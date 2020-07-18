function Install-D365BCApp {
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
        [ValidateSet("Add", "Clean", "Development", "ForceSync")]
        [parameter(Mandatory = $false)]
        [string]
        $SyncMode = "Add",
        [parameter(Mandatory = $true)]
        [string]
        $AppFilename,
        [switch]
        $UpgradeApp,
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
        ### Publish-NAVApp ###
        $params = @{
            ServerInstance   = $ServerInstance 
            Path             = $AppFilename 
            SkipVerification = $True 
            Scope            = $Scope
            WarningAction    = "SilentlyContinue"
        }
        if ($Scope -eq "Tenant") {
            $params.Add("Tenant", $Tenant)
        }
        Write-Host "=========================================="
        Write-Host "          Install / Update"
        Write-Host "=========================================="
        Write-Host "Processing Installation (Version $AppVersion)..."
        Write-Host "   Publishing...    " -NoNewline        
        Publish-NAVApp @params
        Write-Host "Done" -ForegroundColor Green

        ### Sync-NAVApp ###
        $params = @{
            ServerInstance = $ServerInstance 
            Name           = $AppName
            Version        = $AppVersion
            Mode           = $SyncMode
            Force          = $Force
            WarningAction  = "SilentlyContinue"
        }
        if ($AppPublisher) {
            $params.Add("Publisher", $AppPublisher)
        }
        Write-Host "   Syncing app...   " -NoNewline
        Sync-NAVApp @params
        Write-Host "Done" -ForegroundColor Green

        ### Start-NAVAppDataUpgrade/Install-NAVApp ###
        $params = @{
            ServerInstance = $ServerInstance 
            Name           = $AppName 
            Version        = $AppVersion
            WarningAction  = "SilentlyContinue"
            Force          = $Force
        }
        if ($AppPublisher) {
            $params.Add("Publisher", $AppPublisher)
        }
        if ($Scope -eq "Tenant") {
            $params.Add("Tenant", $Tenant)
        }
        if ($UpgradeApp -eq $true) {
            Write-Host "   Upgrading data..." -NoNewline
            Start-NAVAppDataUpgrade @params
            Write-Host "Done" -ForegroundColor Green
        }
        Write-Host "   Installing...    " -NoNewline
        Install-NAVApp @params
        Write-Host "Done" -ForegroundColor Green
        if (($InstalledVersion) -and ($InstalledVersion.DependentApps)) {
            $params = @{
                ServerInstance = $ServerInstance 
                Tenant         = $Tenant 
                Scope          = $Scope
                AppInfo        = $InstalledVersion
                Force          = $Force
            }
            Write-Host "   Installing dependencies...    "
            Install-D365BCDependentApps @params
            Write-Host "   Done" -ForegroundColor Green
        }
    }
}
Export-ModuleMember Install-D365BCApp