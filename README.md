# D365BC-AppHelper
This module is used as a helper module for **Dynamics 365 Business Central** App handling. It's a work-in-progress, so new functionality might be added over time.

Current list of commands:
- [Get-AppDependencyInfo](#get-appDependencyInfo)
- [Write-DependencyTree](#write-dependencyTree)
- [Update-D365BCApp](#update-d365BCApp)
- [Install-D365BCApp](#install-d365BCApp)
- [Uninstall-D365BCApp](#uninstall-d365BCApp)
- [Get-D365BCLicenseInfo](#get-d365BCLicenseInfo)
- [Get-D365BCObjectsFromPath](#get-d365BCObjectsFromPath)
- [Get-D365BCObjectLicenseState](#get-d365BCObjectLicenseState)
- [Get-D365BCUnlicensedObjects](#get-d365BCUnlicensedObjects)

Additionally there are a couple of helper CmdLets. The important ones are described here:
- [Get-D365BCAppNameFromFile](#get-d365BCAppNameFromFile)
- [Get-D365BCVersionFromFile](#get-d365BCVersionFromFile)
- [Get-D365BCPublisherFromFile](#get-d365BCPublisherFromFile)
- [Get-D365BCDependenciesFromFile](#get-d365BCDependenciesFromFile)
- [Get-D365BCPlatformVersion](#get-d365BCPlatformVersion) (Runtime-app only)

## Get-AppDependencyInfo
### Description
Used by `Write-DependencyTree` to resolve dependencies
### Parameters
```
[-ServerInstance]
[-Tenant]
[-AppPublisher]
-AppName
[-IncludeUninstalled]
[-ReverseLookup]
```
If `ServerInstance` or `Tenant` are not provided the CmdLet will check for existing Instances/Tenants. If only one of each is found it will use this without prompting. If there are multiple Instances/Tenants the CmdLet will prompt to select one.

### Output
PSObject with the following structure
- AppId `<Guid>`
- Name `<String>`
- Version `<System.Version>`
- Publisher `<String>`
- NoOfDependencies `<Int>`
- NoOfDependentApps `<Int>`
- Dependencies `<Array<PSObject>>`
- DependentApps `<Array<PSObject>>`

## Write-DependencyTree
### Description
Outputs a representation of the dependencies for the provided app
### Parameters
Parameter Set "AppName"
```
-AppName
[-AppPublisher]
[-ServerInstance]
[-Tenant]
[-IncludeUninstalled]
[-ReverseLookup]
[-Level]
```
Parameter Set "AppObject" (only used internally, when called recursively)
```
-App <PSObject>
[-AppName]
[-AppPublisher]
[-Level]
```
### Examples
Get information for a specific App:

`Write-DependencyTree -AppName "Base Application"`
### Output
Sample output
```
| [0] > [Base Application]
| [1] --> [_Exclude_APIV1_]
| [1] --> [_Exclude_ClientAddIns_]
| [1] --> [Business Central Intelligent Cloud]
| [1] --> [Essential Business Headlines]
| [1] --> [Intelligent Cloud Base]
| [2] ----> [Business Central Intelligent Cloud]
| [1] --> [PayPal Payments Standard]
| [1] --> [Sales and Inventory Forecast]
| [1] --> [Send remittance advice by email]
```
Get information for all installed Apps:

`Write-DependencyTree -AppName "*"`
```
===============================
| [0] > [Business Central Intelligent Cloud]
===============================
| [0] > [Essential Business Headlines]
===============================
| [0] > [_Exclude_APIV1_]
===============================
| [0] > [_Exclude_ClientAddIns_]
===============================
| [0] > [Send remittance advice by email]
===============================
| [0] > [Intelligent Cloud Base]
| [1] --> [Business Central Intelligent Cloud]
===============================
| [0] > [Sales and Inventory Forecast]
===============================
| [0] > [PayPal Payments Standard]
===============================
| [0] > [Base Application]
| [1] --> [_Exclude_APIV1_]
| [1] --> [_Exclude_ClientAddIns_]
| [1] --> [Business Central Intelligent Cloud]
| [1] --> [Essential Business Headlines]
| [1] --> [Intelligent Cloud Base]
| [2] ----> [Business Central Intelligent Cloud]
| [1] --> [PayPal Payments Standard]
| [1] --> [Sales and Inventory Forecast]
| [1] --> [Send remittance advice by email]
===============================
| [0] > [System Application]
| [1] --> [_Exclude_APIV1_]
| [1] --> [_Exclude_ClientAddIns_]
| [1] --> [Base Application]
| [2] ----> [_Exclude_APIV1_]
| [2] ----> [_Exclude_ClientAddIns_]
| [2] ----> [Business Central Intelligent Cloud]
| [2] ----> [Essential Business Headlines]
| [2] ----> [Intelligent Cloud Base]
| [3] ------> [Business Central Intelligent Cloud]
| [2] ----> [PayPal Payments Standard]
| [2] ----> [Sales and Inventory Forecast]
| [2] ----> [Send remittance advice by email]
| [1] --> [Business Central Intelligent Cloud]
| [1] --> [Essential Business Headlines]
| [1] --> [Intelligent Cloud Base]
| [2] ----> [Business Central Intelligent Cloud]
| [1] --> [PayPal Payments Standard]
| [1] --> [Sales and Inventory Forecast]
| [1] --> [Send remittance advice by email]
```
With the Parameter `ReverseLookup` you can output Dependencies in a reversed way. In this case only the targeted App (from `AppName`) with it's direct parents will be outputted. It'll output the different levels of dependencies separately (including implicit dependencies on "System Application")

`Write-DependencyTree -AppName "Business Central Intelligent Cloud" -ReverseLookup`
```
===============================
| [0] > [Intelligent Cloud Base]
| [1] --> [Business Central Intelligent Cloud]
===============================
| [0] > [Base Application]
| [1] --> [Business Central Intelligent Cloud]
| [1] --> [Intelligent Cloud Base]
| [2] ----> [Business Central Intelligent Cloud]
===============================
| [0] > [System Application]
| [1] --> [Base Application]
| [2] ----> [Business Central Intelligent Cloud]
| [2] ----> [Intelligent Cloud Base]
| [3] ------> [Business Central Intelligent Cloud]
| [1] --> [Business Central Intelligent Cloud]
| [1] --> [Intelligent Cloud Base]
| [2] ----> [Business Central Intelligent Cloud]
```

## Update-D365BCApp
### Short Description
Updates an already installed App
### Parameters
```
[-ServerInstance]
[-AppPublisher]
-AppName
[-AppVersion]
[-Tenant]
[-Scope]
[-SyncMode]
-AppFilename
[-Force]
[-ForceSubsequent]
```
**Scope**: *Tenant*, *Global*; default: *Tenant*

**SyncMode**: *Add*, *Clean*, *Development*, *ForceSync*; default: *Add*

**Force**: Skips Confirmation and also uses *Force* on all subsequent CmdLets

**ForceSubsequent**: Uses *Force* on all subsequent CmdLets (not necessary when using *Force*)

### Output
*none*

### Description
Uninstalls the existing App-Version and Installs the new Version (from *AppFilename*) with `Install-D365BCApp` (includes *Publish-NAVApp*, *Sync-NAVApp*, *Start-NAVAppDataUpgrade*, *Install-NAVApp* and *Install-D365BCDependentApps*)

## Install-D365BCApp
### Short Description
Installs an D365BC App
### Parameters
```
-ServerInstance
[-AppPublisher]
-AppName
-AppVersion
[-Tenant]
[-Scope]
[-SyncMode]
-AppFilename
[-UpgradeApp]
[-InstalledVersion]
[-Force]
```
**Scope**: *Tenant*, *Global*; default: *Tenant*

**SyncMode**: *Add*, *Clean*, *Development*, *ForceSync*; default: *Add*

**InstalledVersion**: Used when called from *Update-D365BCApp*

**Force**: Uses *Force* on all used CmdLets

### Description
This CmdLet is a combination of *Publish-NAVApp*, *Sync-NAVApp*, *Start-NAVAppDataUpgrade* (when parameter *UpgradeApp* is used), *Install-NAVApp* and *Install-D365BCDependentApps*)

## Uninstall-D365BCApp
### Short Description
Uninstalls an D365BC App
### Parameters
```
-ServerInstance
[-AppPublisher]
-AppName
-AppVersion
[-Tenant]
[-Scope]
[-SameVersionInstall]
[-InstalledVersion]
[-Force]
```
**Scope**: *Tenant*, *Global*; default: *Tenant*

**SameVersionInstall**: Used when called from *Update-D365BCApp*, necessary if Version wasn't incremented in app-file (Used when called from *Update-D365BCApp*)

**InstalledVersion**: Used when called from *Update-D365BCApp*

**Force**: Uses *Force* on all used CmdLets

## Get-D365BCLicenseInfo
### Short Description
Returns the custom-objects from a license summary file in an easy to process object-format
### Parameters
```
-LicensInfoFile
```
**LicensInfoFile**: The text-file with the license summary

### Output

The output is an Array of 
```
[PSCustomObject]@{
    Type      = <ObjectType>
    Purchased = <NumberPurchased>
    Assigned  = <NumberAssigned>
    Remaining = <NumberRemaining>
    Ranges    = <Array of [PSCustomObject]@{
                            Quantity = <Quantity>
                            Start    = <StartID>
                            End      = <EndID>
                        }>
}  
```

Sample output
```
PS > Get-D365BCLicenseInfo -LicensInfoFile "<PathToSummaryTxtFile" | Format-Table

Type      Purchased Assigned Remaining Ranges
----      --------- -------- --------- ------
TableData        80       70        10 {@{Quantity=58; Start=60000; End=60057}, @{Quantity=9; Start=60100; End=60108}, @{Quantity=3; Start=60113; End=60115}}
Report          200       33       167 {@{Quantity=33; Start=60000; End=60032}}
Codeunit        120       62        58 {@{Quantity=62; Start=60000; End=60061}}
Page            200      108        92 {@{Quantity=87; Start=60000; End=60086}, @{Quantity=21; Start=60100; End=60120}}
XMLPort         100        7        93 {@{Quantity=7; Start=60000; End=60006}}
Query           100        0       100 {}
```

## Get-D365BCObjectsFromPath
### Short Description
Returns AL objects from a given directory in an easy to process object-format
### Parameters
```
-Path
[-CustomPattern]
[-Recurse]
```
**Path**: Specifies a path to a directory containing AL files.
**CustomPattern**: Overwrites the default pattern to identify objects
**Recurse**: Gets the items in the specified locations and in all child items of the locations.

### Output

The output is an Array of 
```
[PSCustomObject]@{
    Type       = <ObjectType>
    ID         = <ObjectID>
    Name       = <ObjectName>
}  
```

Sample output
```
PS > Get-D365BCObjectsFromPath -Path "<PathToRepository>" -Recurse

Type              ID Name
----              -- ----
codeunit       60000 Sales Events
codeunit       60001 Purchase Events
codeunit       60002 Warehouse Events
codeunit       60003 General Events
....
```

## Get-D365BCObjectLicenseState
### Short Description

Returns AL objects from a given directory with the info, if they are licensed or not in an easy to process object-format

### Parameters
```
-LicensInfoFile
-Path
[-CustomPattern]
[-Recurse]
```
**LicensInfoFile**: The text-file with the license summary
**Path**: Specifies a path to a directory containing AL files.
**CustomPattern**: Overwrites the default pattern to identify objects
**Recurse**: Gets the items in the specified locations and in all child items of the locations.

### Output

The output is an Array of 
```
[PSCustomObject]@{
    Type       = <ObjectType>
    ID         = <ObjectID>
    Name       = <ObjectName>
    Licensed   = <Boolean>
    Unlicensed = <Boolean>
}  
```

Sample output
```
Type        ID Name                           Licensed Unlicensed
----        -- ----                           -------- ----------
codeunit 60062 Codeunit ABC                      False       True
codeunit 60063 Codeunit CDE                      False       True
codeunit 60064 Codeunit EFG                      False       True
```

## Get-D365BCUnlicensedObjects
### Short Description
Returns AL objects from a given directory that are not licensed in an easy to process object-format

### Parameters
```
-LicensInfoFile
-Path
[-CustomPattern]
[-Recurse]
```
**LicensInfoFile**: The text-file with the license summary
**Path**: Specifies a path to a directory containing AL files.
**CustomPattern**: Overwrites the default pattern to identify objects
**Recurse**: Gets the items in the specified locations and in all child items of the locations.

### Output

The output is an Array of 
```
[PSCustomObject]@{
    Type       = <ObjectType>
    ID         = <ObjectID>
    Name       = <ObjectName>
}  
```

Sample output
```
Type              ID Name
----              -- ----
codeunit       60000 Sales Events
codeunit       60001 Purchase Events
codeunit       60002 Warehouse Events
codeunit       60003 General Events
```

## Get-D365BCAppNameFromFile
### Short Description
Reads the "Name"-property from an .app-File (works with or without standard Business Central CmdLets available)

### Parameters
```
-Filename
[-FromManifest]
```
**Filename**: (string) The full path to the File (.app) that the information should be read from

**FromManifest**: (switch) Set, if you don't want to use the standard CmdLet (`Get-NavAppInfo`)

## Get-D365BCVersionFromFile
### Short Description
Reads the "Version"-property from an .app-File (works with or without standard Business Central CmdLets available)

### Parameters
```
-Filename
[-FromManifest]
```
**Filename**: (string) The full path to the File (.app) that the information should be read from

**FromManifest**: (switch) Set, if you don't want to use the standard CmdLet (`Get-NavAppInfo`)

## Get-D365BCPublisherFromFile
### Short Description
Reads the "Publisher"-property from an .app-File (works with or without standard Business Central CmdLets available)

### Parameters
```
-Filename
[-FromManifest]
```
**Filename**: (string) The full path to the File (.app) that the information should be read from

**FromManifest**: (switch) Set, if you don't want to use the standard CmdLet (`Get-NavAppInfo`)

## Get-D365BCDependenciesFromFile
### Short Description
Reads the "Dependencies"-property from an .app-File (works with or without standard Business Central CmdLets available)

### Parameters
```
-Filename
[-FromManifest]
```
**Filename**: (string) The full path to the File (.app) that the information should be read from

**FromManifest**: (switch) Set, if you don't want to use the standard CmdLet (`Get-NavAppInfo`)

### Output
Sample output (via `Get-NavAppInfo`)
```
PS C:\run> Get-D365BCDependenciesFromFile -Filename C:\run\my\test\PayPalPaymentsStandard.app

AppId           : 437dbf0e-84ff-417a-965d-ed2bb9650972
Name            : Base Application
Publisher       : Microsoft
MinVersion      : 15.2.0.0
CompatibilityId : 0.0.0.0
IsPropagated    : False
Version         : 15.2.0.0

AppId           : 63ca2fa4-4f03-4f2b-a480-172fef340d3f
Name            : System Application
Publisher       : Microsoft
MinVersion      : 15.2.0.0
CompatibilityId : 0.0.0.0
IsPropagated    : False
Version         : 15.2.0.0
```

Sample output (via Manifest)

```
PS C:\run> Get-D365BCDependenciesFromFile -Filename C:\run\my\test\PayPalPaymentsStandard.app -FromManifest

Id              : 437dbf0e-84ff-417a-965d-ed2bb9650972
Name            : Base Application
Publisher       : Microsoft
MinVersion      : 15.2.0.0
CompatibilityId : 0.0.0.0

Id              : 63ca2fa4-4f03-4f2b-a480-172fef340d3f
Name            : System Application
Publisher       : Microsoft
MinVersion      : 15.2.0.0
CompatibilityId : 0.0.0.0
```

## Get-D365BCPlatformVersion
### Short Description
Returns the "PlatformVersion"-property from a given Runtime-AppPackage (.app-file)

### Parameters
```
-Filename
```
**Filename**: (string) The full path to the File (.app) that the information should be read from

### Output

```
PS C:\run> Get-D365BCPlatformVersion -Filename C:\run\my\test\MyRuntimeApp.runtime.app

17.0.21485.22158
```