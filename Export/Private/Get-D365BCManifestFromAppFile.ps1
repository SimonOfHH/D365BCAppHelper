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
    .PARAMETER ConvertToInfoOutput
        [switch] Converts the output to a format similar to Get-NAVAppInfo output
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
        $HideProgress,
        [switch]
        $ConvertToInfoOutput
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
            $targetTempFolder = Join-Path -Path $env:TEMP -ChildPath (New-Guid).Guid
            # Don't append filename to directory-name, to avoid too long paths
            #$targetTempFolder = Join-Path -Path $targetTempFolder -ChildPath $onlyFilename
            if (Test-Path $targetTempFolder) {
                Write-Verbose "Removing temporary path $targetTempFolder"
                Remove-Item $targetTempFolder -Force -Recurse
            }
            # Shorten filename if necessary, to stay below the limit of 260 chars on some systems
            # Since $targetTempFolder shouldn't be very long (something like "C:\Users\<Username>\AppData\Local\Temp\<GUID>") this mostly applies to very long file names
            while ((Join-Path -Path $targetTempFolder -ChildPath "$onlyFilename.app").Length -ge 260) {
                $onlyFilename = $onlyFilename.Substring(0, $onlyFilename.Length - 1)
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
                    if ($regularStream -eq $true) {
                        $stream.Seek(40, [System.IO.SeekOrigin]::Begin) | Out-Null
                    }
                    else {
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
            function ConvertFrom-XML {
                [CmdletBinding()]
                param
                (
                    [Parameter(Mandatory = $true, ValueFromPipeline)]
                    [System.Xml.XmlNode]$node, #we are working through the nodes
                    [string]$Prefix = '', #do we indicate an attribute with a prefix?
                    $ShowDocElement = $false #Do we show the document element? 
                )
                process {
                    #if option set, we skip the Document element
                    if ($node.DocumentElement -and !($ShowDocElement)) 
                    { $node = $node.DocumentElement }
                    $oHash = [ordered] @{ } # start with an ordered hashtable.
                    #The order of elements is always significant regardless of what they are
                    write-verbose "calling with $($node.LocalName)"
                    if ($null -ne $node.Attributes) {
                        #if there are elements
                        # record all the attributes first in the ordered hash
                        $node.Attributes | ForEach-Object {
                            $oHash.$($Prefix + $_.FirstChild.parentNode.LocalName) = $_.FirstChild.value
                        }
                    }
                    # check to see if there is a pseudo-array. (more than one
                    # child-node with the same name that must be handled as an array)
                    $node.ChildNodes | #we just group the names and create an empty
                    #array for each
                    Group-Object -Property LocalName | Where-Object { $_.count -gt 1 } | Select-Object Name |
                    ForEach-Object {
                        write-verbose "pseudo-Array $($_.Name)"
                        $oHash.($_.Name) = @() <# create an empty array for each one#>
                    };
                    foreach ($child in $node.ChildNodes) {
                        #now we look at each node in turn.
                        write-verbose "processing the '$($child.LocalName)'"
                        $childName = $child.LocalName
                        if ($child -is [system.xml.xmltext]) {
                            # if it is simple XML text 
                            write-verbose "simple xml $childname";
                            $oHash.$childname += $child.InnerText
                        }
                        # if it has a #text child we may need to cope with attributes
                        elseif ($child.FirstChild.Name -eq '#text' -and $child.ChildNodes.Count -eq 1) {
                            write-verbose "text";
                            if ($null -ne $child.Attributes) {
                                #hah, an attribute
                                <#we need to record the text with the #text label and preserve all
					the attributes #>
                                $aHash = [ordered]@{ };
                                $child.Attributes | ForEach-Object {
                                    $aHash.$($_.FirstChild.parentNode.LocalName) = $_.FirstChild.value
                                }
                                #now we add the text with an explicit name
                                $aHash.'#text' += $child.'#text'
                                $oHash.$childname += $aHash
                            }
                            else {
                                #phew, just a simple text attribute. 
                                $oHash.$childname += $child.FirstChild.InnerText
                            }
                        }
                        elseif ($null -ne $child.'#cdata-section') {
                            # if it is a data section, a block of text that isnt parsed by the parser,
                            # but is otherwise recognized as markup
                            write-verbose "cdata section";
                            $oHash.$childname = $child.'#cdata-section'
                        }
                        elseif ($child.ChildNodes.Count -gt 1 -and 
                        ($child | gm -MemberType Property).Count -eq 1) {
                            $oHash.$childname = @()
                            foreach ($grandchild in $child.ChildNodes) {
                                $oHash.$childname += (ConvertFrom-XML $grandchild)
                            }
                        }
                        else {
                            # create an array as a value  to the hashtable element
                            $oHash.$childname += (ConvertFrom-XML $child)
                        }
                    }
                    $oHash
                }
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
                    $targetFilename2 = Join-Path -Path $targetTempFolder -ChildPath "EmittedContent.json"
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

                        ### Read "EmittedContent.json" if available
                        $zipFileStream = [System.IO.FileStream]::new($Filename, [System.IO.FileMode]::Open)
                        $zipFile = [System.IO.Compression.ZipArchive]::new($zipFileStream, [System.IO.Compression.ZipArchiveMode]::Read)
                        $zipEntryManifest = $zipFile.GetEntry("bin/EmittedContent.json")
                        if ($zipEntryManifest) {
                            $entryStream = $zipEntryManifest.Open()

                            $fileStreamTargetManifest = [System.IO.File]::Create($targetFilename2)
                            $entryStream.CopyTo($fileStreamTargetManifest)
                            $entryStream.Close()
                            $zipFileStream.Close()
                            $fileStreamTargetManifest.Close()
                        }
                        else {
                            $zipFileStream.Close()
                        }
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
            $parentPath = Split-Path -Path $ManifestFileName -Parent
            $additionalContentPath = Join-Path $parentPath -ChildPath "EmittedContent.json"            

            [Xml]$xmlManifest = Get-Content -Path $ManifestFileName -Encoding UTF8
            if (Test-Path -Path $additionalContentPath) {
                $additionalContent = Get-Content -Raw -Path $additionalContentPath | ConvertFrom-Json
                if ($additionalContent.PlatformVersion) {
                    $child = $xmlManifest.CreateElement("PlatformVersion")
                    $child.InnerText = $("$($additionalContent.PlatformVersion.Major).$($additionalContent.PlatformVersion.Minor).$($additionalContent.PlatformVersion.Build).$($additionalContent.PlatformVersion.Revision)")
                    $xmlManifest.Package.App.AppendChild($child)
                }
            }
            if ($SkipCleanup -eq $false) {
                # see https://github.com/SimonOfHH/D365BCAppHelper/issues/10
                # It seems that there is a problem in some constellations that, if the directory name would end
                # with a dot (.) the "Remove-Item" will throw an error. So, if the directory name would end with a
                # dot remove it here
                $cleanUpPath = Split-Path $Filename
                if ($cleanUpPath.EndsWith(".")) {
                    $cleanUpPath = $cleanUpPath.Substring(0, $cleanUpPath.Length - 1)
                }
                Write-Verbose "Cleaning up / removing temporary path $($cleanUpPath)"
                Remove-Item $cleanUpPath -Force -Recurse
            }
            
            if (-not $ConvertToInfoOutput) {
                $xmlManifest.Package
            }
            else {
                $tempmanifestobj = $xmlManifest.Package | ConvertFrom-XML | ConvertTo-Json | ConvertFrom-Json
    
                $manifestobj = $tempmanifestobj.App
                $manifestobj | Add-Member @{Depenendencies = $tempmanifestobj.Dependencies }
                $manifestobj
            }
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