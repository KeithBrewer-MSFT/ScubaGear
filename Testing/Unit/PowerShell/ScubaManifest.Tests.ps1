Describe -Tag 'Manifest' -Name 'Scuba Manaifest Checks' {
    It 'Validate scuba module manifest' {
        $ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "../../../../PowerShell/ScubaGear/ScubaGear.psd1"
        {Test-ModuleManifest -Path $ManifestPath}
        $LASTEXITCODE | Should -Be 0 -Because "expect test to have no errors"
    }
}