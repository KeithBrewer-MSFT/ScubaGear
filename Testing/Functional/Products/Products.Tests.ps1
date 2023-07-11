<#
    .SYNOPSIS
    Test script for MS365 Teams product.
    .DESCRIPTION
    Test script to execute Invoke-SCuBA against a given tenant using a service
    principal. Verifies that all teams policies work properly.
    .PARAMETER Thumbprint
    Thumbprint of the certificate associated with the Service Principal.
    .PARAMETER Organization
    The tenant domain name for the organization.
    .PARAMETER AppId
    The Application Id associated with the Service Principal and certificate.
    .EXAMPLE
    $TestContainer = New-PesterContainer -Path "Teams.Tests.ps1" -Data @{ Thumbprint = $Thumbprint; Organization = "cisaent.onmicrosoft.com"; AppId = $AppId }
    Invoke-Pester -Container $TestContainer -Output Detailed
    .EXAMPLE
    Invoke-Pester -Script .\Testing\Functional\Auto\Products\Teams\Teams.Tests.ps1 -Output Detailed

#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Thumbprint', Justification = 'False positive as rule does not scan child scopes')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Organization', Justification = 'False positive as rule does not scan child scopes')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'AppId', Justification = 'False positive as rule does not scan child scopes')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'M365Environment', Justification = 'False positive as rule does not scan child scopes')]
[CmdletBinding(DefaultParameterSetName='Manual')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Auto')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Thumbprint,
    [Parameter(Mandatory = $true, ParameterSetName = 'Auto')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Organization,
    [Parameter(Mandatory = $true,  ParameterSetName = 'Auto')]
    [ValidateNotNullOrEmpty()]
    [string]
    $AppId,
    [Parameter(Mandatory = $false)]
    [Parameter(ParameterSetName = 'Auto')]
    [Parameter(ParameterSetName = 'Manual')]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("teams", "exo", "defender", "aad", "powerplatform", "sharepoint", "onedrive", '*', IgnoreCase = $false)]
    [string[]]
    $ProductNames = @("teams", "exo", "defender", "aad", "sharepoint", "onedrive"),
    [Parameter(ParameterSetName = 'Auto')]
    [Parameter(ParameterSetName = 'Manual')]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $M365Environment = 'gcc'
)

$ScubaModulePath = Join-Path -Path $PSScriptRoot -ChildPath "../../../PowerShell/ScubaGear/ScubaGear.psd1"
Import-Module $ScubaModulePath
Import-Module Selenium

BeforeAll {
    function SetConditions {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [array]
            $Conditions
        )

        ForEach($Condition in $Conditions){
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Splat', Justification = 'Variable is used in ScriptBlock')]
            $Splat = $Condition.Splat
            $ScriptBlock = [ScriptBlock]::Create("$($Condition.Command) @Splat")

            try {
                $ScriptBlock.Invoke()
            }
            catch [Newtonsoft.Json.JsonReaderException]{
                Write-Error $PSItem.ToString()
            }
        }
    }

    function ExecuteScubagear() {
        # Execute ScubaGear to extract the config data and produce the output JSON
        Invoke-SCuBA -productnames teams -Login $false -OutPath . -Quiet
    }

    function LoadSPOTenantData($OutputFolder) {
        $SPOTenant = Get-Content "$OutputFolder/TestResults.json" -Raw | ConvertFrom-Json
        $SPOTenant
    }

    function GetProductTestPlan(){
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("teams", "exo", "defender", "aad", "powerplatform", "sharepoint", "onedrive", '*', IgnoreCase = $false)]
            [string[]]
            $ProductName
        )

        $FileName = Join-Path -Path $PSScriptRoot -ChildPath "TestPlans/$ProductName.testplan.yaml"

        if (Test-Path -Path $FileName -PathType Leaf){
            $Plan = Get-Content -Path $FileName -Raw | ConvertFrom-Yaml
        }
        else {
            Write-Warning "Test plan, $FileName, does not exist. Skipping . . ."
        }

        return $Plan.TestPlan
    }

    # Used for MS.TEAMS.4.1v1
    # $AllowedDomains = New-Object Collections.Generic.List[String]
    # $AllowedDomains.Add("allow001.org")
    # $AllowedDomains.Add("allow002.org")
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'AllowAllDomains', Justification = 'Variable is used in ScriptBlock')]
    # $AllowAllDomains = New-CsEdgeAllowAllKnownDomains
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'BlockedDomains', Justification = 'Variable is used in ScriptBlock')]
    # $BlockedDomain = New-CsEdgeDomainPattern -Domain "blocked001.com"
}
Describe "Retrieve test plan for <_>" -ForEach $ProductNames {
    BeforeEach {
        $TestPlan = GetProductTestPlan -ProductName $_
    }
    Context "For each policy $($TestPlan.PolicyId)" -ForEach @($TestPlan.Tests){
            It "One" {
                $_.TestDescription | Should -Be "2"
            }
    }
}
