function Global:Get-D365BCFobInfoFromFile {
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
        
    }
    process {
        if (-not(Test-Path $Filename)) {
            Throw "File $Filename does not exist."
        }
        if ([System.IO.Path]::GetExtension($Filename) -ne ".fob") {
            Throw 'Please use a Dynamics NAV object file with *.fob extension for this script.'
        }
        $DataArray = New-Object System.Collections.Generic.List[object]
        $reader = [System.IO.File]::OpenText($Filename)
        Write-Verbose "Reading FOB file..."
        try {
            for (; ; ) {
                $line = $reader.ReadLine()
                if ($line -eq $null) { 
                    break
                }
                $FirstCharacter = $line.Substring(0, 1)
                if ([byte][char]$FirstCharacter -eq 26) { 
                    break 
                }
                if ($FirstCharacter -ne ' ') {            
                    $ObjectType = $line.Substring(0, 9).Trim()
                    $ObjectID = $line.Substring(10, 10).Trim()
                    $ObjectName = $line.Substring(21, 30)
                    $ObjectDate = $line.Substring(54, 10).Trim()
                    $ObjectTime = $line.Substring(70, 8).Trim()
                } 
                else {
                    $ObjectSize = $line.Substring(10, 10)
                    $ObjectVersion = $line.Substring(21, 57)
                    $Obj = New-Object Psobject -Property @{
                        Type    = $ObjectType.Trim()
                        ID      = $ObjectID.Trim()
                        Name    = $ObjectName.Trim()
                        Date    = $ObjectDate.Trim()
                        Time    = $ObjectTime.Trim()
                        Size    = $ObjectSize.Trim()
                        Version = $ObjectVersion.Trim()
                    }
                    $DataArray.add($Obj)
                }
            }
        }
        finally {
            $reader.Close()
        }
        return $DataArray
    }
}