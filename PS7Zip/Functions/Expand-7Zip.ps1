﻿<#
.SYNOPSIS
Extract contents of a compressed archive file
.DESCRIPTION
Use Expand-7Zip to extract the contents of an archive.
.EXAMPLE
Expand-7Zip archive.zip

Extract contents of archive.zip in the current working folder

.EXAMPLE
Expand-7Zip "c:\folder\files.gz"

Extract contents of c:\folder\files.gz into current working folder

.PARAMETER FullName
The full path of the compressed archive file.
.PARAMETER Remove
If $True this will remove the compressed version of the file only leaving the uncompressed contents.
.LINK
http://gavineke.com/PS7Zip/Expand-7Zip
#>
Function Expand-7Zip {
    [CmdletBinding(HelpUri='http://gavineke.com/PS7Zip/Expand-7Zip')]
    Param(
        [Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$True)]
        [ValidateScript({Test-Path $_})]
        [string]$FullName,

        [switch]$Remove
	)
	
	Begin {}
	
    Process {
        Write-Verbose -Message 'Extracting contents of compressed archive file'
        & "$7zaBinary" x "$FullName"
        If ($Remove) {
			Write-Verbose -Message 'Removing compressed archive file'
			Remove-Item -Path "$FullName" -Force
        }
	}
	
	End {}
	
}
