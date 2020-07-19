function Global:Test-D365BCModulesAvailable {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Test if standard CmdLets are available on the system running the script.
    .DESCRIPTION
        It first checks if the module "Microsoft.Dynamics.Nav.Apps.Management" is already loaded.
        If this is not the case, it check if NavAdminTool is available (under "C:\Program Files\Microsoft Dynamics *\*\Service\NavAdminTool.ps1")
    #>
    param()
    begin {}
    process {
        $ModuleName = "Microsoft.Dynamics.Nav.Apps.Management"
        $LoadedModules = Get-Module | Select-Object Name
        if ($LoadedModules -like "*$ModuleName*") {
            return $true
        }    
        Write-Verbose "Checking if module $ModuleName does exist"
        $path = "C:\Program Files\Microsoft Dynamics *\*\Service\NavAdminTool.ps1"
        $modulePath = (Get-ChildItem -Path $path | Select-Object -First 1).FullName
        if (($null -ne $modulePath) -and (-not([String]::IsNullOrEmpty($modulePath)))) {
            if (Test-Path $modulePath -ErrorAction SilentlyContinue) {
                Write-Verbose "Module exists."
                return $true
            }
        }
        Write-Verbose "Module does not exist."
        return $false
    }
}
Export-ModuleMember Test-D365BCModulesAvailable