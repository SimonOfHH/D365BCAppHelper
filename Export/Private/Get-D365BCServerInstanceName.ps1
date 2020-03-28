function Get-D365BCServerInstanceName {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns Server Instance to work on.
    .DESCRIPTION
        If there is only one Server Instance available it is returned directly. If there are multiple Server Instances the User is prompted to select the desired Server Instance.
    #>
    param()
    begin {
        Import-D365BCNecessaryModule
    }
    process {
        Write-Verbose "Loading available Server Instances"
        $instances = Get-NAVServerInstance -WarningAction SilentlyContinue -Verbose:$false
        $count = 0
        foreach ($instance in $instances) {
            $count += 1
        }
        Write-Verbose "Found $count Server Instance(s)"
        if ($count -eq 1) {
            $instance = $instances | Select-Object -First 1 | Select-Object -Property ServerInstance -ExpandProperty ServerInstance
        }
        else {
            Write-Host "Select instance to work on:"
            Write-Host "------------------------------------------"
            $count = 0
            foreach ($instance in $instances) {
                $count += 1
                Write-Host "[$($count)] $($instance.ServerInstance.Substring($instance.ServerInstance.LastIndexOf("$") + 1))"
            }
            Write-Host "------------------------------------------"
            $ReadHost = Read-Host "Enter ID: "
            [int]$instanceId = $ReadHost - 1
            $instance = $instances | Select-Object -Skip $instanceId -First 1 | Select-Object -Property ServerInstance -ExpandProperty ServerInstance
            Write-Host "Selected Instance: $($instance.Substring($instance.LastIndexOf("$") + 1))"
            Write-Host "------------------------------------------"
        }
        $selectedInstance = $instance.Substring($instance.LastIndexOf("$") + 1)        
        $selectedInstance
    }
}
Export-ModuleMember Get-D365BCServerInstanceName