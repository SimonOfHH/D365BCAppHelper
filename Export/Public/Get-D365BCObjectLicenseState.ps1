function Global:Get-D365BCObjectLicenseState {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns AL objects from a given directory with the info, if they are licensed or not in an easy to process object-format
    .DESCRIPTION
        ...
    .PARAMETER LicensInfoFile
        [string] The License summary (txt) File you want to grab the information from (mandatory)
    .PARAMETER Path
        [string] Specifies a path to a directory containing AL files (if getting objects from directory).
    .PARAMETER CustomPattern
        [string] Overwrites the default pattern to identify objects (if getting objects from directory).
    .PARAMETER Recurse
        [switch] Gets the items in the specified locations and in all child items of the locations (if getting objects from directory).
    .PARAMETER Objects
        [string] Specifies an array of already loaded AL objects (via Get-D365BCObjectsFromPath).
    .OUTPUTS
        Array of [PSCustomObject]@{
                    Type      = <ObjectType>
                    ID        = <ObjectID>
                    Name      = <ObjectName>
                    Licensed  = <Boolean>
                    Unlicensed  = <Boolean>
                }  
    #>
    param(        
        [parameter(Mandatory = $true)]
        [string]
        $LicensInfoFile,
        [parameter(Mandatory = $true, ParameterSetName = "Directory")]        
        [string]
        $Path,
        [parameter(Mandatory = $false, ParameterSetName = "Directory")]
        [string]
        $CustomPattern,
        [parameter(Mandatory = $false, ParameterSetName = "Directory")]
        [switch]
        $Recurse,
        [parameter(Mandatory = $true, ParameterSetName = "ObjectArray")]        
        [PSCustomObject[]]
        $Objects
    )
    function Test-D365BCObjectIsLicensed {
        param(        
            [parameter(Mandatory = $true)]
            $LicensInfos,
            [parameter(Mandatory = $true)]        
            $Object
        )
        if ($Object.Type.ToLower() -In ('enum', 'pageextension', 'tableextension', 'enumextension', 'interface', 'permissionset', 'permissionsetextension', 'reportextension')) {
            $true
            return
        }
        $typeSearch = $Object.Type
        if ($Object.Type.ToLower() -eq 'table') {
            $typeSearch = 'TableData'
        }
        $licenseInfo = $LicensInfos | Where-Object { $_.Type -eq $typeSearch }
        foreach ($idRange in $licenseInfo.Ranges) {
            if (($Object.ID -In $idRange.Start .. $idRange.End) -eq $true) {
                $true
                return
            }
        }
        $false
    }    
    # Get license information from license file
    $licenseInfos = Get-D365BCLicenseInfo -LicensInfoFile $LicensInfoFile
    # Handle Parameters
    if ($path) {
        $params = @{
            Path = $Path                        
        }
        if ($Recurse) {
            $params.Add("Recurse", $Recurse)
        }
        if ($CustomPattern) {
            $params.Add("CustomPattern", $CustomPattern)
        }
        # Get objcets from path
        $objects = Get-D365BCObjectsFromPath @params
    }
    if ($Objects) {
        $objects = $Objects
    }
    # Check if there are unlicensed objects
    foreach ($object in $objects) {
        $licenseResult = Test-D365BCObjectIsLicensed -LicensInfos $licenseInfos -Object $object
        $object | Add-Member -NotePropertyName Licensed -NotePropertyValue $licenseResult
        $object | Add-Member -NotePropertyName Unlicensed -NotePropertyValue (-not $licenseResult)
    }
    , $objects
}
Export-ModuleMember Get-D365BCObjectLicenseState