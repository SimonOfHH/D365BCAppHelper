function Global:Import-D365BCNecessaryModule {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param()
    begin {
        
    }
    process {
        $ModuleName = "Microsoft.Dynamics.Nav.Apps.Management"
        $LoadedModules = Get-Module | Select-Object Name
        if ($LoadedModules -like "*$ModuleName*") {
            return
        }    
        Write-Verbose "Loading module $ModuleName"
        $path = "C:\Program Files\Microsoft Dynamics *\*\Service\NavAdminTool.ps1"
        $modulePath = (Get-ChildItem -Path $path | Select-Object -First 1).FullName
        if (-not(Test-Path $modulePath)) {
            throw "Module $ModuleName not found."
            return
        }
        Import-Module -Name $modulePath -Verbose:$false | Out-Null
        Write-Verbose "Successfully loaded module $ModuleName"
    }
}
Export-ModuleMember Import-D365BCNecessaryModule