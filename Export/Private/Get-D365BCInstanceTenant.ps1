function Global:Get-D365BCInstanceTenant {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns Tenant to work on.
    .DESCRIPTION
        If there is only one Tenant available it is returned directly. If there are multiple Tenants the User is prompted to select the desired Tenant.
    #>
    param()
    begin {
        Import-D365BCNecessaryModule
    }
    process {
        Write-Verbose "Loading available Tenants"
        $tenants = Get-NAVTenant -ServerInstance $ServerInstance -WarningAction SilentlyContinue -Verbose:$false
        $count = 0
        foreach ($tenant in $tenants) {
            $count += 1
        }
        Write-Verbose "Found $count Tenant(s)"
        if ($count -eq 1) {
            $tenant = $tenants | Select-Object -First 1 | Select-Object -Property Id -ExpandProperty Id
        }
        else {
            Write-Host "Select Tenant:"
            Write-Host "------------------------------------------"
            $count = 0
            foreach ($tenant in $tenants) {
                $count += 1
                Write-Host "[$($count)] $($tenant.Id)"
            }
            Write-Host "------------------------------------------"
            $ReadHost = Read-Host "Enter ID: "
            [int]$tenantId = $ReadHost - 1
            $tenant = $tenants | Select-Object -Skip $tenantId -First 1 | Select-Object -Property Id -ExpandProperty Id
        }
        $tenant
    }
}
Export-ModuleMember Get-D365BCInstanceTenant