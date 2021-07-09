### Create a runbook to update PS modules
# Create the runbook using the GItHub source
resource "azurerm_automation_runbook" "update-psmodules" {
  name                    = "AzureAutomation-Account-Modules-Update"
  location                = local.region
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "This runbook updates the powershell Az modules"
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "https://raw.githubusercontent.com/microsoft/AzureAutomation-Account-Modules-Update/master/Update-AutomationAzureModulesForAccount.ps1"
  }
}

# Create the schedule
resource "azurerm_automation_schedule" "update-psmodules-schedule" {
  name                    = "Update PS Az Modules schedule"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  frequency               = "Month"
  interval                = 1
  timezone                = "Europe/Paris"
  start_time              = "2021-07-01T05:00:00+01:00" # A future update should manage this more dynamically
  description             = "Monthly schedule to update PS Az modules"
  month_days              = ["1"]
}

# And finally connect the schedule to the runbook
resource "azurerm_automation_job_schedule" "update-psmodules-job" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  schedule_name           = azurerm_automation_schedule.update-psmodules-schedule.name
  runbook_name            = azurerm_automation_runbook.update-psmodules.name

  parameters = {
    azuremoduleclass        = "Az"
    resourcegroupname       = azurerm_resource_group.rg.name
    automation_account_name = azurerm_automation_account.automation-account.name
  }
}

### Create a runbook to start and stop VMs based on their tags
# Create the runbook using the PS script
data "local_file" "start-and-stop-vm-script" {
  filename = "${path.module}/powershell/StartStop-AzureVM.ps1"
}

resource "azurerm_automation_runbook" "start-and-stop-vm" {
  name                    = "Start-and-Stop-VMs"
  location                = local.region
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "This runbook starts and stops VMs based on their tags"
  runbook_type            = "PowerShell"
  content                 = data.local_file.start-and-stop-vm-script.content
}

# Create the schedule
resource "azurerm_automation_schedule" "start-and-stop-vm-schedule" {
  name                    = "Start and Stop VMs schedule"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "Europe/Paris"
  start_time              = "2021-07-08T13:00:00+00:00" # UTC time, the timezone attribute will be added to this
  description             = "Hourly schedule to start and stop VMs"
}

# And finally connect the schedule to the runbook
resource "azurerm_automation_job_schedule" "start-and-stop-vm-job" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  schedule_name           = azurerm_automation_schedule.start-and-stop-vm-schedule.name
  runbook_name            = azurerm_automation_runbook.start-and-stop-vm.name

  parameters = {
    subscriptionid    = var.subscription-id
    resourcegroupname = azurerm_resource_group.rg.name
    tagname           = "StopStartSchedule"
    timezone          = "Romance Standard Time"
  }
}

# Schedule sample to handle start and stop at half-hour
resource "azurerm_automation_schedule" "start-and-stop-vm-schedule-2" {
  name                    = "Start and Stop VMs schedule - Half-hour"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "Europe/Paris"
  start_time              = "2021-07-08T14:30:00+00:00" # UTC time, the timezone attribute will be added to this
  description             = "Hourly schedule to start and stop VMs"
}

resource "azurerm_automation_job_schedule" "start-and-stop-vm-job-2" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  schedule_name           = azurerm_automation_schedule.start-and-stop-vm-schedule-2.name
  runbook_name            = azurerm_automation_runbook.start-and-stop-vm.name

  parameters = {
    subscriptionid    = var.subscription-id
    resourcegroupname = azurerm_resource_group.rg.name
    tagname           = "StopStartSchedule"
    timezone          = "Romance Standard Time"
  }
}