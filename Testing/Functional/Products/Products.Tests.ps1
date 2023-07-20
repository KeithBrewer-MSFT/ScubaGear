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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ProductName', Justification = 'False positive as rule does not scan child scopes')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'M365Environment', Justification = 'False positive as rule does not scan child scopes')]

[CmdletBinding(DefaultParameterSetName='Auto')]
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
    [Parameter(Mandatory = $true, ParameterSetName = 'Report')]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("teams", "exo", "defender", "aad", "powerplatform", "sharepoint", IgnoreCase = $false)]
    [string]
    $ProductName,
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

BeforeDiscovery{
    $TestPlanPath = Join-Path -Path $PSScriptRoot -ChildPath "TestPlans/$ProductName.testplan.yaml"
    Test-Path -Path $TestPlanPath -PathType Leaf

    $YamlString = Get-Content -Path $TestPlanPath | Out-String
    $ProductTestPlan = ConvertFrom-Yaml $YamlString
    $TestPlan = $ProductTestPlan.TestPlan.ToArray()
    $Tests = $TestPlan.Tests
}

BeforeAll{
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
        Invoke-SCuBA -CertificateThumbPrint $Thumbprint -AppId $AppId -Organization $Organization -Productnames $ProductName -OutPath . -M365Environment $M365Environment -Quiet

    }

    function LoadSPOTenantData($OutputFolder) {
        $SPOTenant = Get-Content "$OutputFolder/TestResults.json" -Raw | ConvertFrom-Json
        $SPOTenant
    }

    # Used to login to tenant first time
    ExecuteScubagear
}
Describe "Policy Checks for <ProductName>"{
    Context "Start tests for policy <PolicyId>" -ForEach $TestPlan{
        Context "Execute test, <TestDescription>" -ForEach $Tests {
            BeforeEach{
                SetConditions -Conditions $Preconditions
                ExecuteScubagear
                $ReportFolders = Get-ChildItem . -directory -Filter "M365BaselineConformance*" | Sort-Object -Property LastWriteTime -Descending
                $OutputFolder = $ReportFolders[0]
                $SPOTenant = LoadSPOTenantData($OutputFolder)
                # Search the results object for the specific requirement we are validating and ensure the results are what we expect
                $PolicyResultObj = $SPOTenant | Where-Object { $_.PolicyId -eq $PolicyId }
                $BaselineReports = Join-Path -Path $OutputFolder -ChildPath 'BaselineReports.html'
                $script:url = (Get-Item $BaselineReports).FullName
                $Driver = Start-SeChrome -Headless -Arguments @('start-maximized') 2>$null
                Open-SeUrl $script:url -Driver $Driver 2>$null
            }
            It "Check intermediate results" {

                $PolicyResultObj.RequirementMet | Should -Be $ExpectedResult

                $Details = $PolicyResultObj.ReportDetails
                $Details | Should -Not -BeNullOrEmpty -Because "expect detials, $Details"

                if ($IsNotChecked){
                    $Details | Should -Match 'Not currently checked automatically.'
                }

                if ($IsCustomImplementation){
                    $Details | Should -Match 'Custom implementation allowed.'
                }
            }
            It "Execute test" {
                $_.Count | Should -BeGreaterThan 0
            }
            AfterEach {
                SetConditions -Conditions $$_.Postconditions
                #Stop-SeDriver -Driver $Driver 2>$null
            }
        }
    }
}
