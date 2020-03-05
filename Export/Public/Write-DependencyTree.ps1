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
        [int]
        $Level = 0
    )    
    if (-not($App)) {
        if (-not($AppName)) {
            return
        }
        $App = Get-AppDependencyInfo -ServerInstance $ServerInstance -Tenant $Tenant -AppName $AppName -AppPublisher $AppPublisher -IncludeUninstalled:$IncludeUninstalled
        if (-not($App)) {
            return
        }
    } 
    if (($Level -eq 0) -and ($AppName)) {
        $App = $App | Where-Object { $_.Name -eq $AppName }
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