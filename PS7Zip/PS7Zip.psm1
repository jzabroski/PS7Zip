<#
    Parts of this module use the 7-Zip program.
    7-Zip is licensed under the GNU LGPL license.
    www.7-zip.org
#>

# PSScriptRoot Fix
If (!($PSScriptRoot)) {
    $PSScriptRoot = Split-Path "$MyInvocation.MyCommand.Path" -Parent
}

# Set 7zaBinary variable to match OSArchitecture
Write-Verbose -Message 'Setting 7zaBinary variable to match OSArchitecture'
If ([Environment]::Is64BitOperatingSystem) {
	$7zaBinary = "$PSScriptRoot\Bin\64-bit\7za.exe"
} Else {
	$7zaBinary = "$PSScriptRoot\Bin\32-bit\7za.exe"
}

# Test if 7zaBinary is accessible
Write-Verbose -Message 'Test if 7zaBinary is accessible'
If (-not (Test-Path $7zaBinary)) {
	Write-Error -Message '7za.exe binary file could not be found'
}

# Dot source the modules functions
Write-Verbose -Message 'Dot source the modules functions'
. "$PSScriptRoot\Functions\Compress-7Zip.ps1"
. "$PSScriptRoot\Functions\Expand-7Zip.ps1"
. "$PSScriptRoot\Functions\Get-7Zip.ps1"
