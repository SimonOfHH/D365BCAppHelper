function Global:Get-D365BCLicenseInfo {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Returns the custom-objects from a license summary file in an easy to process object-format
    .DESCRIPTION
        ...
    .PARAMETER LicensInfoFile
        [string] The License summary (txt) File you want to grab the information from (mandatory)
    .OUTPUTS
        Array of [PSCustomObject]@{
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
    #>
    param(        
        [parameter(Mandatory = $true)]
        [string]
        $LicensInfoFile
    )
    function Get-D365BCLicenseInfoCustomAreaObjects {
        param(        
            [parameter(Mandatory = $true)]
            [string]
            $SourceString,
            [parameter(Mandatory = $true)]
            [ValidateSet("Purchased", "Assigned")]
            [string]
            $Area
        )
        $SourceString = $SourceString.Replace($Area, "").Trim()
        $Type = $SourceString.Substring(0, $SourceString.IndexOf(".")).Trim()
        $Number = [int]$SourceString.Substring($SourceString.IndexOf(".:")).Replace(".:", "").Trim()
        $info = [PSCustomObject]@{
            Type   = $Type
            Number = $Number
        }
        $info
    }
    function Update-ArrayCustomAreaObjects {
        param(
            [parameter(Mandatory = $true)]        
            [ref]
            $ObjectArray,
            [parameter(Mandatory = $true)]
            [string]
            $SourceString
        )
        # Get identifier ("Purchased" or "Assigned") from string
        $Identifier = $SourceString.Substring(0, $SourceString.IndexOf(" ")).Trim()
        # Get the actual values as an object
        $info = Get-D365BCLicenseInfoCustomAreaObjects -SourceString $SourceString -Area $Identifier
        # Find the array-entry and update it
        $licenseInfo = $ObjectArray.Value | Where-Object { $_.Type -eq $info.Type }
        if ($Identifier -eq "Purchased") {
            $licenseInfo.Purchased = $info.Number
        }
        else {
            $licenseInfo.Assigned = $info.Number
        }
        $licenseInfo.Remaining = $licenseInfo.Purchased - $licenseInfo.Assigned
    }
    function Compress-ObjectIdRanges() {
        param(
            [parameter(Mandatory = $true)]        
            [ref]
            $ObjectArray
        )
        # If there are ID ranges that are practically consecutive, but split over multiple lines,
        # this function will summarize them into one entry
        foreach ($objInfo in $ObjectArray.Value) {
            $newRanges = @()
            $iNewRanges = -1
            foreach ($range in $objInfo.Ranges) {
                if ($prevRange.End + 1 -eq $range.Start) {
                    $newRanges[$iNewRanges].End = $range.End
                    $newRanges[$iNewRanges].Quantity += $range.Quantity
                }
                else {
                    $newRanges += $range
                    $iNewRanges++
                }
                $prevRange = $range
            }
            $objInfo.Ranges = $newRanges
        }
    }
    # Prepare array, only with types but without further values
    $licenseInfos = @()
    "TableData", "Report", "Codeunit", "Page", "XMLPort", "Query" | ForEach-Object {
        $licenseInfos += [PSCustomObject]@{
            Type      = $_
            Purchased = 0
            Assigned  = 0
            Remaining = 0
            Ranges    = @()
        }    
    }
    # Regular Expression to identify lines in "Custom Area Objects"-block
    $patternCustomAreaObjects = '(Purchased|Assigned)\s(TableData|Report|Codeunit|Page|XMLPort|Query).*: \d{1,5}'
    # Regular Expression to identify lines in "Object Assignment"-block
    $patternObjectAssignment = '(TableData|Report|Codeunit|Page|XMLPort|Query)\s*?\d{1,5}\s*\d{1,5}\s*\d{1,5}'
    $customAreaObjectsSection = $false
    $objectAssignmentSection = $false
    foreach ($s in Get-Content -Path $LicensInfoFile) {
        if ($s.Trim() -eq 'Custom Area Objects') {
            $customAreaObjectsSection = $true
        }
        if ($s.Trim() -eq 'Object Assignment') {
            $customAreaObjectsSection = $false
            $objectAssignmentSection = $true
        }
        if ($s.Trim() -eq 'Module Objects and Permissions') {
            $customAreaObjectsSection = $false
            $objectAssignmentSection = $false
            Compress-ObjectIdRanges -ObjectArray ([ref]$licenseInfos)
        }
        if ($customAreaObjectsSection -eq $true) {
            if ($s -match $patternCustomAreaObjects) {
                Update-ArrayCustomAreaObjects -ObjectArray ([ref]$licenseInfos) -SourceString $s
            }
        }
        if ($objectAssignmentSection -eq $true) {
            if ($s -match $patternObjectAssignment) {
                $split = $s -split '\s+'
                $licenseInfo = $licenseInfos | Where-Object { $_.Type -eq $split[0] }
                $licenseInfo.Ranges += [PSCustomObject]@{
                    Quantity = [int]$split[1]
                    Start    = [int]$split[2]
                    End      = [int]$split[3]
                }
            }
        }
    }
    $licenseInfos
}
Export-ModuleMember Get-D365BCLicenseInfo