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
        $IncludeUninstalled = $false,
        [parameter(Mandatory = $false)]
        [switch]
        $ReverseLookup = $false
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
        function Get-ReversedLookupOrder {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true)]
                [PSObject]
                $Apps,
                [parameter(Mandatory = $true)]
                [string]
                $AppName,
                [parameter(Mandatory = $false)]
                [string]
                $AppPublisher
            )
            # Check recursively if the provided object has the given AppName as a dependent app
            function Test-DependentAppsContainApp {
                param(
                    [parameter(Mandatory = $true)]
                    [PSObject]
                    $App,
                    [parameter(Mandatory = $true)]
                    [string]
                    $AppName,
                    [parameter(Mandatory = $false)]
                    [string]
                    $AppPublisher
                )
                process {
                    $containsDependency = $false
                    
                    if ($AppPublisher) {
                        $containsDependency = $null -ne ($App.DependentApps | Where-Object { ($_.Publisher -eq $AppPublisher) -and ($_.Name -eq $AppName) })
                    }
                    else {
                        $containsDependency = $null -ne ($App.DependentApps | Where-Object { $_.Name -eq $AppName })
                    }
                    foreach ($dependency in $App.DependentApps) {
                        $containsDependency = $containsDependency -or (Test-DependentAppsContainApp -App $dependency -AppName $AppName -AppPublisher $AppPublisher)
                    }
                    $containsDependency
                }
            }
            # Removes all app-references from the (initially) complete object with all app references, to only provide the references to the desired AppName
            function Clear-AppObject {
                param(
                    [parameter(Mandatory = $true)]
                    $Apps,
                    [parameter(Mandatory = $true)]
                    [string]
                    $AppName,
                    [parameter(Mandatory = $false)]
                    [string]
                    $AppPublisher
                )
                process {
                    $elements = @()
                    foreach ($app in $Apps) {
                        if (Test-DependentAppsContainApp -App $app -AppName $AppName -AppPublisher $AppPublisher) {
                            $cleanedDependentApps = @()
                            foreach ($dependentApp in $app.DependentApps) {
                                if ($AppPublisher) {
                                    if (($dependentApp.Name -eq $AppName) -and ($dependentApp.Publisher -eq $AppPublisher)) {
                                        $dependentApp.DependentApps = $null
                                        $cleanedDependentApps += $dependentApp
                                    }
                                }
                                else {
                                    if ($dependentApp.Name -eq $AppName) {
                                        $dependentApp.DependentApps = $null
                                        $cleanedDependentApps += $dependentApp
                                    }
                                }
                                if (Test-DependentAppsContainApp -App $dependentApp -AppName $AppName -AppPublisher $AppPublisher) {
                                    $dependentApp = Clear-AppObject -Apps $dependentApp -AppName $AppName -AppPublisher $AppPublisher
                                    $cleanedDependentApps += $dependentApp
                                }
                            }
                            $app.DependentApps = $cleanedDependentApps
                            $elements += $app
                        }
                    }
                    $elements
                }
            }
            $Apps = Clear-AppObject -Apps $Apps -AppName $AppName -AppPublisher $AppPublisher
            $Apps
        }
        if (($AppName -eq "*") -and ($ReverseLookup)) {
            throw "You can not use Wildcard-search combined with 'ReverseLookup'"
            return
        }
        $AppInfo = Get-AppsWithDependencies -ServerInstance $ServerInstance -Tenant $Tenant -IncludeUninstalled:$IncludeUninstalled
        if ($ReverseLookup) {
            $AppInfo = Get-ReversedLookupOrder -Apps $AppInfo -AppName $AppName -AppPublisher $AppPublisher
            $AppInfo
        } 
        else {
            if ($AppName -eq "*") {
                $AppInfo
            }
            else {
                if ($AppPublisher) {
                    $AppInfo | Where-Object { ($_.Publisher -eq $AppPublisher) -and ($_.Name -eq $AppName) }    
                }
                else {
                    $AppInfo | Where-Object { $_.Name -eq $AppName }
                }
            }
        }
    }
}
Export-ModuleMember Get-AppDependencyInfo