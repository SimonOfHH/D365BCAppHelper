# D365BC-AppHelper
This module is used as a helper module for **Dynamics 365 Business Central** App handling. It's a work-in-progress, so new functionality might be added over time.

Current list of commands:
- [Get-AppDependencyInfo](#get-appDependencyInfo)
- [Write-DependencyTree](#write-dependencyTree)

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