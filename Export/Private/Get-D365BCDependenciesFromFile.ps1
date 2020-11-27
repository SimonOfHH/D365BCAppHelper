function Global:Get-D365BCDependenciesFromFile {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns the "Publisher"-property from a given AppPackage (.app-file)
    .DESCRIPTION
        This is basically a shortcut to (Get-NAVAppInfo -Path $Filename).Publisher. 
        If the standard CmdLets are unavailable, it will read the NavxManifest.xml directly from the provided file.
    .PARAMETER Filename
        [string] The .app-File you want to grab the information from (mandatory)
    .PARAMETER FromManifest
        [switch] If set, the information will be grabbed directly from the NavxManifest.xml; if not set it is first determined if the CmdLets are available. 
        In case they are available the standard CmdLet Get-NavAppInfo will be used, otherwise the information will be read from NavxManifest.xml
    .OUTPUTS
        Publisher-property
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $Filename,
        [switch]
        $FromManifest
    )
    begin {
        if ($FromManifest -eq $false) {
            if (Test-D365BCModulesAvailable) {
                Import-D365BCNecessaryModule
                $ReaderOption = "StandardCmdLet"
            }
            else {
                $ReaderOption = "ManifestFile"
            }
        }
        else {
            $ReaderOption = "ManifestFile"
        }
    }
    process {
        if (-not(Test-Path $Filename)) {
            throw "$Filename does not exist."
        }
        
        if ($ReaderOption -eq "StandardCmdLet") {
            Write-Verbose "Getting information from $Filename"
            $info = Get-NAVAppInfo -Path $Filename
            $info.Dependencies
        }
        else {
            $info = Get-D365BCManifestFromAppFile -Filename $Filename            
            $info.Dependencies.ChildNodes
        }
    }
}
Export-ModuleMember Get-D365BCDependenciesFromFile