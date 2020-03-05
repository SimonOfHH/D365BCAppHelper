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
```
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
Set "AppName"
```
-AppName
[-AppPublisher]
[-ServerInstance]
[-Tenant]
[-IncludeUninstalled]
[-Level]
```
Set "AppObject" (only used internally, when called recursively)
```
-App <PSObject>
[-AppName]
[-AppPublisher]
[-Level]
```
### Example
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
