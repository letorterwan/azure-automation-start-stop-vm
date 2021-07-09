<#
    .SYNOPSIS
        This Azure Automation Runbook manages stop and start for Azure VM based on a tag defined on each VM.
        At least one schedule planned every hour must be linked to this runbook.
        Tag sample : Weekdays=07:00-20:00 / Weekends=0
            Weekdays=07:00-20:00 --> VM should be started between 7:00 and 20:00, stopped otherwise
            Weekends=0 --> VM should be stopped all weekend
            This combination ensures that the VM is started from monday to friday between 07:00 and 20:00 + stopped all weekend

    .DESCRIPTION
        The runbook gets the tag value and detect wether the VM should be started, stopped or left alone.
        Status of the VM is checked before sending a start or stop order.
        A schedule must be used to execute this runbook regularly (minimum is every hour, consider using multiple schedule to cover the operationan hours).
        This runbook can only be used for ARM VM (no Classic VM).
        Note that the Tag Name can be changed to match organization requirements.
        NB : A consequent part of this runbook is based on this work : https://azureis.fun/posts/Start-Stop-Azure-VM-with-Azure-Automation-and-Tags/ , go check it out

    .MODULES
		This runbook depends on the following Az Modules (they must be added to the automation account)
			Az.Compute
			Az.Resources
			Az.Accounts

    .VERSION
        1.0 Initial version of the script
#>

