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
  start_time              = local.schedule_updatepsmodules_start_time
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

# Create the schedules
resource "azurerm_automation_schedule" "start-and-stop-vm-schedule" {
  for_each = local.startandstop_schedules

  name                    = each.key
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "Europe/Paris"
  start_time              = each.value
  description             = "Hourly schedule to start and stop VMs"
}

# And finally connect the schedules to the runbook
resource "azurerm_automation_job_schedule" "start-and-stop-vm-job" {
  for_each = local.startandstop_schedules

  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name
  schedule_name           = each.key
  runbook_name            = azurerm_automation_runbook.start-and-stop-vm.name

  parameters = {
    subscriptionid    = var.subscription-id
    resourcegroupname = azurerm_resource_group.rg.name
    tagname           = "StopStartSchedule"
    timezone          = "Romance Standard Time"
  }
}