function Get-D365BCVersionFromFile {
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
        $Filename
    )
    begin {
        Import-D365BCNecessaryModule
    }
    process {
        if (-not(Test-Path $Filename)) {
            throw "$Filename does not exist."
        }
        Write-Verbose "Getting information from $Filename"
        $info = Get-NAVAppInfo -Path $Filename
        $info.Version
    }
}
Export-ModuleMember Get-D365BCVersionFromFile