#Requires -Version 5.1
<#
    .SYNOPSIS
        This script installs the required Powershell modules used by the
        assessment tool
    .DESCRIPTION
        Installs the modules required to support SCuBAGear.  If the Force
        switch is set then any existing module will be re-installed even if
        already at latest version. If the SkipUpdate switch is set then any
        existing module will not be updated to th latest version.
    .EXAMPLE
        .\Setup.ps1
    .NOTES
        Executing the script with no switches set will install the latest
        version of a module if not already installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Installs a given module and overrides warning messages about module installation conflicts. If a module with the same name already exists on the computer, Force allows for multiple versions to be installed. If there is an existing module with the same name and version, Force overwrites that version')]
    [switch]
    $Force,

    [Parameter(HelpMessage = 'If specified then modules will not be updated to latest version')]
    [switch]
    $SkipUpdate,

    [Parameter(HelpMessage = 'Do not automatically trust the PSGallery repository for module installation')]
    [switch]
    $DoNotAutoTrustRepository,

    [Parameter(HelpMessage = 'Do not download OPA')]
    [switch]
    $NoOPA
)

# Set preferences for writing messages
$DebugPreference = "Continue"
$InformationPreference = "Continue"

if (-not $DoNotAutoTrustRepository) {
    $Policy = Get-PSRepository -Name "PSGallery" | Select-Object -Property -InstallationPolicy

    if ($($Policy.InstallationPolicy) -ne "Trusted") {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Write-Information -MessageData "Setting PSGallery repository to trusted."
    }
}

# Start a stopwatch to time module installation elapsed time
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$ScubaManifest = Import-PowerShellDataFile (Join-Path -Path $PSScriptRoot -ChildPath 'PowerShell/ScubaGear/ScubaGear.psd1')

foreach ($Module in $ScubaManifest.RequiredModules) {

    $ModuleName = $Module.ModuleName
    $InstalledApprovedModuleVersions = Get-Module -ListAvailable -Name $ModuleName |
        Where-Object  {[Version]($_.Version) -le $Module.MaximumVersion -and [Version]($_.Version) -ge $Module.ModuleVersion}

    if ($InstalledApprovedModuleVersions) {
        $HighestInstalledApprovedVersion = ($InstalledApprovedModuleVersions |
          Sort-Object Version -Descending |
          Select-Object Version -First 1).Version
        $LatestVersion = [Version](Find-Module -Name $ModuleName -MinimumVersion $Module.ModuleVersion -MaximumVersion $Module.MaximumVersion).Version

        if ($HighestInstalledApprovedVersion -ge $LatestVersion) {
            Write-Debug "${ModuleName}:${HighestInstalledApprovedVersion} already has latest installed."

            if ($Force -eq $true) {
                Install-Module -Name $ModuleName `
                    -Force `
                    -NoClobber `
                    -Scope CurrentUser `
                    -SkipPublisherCheck `
                    -MaximumVersion $Module.MaximumVersion
                Write-Information -MessageData "Re-installing module to latest acceptable version: ${ModuleName}"
            }
        }
        else {
            if ($SkipUpdate -eq $true) {
                Write-Debug "Skipping update for ${ModuleName}:${HighestInstalledApprovedVersion} to newer version ${LatestVersion}."
            }
            else {
                Install-Module -Name $ModuleName `
                    -Force `
                    -NoClobber `
                    -Scope CurrentUser `
                    -SkipPublisherCheck `
                    -MaximumVersion $Module.MaximumVersion
                $MaxInstalledVersion = (Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object Version -First 1).Version
                Write-Information -MessageData " ${ModuleName}:${HighestInstalledApprovedVersion} updated to version ${MaxInstalledVersion}."
            }
        }
    }
    else {
        Install-Module -Name $ModuleName `
            -Force `
            -NoClobber `
            -Scope CurrentUser `
            -SkipPublisherCheck `
            -MaximumVersion $Module.MaximumVersion
        $InstalledApprovedModuleVersions = Get-Module -ListAvailable -Name $ModuleName |
            Where-Object  {[Version]($_.Version) -le $Module.MaximumVersion -and [Version]($_.Version) -ge $Module.ModuleVersion}
        $MaxInstalledApprovedVersion = ($InstalledApprovedModuleVersions | Sort-Object Version -Descending | Select-Object Version -First 1).Version
        Write-Information -MessageData "Installed the latest acceptable version of ${ModuleName} version ${MaxInstalledApprovedVersion}"
    }
}

if ($NoOPA -eq $true) {
    Write-Debug "Skipping Download for OPA."
}
else {
    $DebugPreference = 'Continue'
    try {
    $ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    . $ScriptDir\OPA.ps1
    }
    catch {
        Write-Error "An error occurred: cannot call OPA download script"
    }
}

# Stop the clock and report total elapsed time
$Stopwatch.stop()

Write-Debug "ScubaGear setup time elapsed:  $([math]::Round($stopwatch.Elapsed.TotalSeconds,0)) seconds."

$DebugPreference = "SilentlyContinue"
$InformationPreference = "SilentlyContinue"
