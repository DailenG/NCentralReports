#Requires -Module Pester
<#
.SYNOPSIS
    Pester unit tests for Get-NCPatchDetails.
    Tests run without any live API connection.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-NCPatchDetails.ps1')
}

Describe 'Get-NCPatchDetails' {

    Context 'Strict Schema: ApplianceTaskInformation' {

        It 'Extracts pme_status and pme_threshold_status from serviceDetails array' {
            $task = [PSCustomObject]@{
                serviceDetails = @(
                    [PSCustomObject]@{ detailName = 'pme_status'; detailValue = 'PME service stopped' }
                    [PSCustomObject]@{ detailName = 'pme_threshold_status'; detailValue = 'Threshold exceeded' }
                    [PSCustomObject]@{ detailName = 'other_field'; detailValue = 'irrelevant' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'PME service stopped'
            $result.PMEThresholdStatus | Should -Be 'Threshold exceeded'
        }

        It 'Returns N/A when pme_status is absent' {
            $task = [PSCustomObject]@{
                serviceDetails = @(
                    [PSCustomObject]@{ detailName = 'other_field'; detailValue = 'irrelevant' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'N/A'
            $result.PMEThresholdStatus | Should -Be 'N/A'
        }

        It 'Returns N/A for missing threshold when only pme_status present' {
            $task = [PSCustomObject]@{
                serviceDetails = @(
                    [PSCustomObject]@{ detailName = 'pme_status'; detailValue = 'Error loading PME' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Error loading PME'
            $result.PMEThresholdStatus | Should -Be 'N/A'
        }
    }

    Context 'Case-insensitive key matching' {

        It 'Matches PME_STATUS (uppercase) correctly' {
            $task = [PSCustomObject]@{
                serviceDetails = @(
                    [PSCustomObject]@{ detailName = 'PME_STATUS'; detailValue = 'Uppercase error' }
                    [PSCustomObject]@{ detailName = 'PME_THRESHOLD_STATUS'; detailValue = 'Uppercase threshold' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Uppercase error'
            $result.PMEThresholdStatus | Should -Be 'Uppercase threshold'
        }

        It 'Matches mixed-case Pme_Status correctly' {
            $task = [PSCustomObject]@{
                serviceDetails = @(
                    [PSCustomObject]@{ detailName = 'Pme_Status'; detailValue = 'Mixed case error' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Mixed case error'
        }
    }

    Context 'Empty or missing serviceDetails array' {

        It 'Returns Unknown when no serviceDetails array found at all' {
            $task = [PSCustomObject]@{ taskId = '123'; unrelated = 'field' }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Unknown'
            $result.PMEThresholdStatus | Should -Be 'Unknown'
        }

        It 'Returns Unknown when serviceDetails array is empty' {
            $task = [PSCustomObject]@{ serviceDetails = @() }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Unknown'
            $result.PMEThresholdStatus | Should -Be 'Unknown'
        }
    }

    Context 'RawDetails passthrough' {

        It 'Always includes RawDetails on the return object' {
            $task = [PSCustomObject]@{ serviceDetails = @() }
            $result = Get-NCPatchDetails -TaskObject $task
            
            $result.RawDetails | Should -Not -BeNullOrEmpty
            $result.RawDetails | Should -Be $task
        }
    }
}
