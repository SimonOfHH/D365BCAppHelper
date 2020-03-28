function Install-D365BCDependentApps {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [parameter(Mandatory = $true)]
        [string]
        $ServerInstance,
        [parameter(Mandatory = $false)]
        [string]
        $Tenant = "default",
        [ValidateSet("Tenant", "Global")]
        [parameter(Mandatory = $false)]
        [string]
        $Scope = "Tenant",
        [parameter(Mandatory = $false)]
        [pscustomobject]
        $AppInfo,
        [switch]
        $Force
    )    
    foreach ($app in $AppInfo.DependentApps) {
        $params = @{
            ServerInstance = $ServerInstance 
            Publisher      = $app.Publisher
            Name           = $app.Name
            Version        = $app.Version
            WarningAction  = "SilentlyContinue"
            Force          = $true
        }
        if ($Scope -eq "Tenant") {
            $params.Add("Tenant", $Tenant)
        }
        Write-Host "    Installing $($app.Name)..."
        Install-NAVApp @params
        Install-D365BCDependentApps -ServerInstance $ServerInstance -Tenant $Tenant -AppInfo $app -Scope $Scope -Force:$Force        
    }
}
Export-ModuleMember Install-D365BCDependentApps