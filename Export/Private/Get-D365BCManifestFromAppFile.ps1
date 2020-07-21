function Global:Get-D365BCManifestFromAppFile {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Load Package-information from App-File
    .DESCRIPTION
        This CmdLet is an alternative to the standard CmdLet Get-NAVAppInfo -Path '.\MyAppFile.app'
        You can use it on a machine, where the standard CmdLet is not available, due to missing DLLs etc.

        Reads a binary Extension (.app-File) and returns an [Xml]-object containing the Package-Information.

        Use like this:
        $xmlManifest = Get-D365BCManifestFromAppFile -Filename "\\Path\to\my\app.file"

        # Possible Properties to check are
        $xmlManifest.App.Id
        $xmlManifest.App.Publisher
        $xmlManifest.App.Name
        $xmlManifest.App.Version
        $xmlManifest.App.Brief
        $xmlManifest.App.Description
        $xmlManifest.App.CompatibilityId
        $xmlManifest.App.PrivacyStatement
        $xmlManifest.App.ApplicationInsightsKey
        $xmlManifest.App.EULA
        $xmlManifest.App.Help
        $xmlManifest.App.HelpBaseUrl
        $xmlManifest.App.ContextSensitiveHelpUrl
        $xmlManifest.App.Url
        $xmlManifest.App.Logo
        $xmlManifest.App.Platform
        $xmlManifest.App.Runtime
        $xmlManifest.App.Target
        $xmlManifest.App.ShowMyCode
    .PARAMETER Filename
        [string] The .app-File you want to grab the information from (mandatory)
    .PARAMETER FullExtract
        [switch] Always extract complete archive, not only NavxManifest.xml
    .PARAMETER SkipCleanup
        [switch] Does not remove extracted files after cleanup
    .PARAMETER HideProgress
        [switch] When full extraction is done, normally there is a ProgressBar indicating the progress of Expand-Archive. Use this switch to hide this ProgressBar
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $Filename,
        [switch]
        $FullExtract,
        [switch]
        $SkipCleanup,
        [switch]
        $HideProgress
    )
    begin {
        Add-Type -Assembly System.IO
        function Remove-InvalidFileNameChars {
            param(
                [Parameter(Mandatory = $true,
                    Position = 0,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
                [String]$Name
            )
          
            $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
            $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
            return ($Name -replace $re)
        }
        function Copy-FileToTemporaryLocation {
            param(
                [parameter(Mandatory = $true)]
                [string]
                $Filename
            )
            Write-Verbose "Copying file $Filename to temporary directory"
            $onlyFilename = (Split-Path $Filename -Leaf).Replace(".app", "")
            $onlyFilename = Remove-InvalidFileNameChars $onlyFilename
            $targetTempFolder = Join-Path -Path $env:TEMP -ChildPath $onlyFilename            
            if (Test-Path $targetTempFolder) {
                Write-Verbose "Removing temporary path $targetTempFolder"
                Remove-Item $targetTempFolder -Force -Recurse
            }
            Write-Verbose "Creating temporary path $targetTempFolder"
            New-Item -Path $targetTempFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            $NewFilename = Join-Path -Path $targetTempFolder -ChildPath "$onlyFilename.app"
            Write-Verbose "Copying $NewFilename to temporary path $targetTempFolder (as $NewFilename)"
            Copy-Item $Filename -Destination $NewFilename | Out-Null
            $NewFilename
        }
        function Get-NavxManifestFromAppFile {
            param(
                [parameter(Mandatory = $true)]
                [string]
                $Filename,
                [switch]
                $FullExtract,
                [switch]
                $SkipCleanup,
                [switch]
                $HideProgress
            )
            function Switch-AppFileToRegularZipFile {
                param(
                    [parameter(Mandatory = $true)]
                    [string]
                    $Filename
                )
                begin {
                    # Loads an additional Type, called "D365BCAppHelper.StreamHelper", which is used to decode RuntimePackages
                    Add-D365BCDotNetHelperType
                }
                process {
                    Write-Verbose "Creating ZIP-file from APP-file"
                    $onlyFilename = (Split-Path $Filename -Leaf).Replace(".app", "")
                    $parentDirectory = Split-Path -Path $Filename
                    $newFilename = Join-Path -Path $parentDirectory -ChildPath "$onlyFilename.zip"
                    $regularStream = $true;
                    if ([D365BCAppHelper.StreamHelper]::IsRuntimePackage($Filename)) {
                        $regularStream = $false
                    }
                    # App-files are basically ZIP-files, but with an offest of 40 bytes
                    # So we first read the source file into a FileStream
                    # and then set the Offset of the Stream to 40
                    # After that we create a new file, copy the offsetted stream into it and save it                    
                    $stream = [System.IO.FileStream]::new($Filename, [System.IO.FileMode]::Open)
                    if ($regularStream -eq $true){
                        $stream.Seek(40, [System.IO.SeekOrigin]::Begin) | Out-Null
                    } else {
                        $newStream = [D365BCAppHelper.StreamHelper]::DecodeStream($stream)
                        $stream.Close()
                        $stream = $newStream
                        $stream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
                    }
                    $fileStream = [System.IO.File]::Create($newFilename)
                    $stream.CopyTo($fileStream)
                    $fileStream.Close()
                    $stream.Close()
                    Write-Verbose "New ZIP-file is located at $newFilename"
                    return , $newFilename
                }
            }
            function Expand-ArchiveAndReturnManifestName {
                param(
                    [parameter(Mandatory = $true)]
                    [string]
                    $Filename,
                    [switch]
                    $HideProgress
                )
                if ($HideProgress -eq $true) {
                    $ProgressPreferenceBackup = $ProgressPreference
                    $global:ProgressPreference = 'SilentlyContinue'
                }
                $parentDirectory = Split-Path -Path $Filename
                $targetTempFolder = Join-Path -Path $parentDirectory -ChildPath "unzip"
                try {                    
                    Write-Verbose "Extracting $(Split-Path $Filename -Leaf) to $($targetTempFolder)"
                    Expand-Archive -Path $Filename -DestinationPath $targetTempFolder -Force
                }
                catch {
                    Write-Error "An error happened: $_"
                }
                finally {
                    if ($HideProgress -eq $true) {
                        $global:ProgressPreference = $ProgressPreferenceBackup
                    }
                }
                $targetFilename = Join-Path -Path $targetTempFolder -ChildPath "NavxManifest.xml"
                if (-not(Test-Path $targetFilename)) {
                    throw "$targetFilename not found in Archive."
                    return ""
                }
                $targetFilename
            }
            function Get-NavxManifestFileFromArchive {
                param(
                    [parameter(Mandatory = $true)]
                    [string]
                    $Filename
                )
                begin {
                    Add-Type -Assembly System.IO.Compression
                }
                process {
                    $parentDirectory = Split-Path -Path $Filename
                    $targetTempFolder = Join-Path -Path $parentDirectory -ChildPath "unzip"
                    $targetFilename = Join-Path -Path $targetTempFolder -ChildPath "NavxManifest.xml"
                    try {                    
                        Write-Verbose "Extracting $(Split-Path $Filename -Leaf) to $($targetTempFolder)"
                        New-Item -Path $targetTempFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                        
                        # Read file as ZipArchive
                        # Get ZipArchiveEntry for NavxManifest.xml
                        # Save Stream from ZipArchiveEntry as newly created file
                        $zipFileStream = [System.IO.FileStream]::new($Filename, [System.IO.FileMode]::Open)
                        $zipFile = [System.IO.Compression.ZipArchive]::new($zipFileStream, [System.IO.Compression.ZipArchiveMode]::Read)
                        $zipEntryManifest = $zipFile.GetEntry("NavxManifest.xml")
                        $entryStream = $zipEntryManifest.Open()

                        $fileStreamTargetManifest = [System.IO.File]::Create($targetFilename)
                        $entryStream.CopyTo($fileStreamTargetManifest)
                        $entryStream.Close()
                        $zipFileStream.Close()
                        $fileStreamTargetManifest.Close()                        
                    }
                    catch {
                        Write-Error "An error happened: $_"
                    } 
                    if (-not(Test-Path $targetFilename)) {
                        $targetFilename = ""
                    }
                    $targetFilename
                }
            }
            $Filename = Copy-FileToTemporaryLocation -Filename $Filename
            $Filename = Switch-AppFileToRegularZipFile -Filename $Filename
            $ManifestFileName = ""
            if ($FullExtract -ne $true) {
                # For performance reasons, first try to read a single entry from the archive
                # if this fails, extract the complete archive and look for the file
                $ManifestFileName = Get-NavxManifestFileFromArchive -Filename $Filename
            }
            if ([string]::IsNullOrEmpty($ManifestFileName)) {
                # Fallback (Extract complete Archive)
                $ManifestFileName = Expand-ArchiveAndReturnManifestName -Filename $Filename -HideProgress:$HideProgress
            }
            if ([string]::IsNullOrEmpty($ManifestFileName)) {
                return
            }
            [Xml]$xmlManifest = Get-Content -Path $ManifestFileName
            if ($SkipCleanup -eq $false) {
                Write-Verbose "Cleaning up / removing temporary path $((Split-Path $Filename))"
                Remove-Item (Split-Path $Filename) -Force -Recurse
            }
            $xmlManifest.Package
        }
    }
    process {
        if (-not(Test-Path $Filename)) {
            throw "$Filename does not exist."
        }
        Write-Verbose "Getting information from $Filename"
        Get-NavxManifestFromAppFile -Filename $Filename -FullExtract:$FullExtract -SkipCleanup:$SkipCleanup -HideProgress:$HideProgress
    }
}
Export-ModuleMember Get-D365BCManifestFromAppFile