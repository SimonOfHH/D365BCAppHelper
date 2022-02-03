function Global:Get-D365BCObjectsFromPath {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns AL objects from a given directory in an easy to process object-format
    .DESCRIPTION
        ...
    .PARAMETER Path
        [string] Specifies a path to a directory containing AL files.
    .PARAMETER CustomPattern
        [string] Overwrites the default pattern to identify objects
    .PARAMETER Recurse
        [switch] Gets the items in the specified locations and in all child items of the locations.
    .OUTPUTS
        Array of [PSCustomObject]@{
                    Type      = <ObjectType>
                    ID        = <ObjectID>
                    Name      = <ObjectName>
                }  
    #>
    param(
        [parameter(Mandatory = $true)]        
        [string]
        $Path,
        [parameter(Mandatory = $false)]
        [string]
        $CustomPattern,
        [parameter(Mandatory = $false)]
        [switch]
        $Recurse
    )
    begin {
        # TODO: Create pattern that also includes controladdin, dotnet, entitlement, pagecustomization, profile
        # (right now  this only includes licensable objects)
        $pattern = '(codeunit|enum|enumextension|interface|page|pageextension|permissionset|permissionsetextension|query|report|reportextension|table|tableextension|xmlport) \d* .*\r\n{'
        if ($CustomPattern) { $pattern = $CustomPattern }
    }
    process {
        function Get-D365BCRawObjectsFromPath {
            param(
                [parameter(Mandatory = $true)]        
                [string]
                $Path,
                [parameter(Mandatory = $true)]
                [string]
                $Pattern,
                [parameter(Mandatory = $true)]
                [switch]
                $Recurse
            )
            $alFiles = Get-ChildItem -Path $Path -Filter "*.al" -Recurse:$Recurse
            $rawObjects = @()
            foreach ($alFile in $alFiles) {            
                # Using Get-Content here as a workaround, because using "Select-String" directly seems to make it impossible to have a multi-line match
                $result = Get-Content -Path $alFile.FullName -Raw | Select-String -Pattern $pattern -AllMatches 
                if ($result.Matches) {                
                    $result.Matches | ForEach-Object { $rawObjects += $_.Value.Replace("{", "").Trim() }
                }
            }
            $rawObjects
        }
        function Get-D365BCEntryAsObject {
            param(
                [parameter(Mandatory = $true)]        
                [string]
                $RawObject
            )
            # TODO: Think about adding "extends"-info as well
            $type = $RawObject.Substring(0, $RawObject.IndexOf(" "))
            $RawObject = $RawObject.Substring($RawObject.IndexOf(" ")).Trim()
            $id = $RawObject.Substring(0, $RawObject.IndexOf(" "))
            $RawObject = $RawObject.Substring($RawObject.IndexOf(" ")).Trim()
            $name = $RawObject
            if ($name.Contains(" extends ")) {
                $name = $name.Substring(0, $name.IndexOf(" extends"))
            }
            $typedObject = [PSCustomObject]@{
                Type = $type
                ID   = [int]$id
                Name = $name.Replace('"', '')
            }
            $typedObject
        }
        $rawObjects = Get-D365BCRawObjectsFromPath -Path $Path -Pattern $pattern -Recurse:$Recurse
        $objects = @()
        foreach ($rawObject in $rawObjects) {
            $object = Get-D365BCEntryAsObject -RawObject $rawObject
            $objects += $object
        }
        , $objects
    }
}
Export-ModuleMember Get-D365BCObjectsFromPath