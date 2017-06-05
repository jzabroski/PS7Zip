# This script will invoke pester tests
# It should invoke on PowerShell v3 and later
# We serialize XML results and pull them in appveyor.yml
#If Finalize is specified, we collect XML output, upload tests, and indicate build errors

param(
    [switch]$Install,
    [switch]$Test,
    [switch]$DockerTest,
    [switch]$BetaTest,
    [switch]$Build,
    [switch]$Deploy,
    [switch]$Finalize
)

#Initialize some variables, move to the project root
$ProjectRoot = $ENV:APPVEYOR_BUILD_FOLDER
$Timestamp = Get-Date -uformat "%Y%m%d-%H%M%S"
$PSVersion = $PSVersionTable.PSVersion.ToString()
$TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
Write-Host "$ProjectRoot"

$Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
Set-Location $ProjectRoot

$Verbose = @{}
If ($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master") {
    $Verbose.add("Verbose",$True)
}

If ($Install) {
    If ($PSVersionTable.PSVersion -ge [Version]'5.0') {
        Install-PackageProvider Nuget -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Pester, platyPS, PSScriptAnalyzer -SkipPublisherCheck -Force
    } Else {
        nuget install Pester -source https://www.powershellgallery.com/api/v2 -outputDirectory "$Env:ProgramFiles\WindowsPowerShell\Modules\."
        nuget install platyPS -source https://www.powershellgallery.com/api/v2 -outputDirectory "$Env:ProgramFiles\WindowsPowerShell\Modules\."
        nuget install PSScriptAnalyzer -source https://www.powershellgallery.com/api/v2 -outputDirectory "$Env:ProgramFiles\WindowsPowerShell\Modules\."
    }
}

#Run a test with the current version of PowerShell, upload results
If ($Test) {
    "`n`tSTATUS: Testing with PowerShell $PSVersion`n"

    Import-Module Pester
    Invoke-Pester @Verbose -Path "$ProjectRoot\PS7Zip\Tests" -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -PassThru | Export-Clixml -Path "$ProjectRoot\PesterResults_PS$PSVersion`_$Timestamp.xml"

    If ($env:APPVEYOR_JOB_ID) {
        (New-Object 'System.Net.WebClient').UploadFile( $Address, "$ProjectRoot\$TestFile" )
    }
    
    # Test Alternative Install
    iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/GavinEke/PS7Zip/master/install.ps1'))
    Get-Module -Name PS7Zip -ListAvailable
}

If ($DockerTest) {
    Set-Location "$ProjectRoot\Docker"
    docker build -t nano -f NanoServer.Dockerfile .
    docker run nano
    Set-Location "$ProjectRoot"
}

If ($BetaTest) {
    $POWERSHELL6_MSI = "https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-beta.2/PowerShell-6.0.0-beta.2-win10-win2016-x64.msi"
    Invoke-WebRequest -Uri "$POWERSHELL6_MSI" -UseBasicParsing -OutFile "C:\PowerShell-win10-x64.msi"
    Start-Process -FilePath msiexec.exe -ArgumentList '-qn','-i C:\PowerShell-win10-x64.msi','-norestart' -wait
    $psexe=Get-Item -Path $Env:ProgramFiles\PowerShell\*\powershell.exe
    New-Item -Type SymbolicLink -Path $Env:ProgramFiles\PowerShell\ -Name latest -Value $psexe.DirectoryName
    & "C:\Program Files\PowerShell\latest\PowerShell.exe" -Command Invoke-Pester @Verbose -Path "$ProjectRoot\PS7Zip\Tests"
}

If ($Build) {
    Import-Module $ProjectRoot\PS7Zip -Force -ErrorAction SilentlyContinue
    New-MarkdownHelp -Module PS7Zip -OutputFolder "$ProjectRoot\PS7Zip\docs"
}

#Run a test with the current version of PowerShell, upload results
If ($Deploy) {
    Update-ModuleManifest -Path "$ProjectRoot\PS7Zip\PS7Zip.psd1" -ModuleVersion "$env:APPVEYOR_BUILD_VERSION"
    Import-Module $ProjectRoot\PS7Zip -Force -ErrorAction SilentlyContinue
    
    [Version]$PS7ZipGalleryVersion = Find-Package PS7Zip -ErrorAction Stop | Select-Object -ExpandProperty Version
    [Version]$PS7ZipLocalVersion = Get-Module PS7Zip -ErrorAction Stop | Select-Object -ExpandProperty Version
    
    If (($PS7ZipLocalVersion.Major -gt $PS7ZipGalleryVersion.Major) -or ($PS7ZipLocalVersion.Minor -gt $PS7ZipGalleryVersion.Minor)) {
        Write-Output "Deploying $PS7ZipLocalVersion to the PowerShell Gallery"
        Publish-Module -Path "$ProjectRoot\PS7Zip" -NuGetApiKey "$env:NuGetApiKey"
    }
    
    Compress-Archive -Path "$ProjectRoot\PS7Zip" -DestinationPath "$ProjectRoot\PS7Zip-$PS7ZipLocalVersion.zip"
    
    Push-AppveyorArtifact "$ProjectRoot\PS7Zip-$PS7ZipLocalVersion.zip"
}

#If finalize is specified, display errors and fail build if we ran into any
If ($Finalize) {
    #Show status...
        $AllFiles = Get-ChildItem -Path $ProjectRoot\PesterResults*.xml | Select -ExpandProperty FullName
        "`n`tSTATUS: Finalizing results`n"
        "COLLATING FILES:`n$($AllFiles | Out-String)"

    #What failed?
        $Results = @( Get-ChildItem -Path "$ProjectRoot\PesterResults_PS*.xml" | Import-Clixml )

        $FailedCount = $Results |
            Select -ExpandProperty FailedCount |
            Measure-Object -Sum |
            Select -ExpandProperty Sum

        If ($FailedCount -gt 0) {

            $FailedItems = $Results |
                Select -ExpandProperty TestResult |
                Where {$_.Passed -notlike $True}

            "FAILED TESTS SUMMARY:`n"
            $FailedItems | ForEach-Object {
                $Item = $_
                [pscustomobject]@{
                    Describe = $Item.Describe
                    Context = $Item.Context
                    Name = "It $($Item.Name)"
                    Result = $Item.Result
                }
            } |
                Sort Describe, Context, Name, Result |
                Format-List

            throw "$FailedCount tests failed."
        }
}
