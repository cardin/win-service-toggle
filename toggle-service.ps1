<#
.SYNOPSIS
    Interactive prompt to toggle a Windows Service (i.e. enable or disable it).
    The script does a UAC Prompt for Administrator rights if it was invoked without one.
.PARAMETER serviceName
    The name of the service. Case insensitive
.NOTES
    Author:         Cardin Lee
    Website:        github.com/cardin
#>
[CmdletBinding(PositionalBinding=$true)]
param(
    [Parameter(Mandatory = $true)]
    [String]
    $serviceName,
    [Parameter()]
    [Int32]
    $priorDecision
)

function private:coloriseStatus($statusObj) {
    $statusStr = $statusObj.Status.toString().ToLower()
    $origColor = $host.UI.RawUI.ForegroundColor
    if ($statusStr -eq "running") {
        return "{Green}$statusStr{$origColor}"
    } else {
        return "{DarkYellow}$statusStr{$origColor}"
    }
}

function private:Write-Color() {
    Param (
        [string] $text = $(Write-Error "You must specify some text"),
        [switch] $NoNewLine = $false
    )

    $startColor = $host.UI.RawUI.ForegroundColor

    $text.Split( [char]"{", [char]"}" ) | ForEach-Object { $i = 0 } {
        if ($i % 2 -eq 0) {
            Write-Host $_ -NoNewline
        } else {
            if ($_ -in [enum]::GetNames("ConsoleColor")) {
                $host.UI.RawUI.ForegroundColor = ($_ -as [System.ConsoleColor])
            }
        }

        $i++
    }

    if (!$NoNewLine) {
        Write-Host
    }
    $host.UI.RawUI.ForegroundColor = $startColor
}
$origColor = $host.UI.RawUI.ForegroundColor

# Get Admin Status
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hasPriorDecision = $PSBoundParameters.ContainsKey('priorDecision')
if (!$isAdmin -and $hasPriorDecision) {
    # Script was restarted, but still not in admin mode
    Write-Color "{red}Unable to toggle {cyan}$serviceName{red}!"
    Write-Color "{red}You must allow Administrator mode!"
    Exit
}

# Get Service Status
$statusObj = Get-Service $serviceName -ErrorAction SilentlyContinue
if (!$statusObj) {
    Write-Color "{red}Service {cyan}$serviceName {red}does not exist!"
    Exit
}

# Get Decision Status
if (!$hasPriorDecision) {
    Write-Color "Service {cyan}$serviceName {$origColor}is $(coloriseStatus $statusObj). Do you want to toggle it?"
    $decision = $Host.UI.PromptForChoice("", "", @("&No"; "&Yes"), 0)
    Write-Host
}
else {
    $decision = $priorDecision
}

if ($decision) {
    # Restart As Admin (if not admin)
    if (!$isAdmin) {
        Write-Host "Attempting to restart as Admin"
        $exitCode = Start-Process pwsh -ArgumentList "-File $($script:MyInvocation.MyCommand.Definition) $serviceName $decision" -Verb RunAs -Wait -WindowStyle Hidden
        if ($exitCode.ExitCode -ne 0) {
            Write-Color "{red}Unable to toggle {cyan}$serviceName"
            Write-Color "{red}You must allow Administrator mode!"
            Write-Host
        }

        Write-Color "Service {cyan}$serviceName {$origColor}is now $(coloriseStatus $(Get-Service $serviceName)){$origColor}"
        Read-Host -Prompt "Press any key to continue..."
        Exit
    }
    if ($statusObj.Status -eq "Running") {
        Stop-Service $serviceName
    }
    else {
        Start-Service $serviceName
    }
}
