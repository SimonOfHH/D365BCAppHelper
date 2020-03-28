function Get-D365BCLatestVersionFromFolder {
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
        $Directory,
        [parameter(Mandatory = $false)]
        [string]
        $AppPublisher,
        [parameter(Mandatory = $false)]
        [string]
        $AppName,
        [parameter(Mandatory = $false)]
        [switch]
        $ReturnFilenameOnly
    )
    $filter = ""
    if ($AppPublisher){
        $filter = "$($AppPublisher)_"
    }
    if ($AppName){
        $filter = "$filter$($AppName)_"
    }
    $filter = "$filter*.app"
    Write-Verbose "Checking Directory '$Directory' with Filter '$filter'"
    $file = Get-ChildItem -Path $Directory -Filter "*.app" | Sort-Object -Property Name -Descending | Select-Object -First 1
    if ($file) {
        Write-Verbose "Latest version file is: $($file.FullName)"
    }
    if ($ReturnFilenameOnly) {        
        $file = $file.FullName
    }
    $file
}
Export-ModuleMember Get-D365BCLatestVersionFromFolder