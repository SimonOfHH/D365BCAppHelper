function Write-DependencyTree {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [parameter(Mandatory = $true, ParameterSetName = "AppObject")]
        [PSObject]
        $App,
        [parameter(Mandatory = $false, ParameterSetName = "AppObject")]
        [parameter(Mandatory = $true, ParameterSetName = "AppName")]
        [string]
        $AppName,
        [parameter(Mandatory = $false, ParameterSetName = "AppObject")]
        [parameter(Mandatory = $false, ParameterSetName = "AppName")]
        [string]
        $AppPublisher,
        [parameter(Mandatory = $false, ParameterSetName = "AppName")]
        [string]
        $ServerInstance,
        [parameter(Mandatory = $false, ParameterSetName = "AppName")]
        [string]
        $Tenant,
        [parameter(Mandatory = $false, ParameterSetName = "AppName")]
        [parameter(Mandatory = $false)]
        [switch]
        $IncludeUninstalled = $false,
        [parameter(Mandatory = $false)]
        [switch]
        $ReverseLookup = $false,
        [parameter(Mandatory = $false)]
        [int]
        $Level = 0
    ) 
    if (($AppName -eq "*") -and ($ReverseLookup)) {
        throw "You can not use Wildcard-search combined with 'ReverseLookup'"
        return
    }
    if (-not($App)) {
        if (-not($AppName)) {
            return
        }
        $App = Get-AppDependencyInfo -ServerInstance $ServerInstance -Tenant $Tenant -AppName $AppName -AppPublisher $AppPublisher -IncludeUninstalled:$IncludeUninstalled -ReverseLookup:$ReverseLookup
        if (-not($App)) {
            Write-Host "Nothing found."
            return
        }
    } 
    if (($Level -eq 0) -and ($AppName)) {
        if (($AppName -eq "*") -or ($ReverseLookup)) {
            foreach ($appInfo in $App){
                Write-Host "==============================="
                Write-DependencyTree -App $appInfo -AppName $appInfo.Name -Level 0
            }
            return
        }
        else {
            $App = $App | Where-Object { $_.Name -eq $AppName }
        }
    }
    
    Write-Host "| [$Level] " -NoNewline 
    for ($i = 0; $i -lt $Level; $i++) {
        Write-Host "--" -NoNewline
    }
    Write-Host "> " -NoNewline
    Write-Host "[$($App.Name)]"

    $App.DependentApps = $App.DependentApps | Sort-Object -Property Name
    foreach ($dependency in $App.DependentApps) {
        Write-DependencyTree -App $dependency -Level ($Level + 1)
    }
}
Export-ModuleMember Write-DependencyTree