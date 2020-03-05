#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Export\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Export\Private\*.ps1 -ErrorAction SilentlyContinue )

# Dot source the files
Foreach ($import in @($Public)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
Foreach ($import in @($Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
Foreach ($import in $Public) {
    Export-ModuleMember -Function $import.Basename
}