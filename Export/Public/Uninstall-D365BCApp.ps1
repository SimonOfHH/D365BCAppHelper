function Uninstall-D365BCApp {
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
        $AppPublisher,
        [parameter(Mandatory = $true)]
        [string]
        $AppName,
        [parameter(Mandatory = $true)]
        [string]
        $AppVersion,
        [parameter(Mandatory = $false)]
        [string]
        $Tenant = "default",
        [ValidateSet("Tenant", "Global")]
        [parameter(Mandatory = $false)]
        [string]
        $Scope = "Tenant",        
        [switch]
        $SameVersionInstall,
        [parameter(Mandatory = $false)]
        [pscustomobject]
        $InstalledVersion,
        [switch]
        $Force
    )
    begin {
        if (-not($ServerInstance)) {
            $ServerInstance = Get-D365BCServerInstanceName
        }
        if (-not($Tenant)) {
            $Tenant = Get-D365BCInstanceTenant
        }
    }
    process {
        Write-Host "=========================================="
        Write-Host "          Uninstall"
        Write-Host "=========================================="
        Write-Host "Trying to uninstall the previously installed version $AppVersion"
        if (Get-NAVAppInfo -ServerInstance $ServerInstance -Publisher $AppPublisher -Name $AppName -Version $AppVersion -Tenant $Tenant -TenantSpecificProperties -WarningAction SilentlyContinue) {        
            Write-Host "Processing Uninstallation (Version $AppVersion)..."
            #if (($InstalledVersion) -and ($InstalledVersion.DependentApps)) {
            #    #Uninstall-DependentApps -ServerInstance $ServerInstance -Tenant $Tenant -AppInfo $InstalledVersion.AppInfo
            #    Write-Host "  Uninstalling $($AppName)..." -NoNewline
            #    Uninstall-NAVApp -ServerInstance $ServerInstance -Name $AppName -Tenant $Tenant -Version $AppVersion -Force -WarningAction SilentlyContinue            
            #    Write-Host "  Done" -ForegroundColor Green
            #}
            #else {
                Write-Host "  Uninstalling...   " -NoNewline
                Uninstall-NAVApp -ServerInstance $ServerInstance -Name $AppName -Tenant $Tenant -Version $AppVersion -Force -WarningAction SilentlyContinue
                Write-Host "Done" -ForegroundColor Green
            #}                
            if ($SameVersionInstall) {
                Write-Host "   Syncing app...   " -NoNewline
                if ($Scope -eq "Tenant") {
                    Sync-NAVApp -ServerInstance $ServerInstance -Name $AppName -Version $AppVersion -Mode Add -Tenant $Tenant -WarningAction SilentlyContinue
                }
                else {
                    Sync-NAVApp -ServerInstance $ServerInstance -Name $AppName -Version $AppVersion -Mode Add -WarningAction SilentlyContinue
                }
                Write-Host "Done" -ForegroundColor Green
                Write-Host "Syncing tenant...   " -NoNewline
                Sync-NAVTenant -Tenant $Tenant -ServerInstance $ServerInstance -Mode Sync -Force -WarningAction SilentlyContinue
                Write-Host "Done" -ForegroundColor Green
                Write-Host "  Unpublishing...   " -NoNewline
                if ($Scope -eq "Tenant") {
                    Unpublish-NAVApp -ServerInstance $ServerInstance -Name $AppName -Tenant $Tenant -Version $AppVersion -WarningAction SilentlyContinue
                }
                else {
                    Unpublish-NAVApp -ServerInstance $ServerInstance -Name $AppName -Version $AppVersion -WarningAction SilentlyContinue
                }
                Write-Host "Done" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Version $AppVersion currently not installed"
        }
    }
}
Export-ModuleMember Uninstall-D365BCApp