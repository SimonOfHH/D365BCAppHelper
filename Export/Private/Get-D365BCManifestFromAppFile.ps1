function Global:Get-D365BCManifestFromAppFile {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Load Package-information from App-File
    .DESCRIPTION
        Known Limitations: does not work with runtime-files

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
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $Filename,
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
                Write-Verbose "Creating ZIP-file from APP-file"
                $onlyFilename = (Split-Path $Filename -Leaf).Replace(".app", "")
                $parentDirectory = Split-Path -Path $Filename
                $newFilename = Join-Path -Path $parentDirectory -ChildPath "$onlyFilename.zip"
                # App-files are basically ZIP-files, but with an offest of 40 bytes
                # So we first read the source file into a FileStream
                # and then set the Offset of the Stream to 40
                # After that we create a new file, copy the offsetted stream into it and save it
                $stream = [System.IO.FileStream]::new($Filename, [System.IO.FileMode]::Open)
                $stream.Seek(40, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fileStream = [System.IO.File]::Create($newFilename)
                $stream.CopyTo($fileStream)
                $fileStream.Close()
                $stream.Close()
                Write-Verbose "New ZIP-file is located at $newFilename"
                return , $newFilename
            }
            function Expand-ArchiveAndReturnManifestName {
                param(
                    [parameter(Mandatory = $true)]
                    [string]
                    $Filename,
                    [switch]
                    $HideProgress
                )
                if ($HideProgress -eq $true){
                    $ProgressPreferenceBackup = $ProgressPreference
                    $global:ProgressPreference = 'SilentlyContinue'
                }
                $parentDirectory = Split-Path -Path $Filename
                $targetTempFolder = Join-Path -Path $parentDirectory -ChildPath "unzip"
                try {                    
                    Write-Verbose "Extracting $(Split-Path $Filename -Leaf) to $($targetTempFolder)"
                    Expand-Archive -Path $Filename -DestinationPath $targetTempFolder -Force
                } catch {
                    Write-Error "An error happened: $_"
                } finally {
                    if ($HideProgress -eq $true){
                        $global:ProgressPreference = $ProgressPreferenceBackup
                    }
                }
                $targetFilename = Join-Path -Path $targetTempFolder -ChildPath "NavxManifest.xml"
                if (-not(Test-Path $targetFilename)){
                    throw "$targetFilename not found in Archive."
                    return ""
                }
                $targetFilename
            }
            $Filename = Copy-FileToTemporaryLocation -Filename $Filename
            $Filename = Switch-AppFileToRegularZipFile -Filename $Filename
            $ManifestFile = Expand-ArchiveAndReturnManifestName -Filename $Filename -HideProgress:$HideProgress
            if ([string]::IsNullOrEmpty($ManifestFile)){
                return
            }
            [Xml]$xmlManifest = Get-Content -Path $ManifestFile
            if ($SkipCleanup -eq $false){
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
        Get-NavxManifestFromAppFile -Filename $Filename -SkipCleanup:$SkipCleanup -HideProgress:$HideProgress
    }
}
Export-ModuleMember Get-D365BCManifestFromAppFile