function Global:Get-D365BCUnlicensedObjects {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns AL objects from a given directory that are not licensed in an easy to process object-format
    .DESCRIPTION
        ...
    .PARAMETER LicensInfoFile
        [string] The License summary (txt) File you want to grab the information from (mandatory)
    .PARAMETER Path
        [string] Specifies a path to a directory containing AL files.
    .PARAMETER CustomPattern
        [string] Overwrites the default pattern to identify objects
    .PARAMETER Recurse
        [switch] Gets the items in the specified locations and in all child items of the locations.
    .OUTPUTS
        Array of [PSCustomObject]@{
                    Type      = <ObjectType>
                    ID        = <ObjectID>
                    Name      = <ObjectName>
                }  
    #>
    param(        
        [parameter(Mandatory = $true)]
        [string]
        $LicensInfoFile,
        [parameter(Mandatory = $true)]        
        [string]
        $Path,
        [parameter(Mandatory = $false)]
        [string]
        $CustomPattern,
        [parameter(Mandatory = $false)]
        [switch]
        $Recurse
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
    # Handle Parameters
    $params = @{
        Path = $Path                        
    }
    if ($Recurse) {
        $params.Add("Recurse", $Recurse)
    }
    if ($CustomPattern) {
        $params.Add("CustomPattern", $CustomPattern)
    }
    # Get license information from license file
    $licenseInfos = Get-D365BCLicenseInfo -LicensInfoFile $LicensInfoFile
    # Get objcets from path
    $objects = Get-D365BCObjectsFromPath @params
    # Check if there are unlicensed objects
    $unlicensedObjects = @()
    foreach ($object in $objects) {
        if ((Test-D365BCObjectIsLicensed -LicensInfos $licenseInfos -Object $object) -eq $false) {
            $unlicensedObjects += $object
        }
    }
    , $unlicensedObjects
}
Export-ModuleMember Get-D365BCUnlicensedObjects