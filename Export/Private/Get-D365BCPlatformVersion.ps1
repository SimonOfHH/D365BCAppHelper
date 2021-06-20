function Global:Get-D365BCPlatformVersion {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns the "PlatformVersion"-property from a given Runtime-AppPackage (.app-file)
    .DESCRIPTION        
        When available in the Runtime-package the "VersionRuntimePackageIsBuiltFor" will be returned
    .PARAMETER Filename
        [string] The .app-File you want to grab the information from (mandatory)
    .OUTPUTS
        PlatformVersion-property
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $Filename
    )    
    process {
        if (-not(Test-Path $Filename)) {
            throw "$Filename does not exist."
        }
                
        $info = Get-D365BCManifestFromAppFile -Filename $Filename
        $info.App.PlatformVersion        
    }
}
Export-ModuleMember Get-D365BCPlatformVersion