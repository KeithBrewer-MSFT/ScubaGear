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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ProductNames', Justification = 'False positive as rule does not scan child scopes')]
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
    [Parameter(Mandatory = $true,  ParameterSetName = 'Auto')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Report')]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("teams", "exo", "defender", "aad", "powerplatform", "sharepoint", IgnoreCase = $false)]
    [string[]]
    $ProductNames = @("teams", "exo", "defender", "aad", "sharepoint"),
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
    function GetProductTestPlan{
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("teams", "exo", "defender", "aad", "powerplatform", "sharepoint", IgnoreCase = $false)]
            [string]
            $ProductName
        )

        $TestPlanPath = Join-Path -Path $PSScriptRoot -ChildPath "TestPlans/$ProductName.testplan.yaml"
        Test-Path -Path $TestPlanPath -PathType Leaf

        $YamlString = Get-Content -Path $TestPlanPath | Out-String
        $TestPlan = ConvertFrom-Yaml $YamlString
        $TestPlan
    }

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
}

Describe "Policy Checks for <_>" -ForEach $ProductNames{
    BeforeEach{
        $ProductTestPlan = GetProductTestPlan -ProductName $_
    }
    Context "Start tests for <_>" {
        It "Validate test plan for <_>" {
            $ProductTestPlan.ProductName | Should -Be $_ 
            $ProductTestPlan.ProductName | Should -Be $_
            $ProductTestPlan.TestPlan.GetType() | Should -BeOfType System.Object[]
        }
    }
    AfterEach {
        #SetConditions -Conditions $Postconditions
        #Stop-SeDriver -Driver $Driver 2>$null
    }
}
