Import-Module -Name $PSScriptRoot/../ExportEXOProvider.psm1 -Function Get-ScubaSpfRecords, Get-ScubaDkimRecords, Get-ScubaDmarcRecords
Import-Module -Name $PSScriptRoot/../ExportAADProvider.psm1 -Function Get-PrivilegedRole, Get-PrivilegedUser

# Any module can be auto imported upon discovery here.  So we need to restrict to approved versions to support
# Side-by-side powershell module installations.  
$ScubaManifest = Import-PowerShellDataFile (Join-Path -Path $PSScriptRoot -ChildPath '../../../ScubaGear.psd1')
$ScubaManifest.RequiredModules | ForEach-Object {
    if ($_.ModuleName.StartsWith('Microsoft.Graph')){
        Import-Module -Name $_.ModuleName -MinimumVersion $_.ModuleVersion.ToString() -MaximumVersion $_.MaximumVersion.ToString()
    }
}

class CommandTracker {
    [string[]]$SuccessfulCommands = @()
    [string[]]$UnSuccessfulCommands = @()

    [System.Object[]] TryCommand([string]$Command, [hashtable]$CommandArgs) {
        <#
        .Description
        Wraps the given Command inside a try/catch, run with the provided
        arguments, and tracks successes/failures. Unless otherwise specified,
        ErrorAction defaults to "Stop"
        .Functionality
        Internal
        #>
        if (-Not $CommandArgs.ContainsKey("ErrorAction")) {
            $CommandArgs.ErrorAction = "Stop"
        }

        try {
            $Result = & $Command @CommandArgs
            $this.SuccessfulCommands += $Command
            return $Result
        }
        catch {
            Write-Warning "Error running $($Command). $($_)"
            $this.UnSuccessfulCommands += $Command
            $Result = @()
            return $Result
        }
    }

    [System.Object[]] TryCommand([string]$Command) {
        <#
        .Description
        Wraps the given Command inside a try/catch and tracks successes/
        failures. No command arguments are specified beyond ErrorAction=Stop
        .Functionality
        Internal
        #>

        return $this.TryCommand($Command, @{})
    }

    [void] AddSuccessfulCommand([string]$Command) {
        $this.SuccessfulCommands += $Command
    }

    [void] AddUnSuccessfulCommand([string]$Command) {
        $this.UnSuccessfulCommands += $Command
    }

    [string[]] GetUnSuccessfulCommands() {
        return $this.UnSuccessfulCommands
    }

    [string[]] GetSuccessfulCommands() {
        return $this.SuccessfulCommands
    }

}

function Get-CommandTracker {
    [CommandTracker]::New()
}