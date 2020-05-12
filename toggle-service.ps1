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
# Get Admin Status
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hasPriorDecision = $PSBoundParameters.ContainsKey('priorDecision')
if (!$isAdmin -and $hasPriorDecision) {
    # Script was restarted, but still not in admin mode
    Write-Host "You must allow Administrator mode!"
    Exit
}

# Get Service Status
$statusObj = Get-Service $serviceName -ErrorAction SilentlyContinue
if (!$statusObj) {
    Write-Host "Service $serviceName does not exist!"
    Exit
}

# Get Decision Status
if (!$hasPriorDecision) {
    $question = "Service $serviceName is $($statusObj.Status.ToString().ToLower()). Do you want to toggle it?"
    $decision = $Host.UI.PromptForChoice("", $question, @("&No"; "&Yes"), 0)
}
else {
    $decision = $priorDecision
}

if ($decision) {
    # Restart As Admin (if not admin)
    if (!$isAdmin) {
        Write-Host "Attempting to restart as Admin"
        Start-Process pwsh -ArgumentList "-File $($script:MyInvocation.MyCommand.Definition) $serviceName $decision" -Verb RunAs -Wait -WindowStyle Hidden
        Write-Host "Service $serviceName is now $($(Get-Service $serviceName).Status.toString().ToLower())"
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
