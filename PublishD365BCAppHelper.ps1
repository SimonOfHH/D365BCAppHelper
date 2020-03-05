$VerbosePreference="SilentlyContinue"
# Version, Author, CompanyName and nugetkey
. (Join-Path $PSScriptRoot ".\Private\settings.ps1")

$moduleName = "D365BCAppHelper"
Clear-Host
#Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings PSGallery -Severity Warning

Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Remove-Module $moduleName -ErrorAction Ignore
Uninstall-module $moduleName -ErrorAction Ignore

$path = "C:\temp\$moduleName"

if (Test-Path -Path $path) {
    Remove-Item -Path $path -Force -Recurse
}
Copy-Item -Path $PSScriptRoot -Destination "C:\temp" -Exclude @("settings.ps1", ".gitignore", "README.md", "Publish$moduleName.ps1","TestRunner.ps1") -Recurse
Remove-Item -Path (Join-Path $path ".git") -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $path "Tests") -Force -Recurse -ErrorAction SilentlyContinue

$modulePath = Join-Path $path "$moduleName.psm1"
Import-Module $modulePath -DisableNameChecking

#get-module -Name $moduleName

$functionsToExport = (get-module -Name $moduleName).ExportedFunctions.Keys | Sort-Object
$aliasesToExport = (get-module -Name $moduleName).ExportedAliases.Keys | Sort-Object

Update-ModuleManifest -Path (Join-Path $path "$moduleName.psd1") `
                      -RootModule "$moduleName.psm1" `
                      -ModuleVersion $version `
                      -Author $author `
                      -CompanyName $CompanyName #`
                      #-FunctionsToExport $functionsToExport #`
                      #-AliasesToExport $aliasesToExport `
                      #-FileList @("") `
                      #-ReleaseNotes (get-content (Join-Path $path "ReleaseNotes.txt")) 

Copy-Item -Path (Join-Path $path "$moduleName.psd1") -Destination $PSScriptRoot -Force
Publish-Module -Path $path -NuGetApiKey $powershellGalleryApiKey

Remove-Item -Path $path -Force -Recurse