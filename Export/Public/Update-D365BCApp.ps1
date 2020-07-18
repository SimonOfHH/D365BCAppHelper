function Update-D365BCApp {
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
        $AppPublisher,
        [parameter(Mandatory = $true)]
        [string]
        $AppName,
        [parameter(Mandatory = $false)]
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
        $Force,
        [switch]
        $ForceSubsequent
    )
    begin {
        if (-not($ServerInstance)) {
            $ServerInstance = Get-D365BCServerInstanceName
        }
        if (-not($Tenant)) {
            $Tenant = Get-D365BCInstanceTenant
        }
        if (-not($AppVersion)) {
            $AppVersion = Get-D365BCVersionFromFile -Filename $AppFilename
        }
        if (-not($AppPublisher)) {
            $AppPublisher = Get-D365BCPublisherFromFile -Filename $AppFilename
        }
    }
    process {
        ### Preparation ###
        if (-not($ServerInstance)) {
            throw "'ServerInstance' needs to be set"
            return
        }
        if (-not($Tenant)) {
            throw "'Tenant' needs to be set"
            return
        }
        if (-not($AppVersion)) {
            throw "'AppVersion' needs to be set"
            return
        }
        $params = @{
            ServerInstance = $ServerInstance 
            Tenant         = $Tenant 
            AppPublisher   = $AppPublisher
            AppName        = $AppName 
        }
        $appInfo = Get-AppDependencyInfo @params -IncludeUninstalled

        ### Confirmation ###
        $params = @{
            ServerInstance        = $ServerInstance 
            Tenant                = $Tenant 
            AppPublisher          = $AppPublisher
            AppName               = $AppName 
            InstalledVersion      = $appInfo
            LatestVersion         = $AppVersion
            LatestVersionFilename = $AppFilename
            Scope                 = $Scope
            Force                 = $Force
        }
        if (-not(Test-D365InstallConfirmation @params)) {
            return
        }
        if ((-not($Force) -and ($ForceSubsequent))) {
            $Force = $ForceSubsequent
        }
        ### Uninstall ###
        $params = @{
            ServerInstance     = $ServerInstance 
            Tenant             = $Tenant 
            AppPublisher       = $AppPublisher
            AppName            = $AppName 
            InstalledVersion   = $appInfo
            AppVersion         = $appInfo.Version
            SameVersionInstall = ($appInfo.Version -eq $AppVersion)
            Scope              = $Scope
            Force              = $Force
        }
        Uninstall-D365BCApp @params

        ### Install ###
        $params = @{
            ServerInstance   = $ServerInstance 
            AppPublisher     = $AppPublisher
            AppName          = $AppName 
            AppVersion       = $AppVersion
            Tenant           = $Tenant 
            Scope            = $Scope
            AppFilename      = $AppFilename
            InstalledVersion = $appInfo
            SyncMode         = $SyncMode
            UpgradeApp       = ($appInfo.Version -lt $AppVersion)
            Force            = $Force
        }
        Install-D365BCApp @params
    }
}
Export-ModuleMember Update-D365BCApp