param(
    [parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [parameter(Mandatory = $false)]
    [string]$TagName = "StopStartSchedule",
    [parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    [parameter(Mandatory = $false)]
    [string]$TimeZone = "UTC"
)

### First step : Connect to Azure with RunAsAccount and set working subscription
# Connect to Azure
$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    
    Write-Output "Successfully logged into Azure subscription using Az cmdlets..."
}

catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Set subscription as context
try {
    Set-AzContext -Subscription $SubscriptionId
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Check if TimeZone parameter is OK
if ($TimeZone -match 'UTC' -or (Get-TimeZone -ListAvailable | find $TimeZone)) {
    Write-Output "Specified Time Zone $TimeZone is valid"
}
else {
    Write-Output "Specified Time Zone $TimeZone is invalid, please check the value. Exiting runbook."
    exit
}

### Second Step : Get all VM with the tag
if ($ResourceGroupName) {
    # Check if Resource Group exists within the subscription
    Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -ErrorVariable NoRG
    if ($NoRG) {
        Write-output "Specified RG $ResourceGroupName does not exist within the subscription. Exiting runbook."
        exit
    }
    else {
        $VMs = Get-AzResource -ResourceType "Microsoft.Compute/VirtualMachines" -ResourceGroupName $ResourceGroupName -TagName $TagName
        Write-Output "Found $($VMs.Count) VM in resource group $ResourceGroupName with $TagName defined"
    }
}
else {
    $VMs = Get-AzResource -ResourceType "Microsoft.Compute/VirtualMachines" -TagName $TagName
    Write-Output "Found $($VMs.Count) VM with tag $TagName defined"
}
# Exit now if no VM is detected
if (!$VMs) {
    Write-Output "No VM with state schedule management tag ($TagName) have been found in the provided scope (subId : $SubscriptionID / rg : $ResourceGroupName)"
    exit
}

### Third Step : Manage status for each VM
$VMActionList = @()
foreach ($VM in $VMs) {
    Write-Output "Processing $($VM.Name) virtual machine. It will be started or stopped if according tag value is matched"
    # Extract values from tag
    # Tag Sample : StopStartSchedule = Weekdays=07:00-20:00 / Weekends=0
    $ScheduleTagValue = ($VM.Tags).$TagName
    if ($ScheduleTagValue -like '*/*') {
        $WeekdaysUptime = (($ScheduleTagValue.Split('/')[0]).Split('=')[1]).Trim(' ')
        $WeekendsUptime = (($ScheduleTagValue.Split('/')[1]).Split('=')[1]).Trim(' ')
    }
    else {
        Write-Output "Stop and Start tag $ScheduleTagValue does not match expected value (i.e. Weekdays=07:00-20:00 / Weekends=0), exiting runbook."
        exit
    }

    # Check if weekdays value is ok / This should be reworked because its quite an ugly check
    $TimeTagRegex = '^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]-([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]'
    if ($WeekdaysUptime -match $TimeTagRegex -or $WeekdaysUptime -eq '0' -or $WeekdaysUptime -eq '1') {
        Write-Output "Weekdays uptime $WeekdaysUptime match expected value (i.e. Weekdays=07:00-20:00 or Weekdays=1), moving on."
    }
    else {
        Write-Output "Weekdays uptime $WeekdaysUptime does not match expected value (i.e. Weekdays=07:00-20:00 or Weekdays=1), exiting runbook."
        exit
    }
    # Same for weekends
    if ($WeekendsUptime -match $TimeTagRegex -or $WeekendsUptime -eq '0' -or $WeekendsUptime -eq '1') {
        Write-Output "Weekends uptime $WeekendsUptime match expected value (i.e. Weekends=07:00-20:00 or Weekends=1), moving on."
    }
    else {
        Write-Output "Weekends uptime $WeekendsUptime does not match expected value (i.e. Weekends=07:00-20:00 or Weekends=1), exiting runbook."
        exit
    }

    # Adjust time based on the timezone passed as argument (default UTC)
    # Beware, no control on the value passed as $TimeZone!
    $CurrentTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, $TimeZone)

    # Define schedule time to use depending on weekday / weekend
    If ($CurrentTime.DayOfWeek -like 'S*') {
        $ScheduledTime = $WeekendsUptime
    }
    else {
        $ScheduledTime = $WeekdaysUptime
    }

    # Extract start and stop time from the tag (looking like that 7:00AM-08:00PM, or 0 if VM should be stopped / 1 VM should be started)
    if ($ScheduledTime -eq '0') {
        $VMAction = "Stop"
    }
    elseif ($ScheduledTime -eq '1') {
        $VMAction = "Start"
    }
    else {
        $ScheduledTime = $ScheduledTime.Split('-')
        $ScheduledStartHour = $ScheduledTime[0].split(':')[0]
        $ScheduledStartMinute = $ScheduledTime[0].split(':')[1]
        $ScheduledStopHour = $ScheduledTime[1].split(':')[0]
        $ScheduledStopMinute = $ScheduledTime[1].split(':')[1]
                
        $ScheduledStartTime = Get-Date -Hour $ScheduledStartHour -Minute $ScheduledStartMinute -Second 0
        $ScheduledStopTime = Get-Date -Hour $ScheduledStopHour -Minute $ScheduledStopMinute -Second 0
    
        # Determine if an action should be done on the VM
        If (($CurrentTime -gt $ScheduledStartTime) -and ($CurrentTime -lt $ScheduledStopTime)) {
            #Current time is within the interval
            Write-Output "VM $($VM.Name) should be running now"
            $VMAction = "Start"
        }
        else {
            #Current time is outside of the operational interval
            Write-Output "VM $($VM.Name) should be stopped now"
            $VMAction = "Stop"
        }
    }

    # Get current power state for a VM
    $VM = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
    $VMCurrentState = ($VM.Statuses | Where-Object Code -like "*PowerState*").DisplayStatus
        
    # Start or Stop the VM according to the VM action. If the action matches the current state, do nothing.
    # States are checked against 'healthy' statuses to avoid sending a Start request to a Stopping VM
    if ($VMAction -eq "Start" -and ($VMCurrentState -like "*stopped*" -or $VMCurrentState -like "*deallocated")) {
        Write-Output "Starting VM $($VM.Name)"
        Start-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name
    }
    elseif ($VMAction -eq "Stop" -and $VMCurrentState -like "*running*") {
        Write-Output "Stopping VM $($VM.Name)"
        Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force
    }
    else { 
        Write-Output "VM $($VM.Name) already in target state ($VMCurrentState)"
    }
    
    # Build a table for results
    $VMInfo = "" | select VM, Action
    $VMInfo.VM = $VM.Name
    $VMInfo.Action = $VMAction
    $VMActionList += $VMInfo
}

Write-Output $VMActionList
Write-Output "Runbook completed."