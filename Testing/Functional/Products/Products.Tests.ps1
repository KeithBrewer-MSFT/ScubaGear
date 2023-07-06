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
    [Parameter(ParameterSetName = 'Auto')]
    [Parameter(ParameterSetName = 'Manual')]
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $M365Environment = 'gcc'
)

$ScubaModulePath = Join-Path -Path $PSScriptRoot -ChildPath "../../../../PowerShell/ScubaGear/ScubaGear.psd1"
Import-Module $ScubaModulePath
Import-Module Selenium

BeforeAll {
    $Product = 'teams'
    $OrganizationName = 'y2zj1'

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

    # Used for MS.TEAMS.4.1v1
    $AllowedDomains = New-Object Collections.Generic.List[String]
    $AllowedDomains.Add("allow001.org")
    $AllowedDomains.Add("allow002.org")
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'AllowAllDomains', Justification = 'Variable is used in ScriptBlock')]
    $AllowAllDomains = New-CsEdgeAllowAllKnownDomains
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'BlockedDomains', Justification = 'Variable is used in ScriptBlock')]
    $BlockedDomain = New-CsEdgeDomainPattern -Domain "blocked001.com"
}

Describe "Policy Checks for <PolicyId>" -ForEach @(
    @{
        PolicyId = 'MS.TEAMS.1.1v1'
        Tests = @(
            @{
                TestDescription = "Allows External Participant Give Request Control"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Test Draft Teams Minimum Viable Secure Configuration Baseline'; AllowExternalParticipantGiveRequestControl = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Does not Allows  External Participant Give Request Control"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Test Draft Teams Minimum Viable Secure Configuration Baseline'; AllowExternalParticipantGiveRequestControl = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.2.1v1'
        Tests = @(
            @{
                TestDescription = "Allows External Participant Give Request Control"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Test Draft Teams Minimum Viable Secure Configuration Baseline'; AllowAnonymousUsersToStartMeeting = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Does not Allows  External Participant Give Request Control"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Test Draft Teams Minimum Viable Secure Configuration Baseline'; AllowAnonymousUsersToStartMeeting = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.3.1v1'
        Tests = @(
            @{
                TestDescription = "Dialin bypass lobby; Everyone is autoadmitted user"
                Preconditions = @(
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AllowPSTNUsersToBypassLobby = $true}},
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AutoAdmittedUsers = 'EveryOne'}}
                )
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Dialin bypass lobby; Everyone not auto admitted user"
                Preconditions = @(
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AllowPSTNUsersToBypassLobby = $true}},
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AutoAdmittedUsers = 'EveryoneInCompany'}}
                )
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Dialin not bypass lobbyEveryone not auto admitted user"
                Preconditions = @(
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AllowPSTNUsersToBypassLobby = $false}},
                    @{Command = "Set-CsTeamsMeetingPolicy"; Splat = @{Identity = 'Global'; AutoAdmittedUsers = 'EveryoneInCompany'}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.4.1v1'
        Tests = @(
            # @{
            #     TestDescription = "Specify blocked domains"
            #     Preconditions = @(
            #         @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowedDomainsAsAList = $(New-CsEdgeAllowAllKnownDomains); BlockedDomains = @{Add = $BlockedDomain}}}
            #     )
            #     Postconditions = @()
            #     ExpectedResult = $false
            # },
            # @{
            #     TestDescription = "Specify Allowed domains"
            #     Preconditions = @(
            #         @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowFederatedUsers = $true; AllowedDomainsAsAList = $AllowedDomains}}
            #     )
            #     Postconditions = @()
            #     ExpectedResult = $false
            # },
            @{
                TestDescription = "Do not allow federated users"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowFederatedUsers = $false}}
                )
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.5.1v1'
        Tests = @(
            @{
                TestDescription = "AllowTeamsConsumerInbound; AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumerInbound = $true; AllowTeamsConsumer = $true}}
                )
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "AllowTeamsConsumerInbound; Not AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumerInbound = $true; AllowTeamsConsumer = $false}}
                )
                Postconditions = @()
                ExpectedResult = $true
            },
            @{
                TestDescription = "Not AllowTeamsConsumerInbound; AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumerInbound = $false; AllowTeamsConsumer = $true}}
                )
                Postconditions = @()
                ExpectedResult = $true
            },            @{
                TestDescription = "Not AllowTeamsConsumerInbound; Not AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumerInbound = $false; AllowTeamsConsumer = $false}}
                )
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.5.2v1'
        Tests = @(
            @{
                TestDescription = "AllowTeamsConsumerInbound; AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumer = $true}}
                )
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "AllowTeamsConsumerInbound; Not AllowTeamsConsumer"
                Preconditions = @(
                    @{Command = "Set-CsTenantFederationConfiguration"; Splat = @{AllowTeamsConsumer = $false}}
                )
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.6.1v1'
        Tests = @(
            @{
                TestDescription = "AllowPublicUsers"
                Preconditions = @(@{Command = "Set-CsTenantFederationConfiguration";  Splat = @{AllowPublicUsers = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Not AllowPublicUsers"
                Preconditions = @(@{Command = "Set-CsTenantFederationConfiguration";  Splat = @{AllowPublicUsers = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.7.1v1'
        Tests = @(
            @{
                TestDescription = "AllowEmailIntoChannel"
                Preconditions = @(@{Command = "Set-CsTeamsClientConfiguration";  Splat = @{AllowEmailIntoChannel = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Not AllowEmailIntoChannel"
                Preconditions = @(@{Command = "Set-CsTeamsClientConfiguration";  Splat = @{AllowEmailIntoChannel = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.8.1v1'
        Tests = @(
            @{
                TestDescription = "BlockedAppList"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; DefaultCatalogAppsType = 'BlockedAppList'}})
                Postconditions = @()
                ExpectedResult = $true
            },
            @{
                TestDescription = "AllowedAppList"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; DefaultCatalogAppsType = 'AllowedAppList'}})
                Postconditions = @()
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.8.2v1'
        Tests = @(
            @{
                TestDescription = "GlobalCatalogAppsType:Block; PrivateCatalogAppsType:Block"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; GlobalCatalogAppsType = 'BlockedAppList'; PrivateCatalogAppsType = 'BlockedAppList'}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "GlobalCatalogAppsType:Allow; PrivateCatalogAppsType:Block"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; GlobalCatalogAppsType = 'AllowedAppList'; PrivateCatalogAppsType = 'BlockedAppList'}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "GlobalCatalogAppsType:Block; PrivateCatalogAppsType:Allow"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; GlobalCatalogAppsType = 'BlockedAppList'; PrivateCatalogAppsType = 'AllowedAppList'}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "GlobalCatalogAppsType:Allow; PrivateCatalogAppsType:Allow"
                Preconditions = @(@{Command = "Set-CsTeamsAppPermissionPolicy";  Splat = @{Identity = 'Global'; GlobalCatalogAppsType = 'AllowedAppList'; PrivateCatalogAppsType = 'AllowedAppList'}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.8.3v1' # Not Checked
        Tests = @(
            @{
                TestDescription = "Not Checked"
                Preconditions = @()
                Postconditions = @()
                IsNotChecked = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.9.1v1'
        Tests = @(
            @{
                TestDescription = "AllowCloudRecording"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "Not AllowCloudRecording"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.9.3v1'
        Tests = @(
            @{
                TestDescription = "AllowCloudRecording:true; AllowRecordingStorageOutsideRegion:true"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $true; AllowRecordingStorageOutsideRegion = $true}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "AllowCloudRecording:true; AllowRecordingStorageOutsideRegion:false"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $true; AllowRecordingStorageOutsideRegion = $false}})
                Postconditions = @()
                ExpectedResult = $true
            },
            @{
                TestDescription = "AllowCloudRecording:false; AllowRecordingStorageOutsideRegion:true"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $false; AllowRecordingStorageOutsideRegion = $true}})
                Postconditions = @()
                ExpectedResult = $true
            },
            @{
                TestDescription = "AllowCloudRecording:false; AllowRecordingStorageOutsideRegion:false"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingPolicy";  Splat = @{Identity = 'Global'; AllowCloudRecording = $false; AllowRecordingStorageOutsideRegion = $false}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.10.1v1'
        Tests = @(
            @{
                TestDescription = "BroadcastRecordingMode:AlwaysEnabled"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingBroadcastPolicy";  Splat = @{Identity = 'Global'; BroadcastRecordingMode = 'AlwaysEnabled'}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "BroadcastRecordingMode:AlwaysDisabled"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingBroadcastPolicy";  Splat = @{Identity = 'Global'; BroadcastRecordingMode = 'AlwaysDisabled'}})
                Postconditions = @()
                ExpectedResult = $false
            },
            @{
                TestDescription = "BroadcastRecordingMode:UserOverride"
                Preconditions = @(@{Command = "Set-CsTeamsMeetingBroadcastPolicy";  Splat = @{Identity = 'Global'; BroadcastRecordingMode = 'UserOverride'}})
                Postconditions = @()
                ExpectedResult = $true
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.11.1v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.11.2v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.11.4v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.12.1v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.12.2v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.13.1v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.13.2v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    },
    @{
        PolicyId = 'MS.TEAMS.13.3v1'
        Tests = @(
            @{
                TestDescription = "Custom Implementation"
                Preconditions = @()
                Postconditions = @()
                IsCustomImplementation = $true
                ExpectedResult = $false
            }
        )
    }
){
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
    Context "Start tests for <PolicyId>" -ForEach $Tests{
        It "<TestDescription> [<PolicyId>]" -Tag "<PolicyId>" {

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
        It "Check <Product> (<LinkText>) tables" -ForEach @(
            @{Product = "teams"; LinkText = "Microsoft Teams"}
        ){
            $FoundPolicy = $false
            $DetailLink = Get-SeElement -Driver $Driver -Wait -By LinkText $LinkText
            $DetailLink | Should -Not -BeNullOrEmpty
            Invoke-SeClick -Element $DetailLink

            # For better performance turn off implict wait
            $Driver.Manage().Timeouts().ImplicitWait = New-TimeSpan -Seconds 0

            $Tables = Get-SeElement -Driver $Driver -By TagName 'table'
            $Tables.Count | Should -BeGreaterThan 1

            ForEach ($Table in $Tables){
                $Rows = Get-SeElement -Element $Table -By TagName 'tr'
                $Rows.Count | Should -BeGreaterThan 0

                if ($Table.GetProperty("id") -eq "tenant-data"){
                    $Rows.Count | Should -BeExactly 2
                    $TenantDataColumns = Get-SeElement -Target $Rows[1] -By TagName "td"
                    $Tenant = $TenantDataColumns[0].Text
                    $Tenant | Should -Be $OrganizationName -Because "Tenant is $Tenant"
                } else {
                    # Control report tables
                    ForEach ($Row in $Rows){
                        $RowHeaders = Get-SeElement -Element $Row -By TagName 'th'
                        $RowData = Get-SeElement -Element $Row -By TagName 'td'

                        ($RowHeaders.Count -eq 0 ) -xor ($RowData.Count -eq 0) | Should -BeTrue -Because "Any given row should be homogenious"

                        if ($RowHeaders.Count -gt 0){
                            $RowHeaders.Count | Should -BeExactly 5
                            $RowHeaders[0].text | Should -BeLikeExactly "Control ID"
                        }

                        if ($RowData.Count -gt 0){
                            $RowData.Count | Should -BeExactly 5

                            if ($RowData[0].text -eq $PolicyId){
                                $FoundPolicy = $true
                                $Msg = "Output folder: $OutputFolder; Expected: $ExpectedResult; Result: $($RowData[2].text); Details: $($RowData[4].text)"

                                if ($IsCustomImplementation){
                                    $RowData[2].text | Should -BeLikeExactly "N/A" -Because "custom policies should not have results. [$Msg]"
                                    $RowData[4].text | Should -Match 'Custom implementation allowed.'
                                }
                                elseif ($IsNotChecked){
                                    $RowData[2].text | Should -BeLikeExactly "N/A" -Because "custom policies should not have results. [$Msg]"
                                    $RowData[4].text | Should -Match 'Not currently checked automatically.'
                                }
                                elseif ($true -eq $ExpectedResult) {
                                    $RowData[2].text | Should -BeLikeExactly "Pass" -Because "expected policy to pass. [$Msg]"
                                    $RowData[4].text | Should -Match 'Requirement met'
                                }
                                elseif ($null -ne $ExpectedResult ) {
                                    if ('Shall' -eq $RowData[3].text){
                                        $RowData[2].text | Should -BeLikeExactly "Fail" -Because "expected policy to fail. [$Msg]"
                                    }
                                    elseif ('Should' -eq $RowData[3].text){
                                        $RowData[2].text | Should -BeLikeExactly "Warning" -Because "expected policy to warn. [$Msg]"
                                    }
                                    else {
                                        $RowData[2].text | Should -BeLikeExactly "Unknown" -Because "unexpected criticality. [$Msg]"
                                    }

                                    $RowData[4].text | Should -Not -BeNullOrEmpty
                                }
                                else {
                                   $false | Should -BeTrue -Because "policy should be custom, not checked, or have and expected result. [$Msg]"
                                }
                            }
                        }
                    }
                }
            }

            $FoundPolicy | Should -BeTrue -Because "all policies should have a result. [$PolicyId]"
            # Turn implict wait back on
            $Driver.Manage().Timeouts().ImplicitWait = New-TimeSpan -Seconds 10
        }
    }
    AfterEach {
        SetConditions -Conditions $Postconditions
        Stop-SeDriver -Driver $Driver 2>$null
    }
}
