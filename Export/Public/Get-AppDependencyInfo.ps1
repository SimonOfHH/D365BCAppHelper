function Get-AppDependencyInfo {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [parameter(Mandatory = $false)]
        [string]
        $ServerInstance,
        [parameter(Mandatory = $false)]
        [string]
        $Tenant,
        [parameter(Mandatory = $false)]
        [string]
        $AppPublisher,
        [parameter(Mandatory = $true)]
        [string]
        $AppName,
        [parameter(Mandatory = $false)]
        [switch]
        $IncludeUninstalled = $false
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
        function Get-AppsWithDependencies {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true)]
                [string]
                $ServerInstance,
                [parameter(Mandatory = $false)]
                [string]
                $Tenant,
                [parameter(Mandatory = $false)]
                [switch]
                $IncludeUninstalled = $false
            )
            function Expand-DependentApps {
                [CmdletBinding()]
                param(
                    [parameter(Mandatory = $true)]
                    [PSObject]
                    $Apps
                )
                function Get-DependentAppsForApp {
                    [CmdletBinding()]
                    param(        
                        [parameter(Mandatory = $true)]
                        [PSObject]
                        $PopulatedApps,
                        [parameter(Mandatory = $false)]
                        [string]
                        $AppPublisher,
                        [parameter(Mandatory = $true)]
                        [string]
                        $AppName
                    )    
                    if ($AppPublisher) {
                        $App = $PopulatedApps | Where-Object { ($_.Publisher -eq $AppPublisher) -and ($_.Name -eq $AppName) } | Select-Object -First 1
                    }
                    else {
                        $App = $PopulatedApps | Where-Object { ($_.Name -eq $AppName) } | Select-Object -First 1
                    }
                    $mainApp = [PSCustomObject]@{
                        AppId             = $App.AppId
                        Name              = $App.Name
                        Version           = $App.Version
                        Publisher         = $App.Publisher
                        NoOfDependencies  = $App.NoOfDependencies
                        NoOfDependentApps = $App.NoOfDependencies
                        Dependencies      = $App.Dependencies
                        DependentApps     = @()
                    }
                    foreach ($PopulatedApp in $PopulatedApps) {
                        if ($AppPublisher) {
                            $hasDependency = $PopulatedApp.Dependencies | Where-Object { ($_.Publisher -eq $AppPublisher) -and ($_.Name -eq $AppName) }
                        }
                        else {
                            $hasDependency = $PopulatedApp.Dependencies | Where-Object { $_.Name -eq $App.Name }
                        }   
                        if ($hasDependency) {
                            $mainApp.DependentApps += $PopulatedApp
                        }
                    }
                    $mainApp.NoOfDependentApps = $mainApp.DependentApps.Count
                    Write-Verbose "$($mainApp.Name) has $($mainApp.DependentApps.Count) dependent app(s)"
                    foreach ($app in $mainApp.DependentApps) {
                        Write-Verbose "[-] $($app.Name)"
                    }
                    $mainApp
                }
                for ($i = 0; $i -lt $Apps.Length; $i++) {
                    $Apps[$i] = Get-DependentAppsForApp -PopulatedApps $Apps -AppName $Apps[$i].Name
                }
                $Apps
            }
            function Get-AppWithPopulatedDependencies {
                [CmdletBinding()]
                param(
                    [parameter(Mandatory = $true)]
                    [string]
                    $ServerInstance,
                    [parameter(Mandatory = $true)]
                    [PSObject]
                    $App
                )
                $populatedApp = [PSCustomObject]@{
                    AppId             = $App.AppId
                    Name              = $App.Name
                    Version           = $App.Version
                    Publisher         = $App.Publisher
                    NoOfDependencies  = 0
                    NoOfDependentApps = 0
                    Dependencies      = @()
                    DependentApps     = @()
            
                }    
                foreach ($dependency in $App.Dependencies) {
                    $dependendApp = [PSCustomObject]@{
                        AppId             = $dependency.AppId
                        Name              = $dependency.Name
                        Version           = $dependency.Version
                        Publisher         = $dependency.Publisher
                        NoOfDependencies  = 0
                        NoOfDependentApps = 0
                        Dependencies      = @()
                        DependentApps     = @()
            
                    }
                    $populatedApp.Dependencies += $dependendApp
                }
                $populatedApp.NoOfDependencies = $populatedApp.Dependencies.Count
                $populatedApp
            
            }
            if ($IncludeUninstalled) {
                Write-Verbose "Getting all apps... "
            }
            else {
                Write-Verbose "Getting all installed apps... "
            }
            if ($IncludeUninstalled) {
                $allApps = Get-NavAppinfo -ServerInstance $ServerInstance -Tenant $Tenant -TenantSpecificProperties -Verbose:$false
            }
            else {
                $allApps = Get-NavAppinfo -ServerInstance $ServerInstance -Tenant $Tenant -TenantSpecificProperties -Verbose:$false | Where-Object { $_.IsInstalled -eq $true }
            }
            Write-Verbose "Found $($allApps.Count) apps"
            Write-Verbose "Populating dependencies for $($allApps.Count) apps"
            $appsPopulated = @()
            foreach ($app in $allApps) {
                $appInfo = Get-NavAppinfo -ServerInstance $ServerInstance -Id $app.AppId -Version $app.Version -Verbose:$false
                if ($app.IsInstalled -eq $true) {
                    $appsPopulated += Get-AppWithPopulatedDependencies -ServerInstance $ServerInstance -App $appInfo
                }
            }
            $appsPopulated = $appsPopulated | Sort-Object -Property NoOfDependencies -Descending    
            Expand-DependentApps -Apps $appsPopulated
        }
        $AppInfo = Get-AppsWithDependencies -ServerInstance $ServerInstance -Tenant $Tenant -IncludeUninstalled:$IncludeUninstalled
        if ($AppPublisher) {
            $AppInfo | Where-Object { ($_.Publisher -eq $AppPublisher) -and ($_.Name -eq $AppName) }    
        }
        else {
            $AppInfo | Where-Object { $_.Name -eq $AppName }
        }
    }
}
Export-ModuleMember Get-AppDependencyInfo