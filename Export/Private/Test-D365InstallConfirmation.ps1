function Test-D365InstallConfirmation {
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
        [parameter(Mandatory = $false)]
        [string]
        $AppPublisher,
        [parameter(Mandatory = $true)]
        [string]
        $AppName,
        [parameter(Mandatory = $false)]
        [pscustomobject]
        $InstalledVersion,
        [parameter(Mandatory = $true)]
        [string]
        $LatestVersion,
        [parameter(Mandatory = $true)]
        [string]
        $LatestVersionFilename,
        [parameter(Mandatory = $true)]
        [string]
        $Scope,
        [parameter(Mandatory = $false)]
        [string]
        $AppFileDirectory,
        [switch]
        $Force
    )
    Write-Host "=========================================="
    Write-Host "                   Info                   "
    Write-Host "=========================================="
    Write-Host "   Server Instance: $ServerInstance"
    Write-Host "            Tenant: $Tenant"
    Write-Host "             Scope: $Scope"
    Write-Host "     App Publisher: $AppPublisher"
    Write-Host "          App Name: $AppName"
    if ($AppFileDirectory) {
        Write-Host "App File Directory: $AppFileDirectory"
    }
    if ($InstalledVersion) {
        Write-Host " Installed Version: $($InstalledVersion.Version) ($($null -ne $InstalledVersion.DependentApps))"
    }
    else {
        Write-Host " Installed Version: --- NONE ---"
    }
    Write-Host "       New Version: $($LatestVersion) (Source: $LatestVersionFilename)"
    if ($InstalledVersion.DependentApps) {
        Write-Host "Attention: This app has depending apps. These apps will be uninstalled during the update and installed back again when everything is done." -ForegroundColor Yellow
        Write-Host "Depending Apps:" -ForegroundColor Yellow
        Write-DependencyTree -App $InstalledVersion
    }
    if (-not($Force)) {
        Write-Host "Do you want to continue?" -ForegroundColor Yellow -NoNewline
        $Readhost = Read-Host " ( y / n ) " 
        Switch ($ReadHost.ToUpper()) {  
            Y {
                Write-Host "Continuing"
                $true
            }       
            Default {
                Write-Host "Stopping"
                $false
            } 
        }
    } else {
        $true
    }
}
Export-ModuleMember Test-D365InstallConfirmation
