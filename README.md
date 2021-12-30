# Azure Automation - Start and Stop VM
This sample combines terraform and powershell to deploy an Azure Automation account with runbooks and schedules in order to manage VM off-hours state.

Terraform is used to create Azure resources that will run the powershell runbook. The runbook itself stops and starts VMs based on a tag defined on them (see instructions below). Please note that this runbook do not manage each day of the week independently but as 2 groups : weekdays and weekends. It means that a VM will be stopped and started every day from monday to friday and/or from saturday to sunday.

This runbook will target all VMs in a defined subscription, a specific resource group in that subscription can be specified for more precise targetting.

## Instructions
The main focus is on the tag you deploy on your VM. The default name is *StartStopSchedule* but it can be changed to match your organization tagging policy.

The value of the tag must match the following expression : *Weekdays=07:00-22:00 / Weekends=09:00-20:00*.
Values for *weekdays* and *weekends* can be :
- **0** : VM should be stopped all involved days
- **1** : VM should be started all involved days
- **01:00-22:00** : VM should be started between 01:00 and 22:00 (and stopped otherwise)

Using this sample should be easy :
1. Clone this repo
2. Deploy the tag on your target VMs (check the *locals.tf* file for tag sample)
3. Get rid of the sample VM if you don't need to test it first
4. Rename the *terraform.tfvars.sample* file into *terraform.tfvars* and update the subscription ID
5. Update the *locals.tf* file to define schedules according to your needs and update if necessary the parameters sent to the runbook in the *r-runbook.tf* file (see Runbook part below)


## Runbook

The runbook accepts 4 parameters:
| Parameter         | Value                 | Mandatory  | Default value     |
| ----------------- |-----------------------| -----------| ------------------|
| subscriptionid    | ID of the target sub  | yes        | N/A               |
| resourcegroupname | Name of target RG     | no         | N/A               |
| tagname           | Name of the tag on VM | no         | StartStopSchedule |
| timezone          | Timezone              | no         | UTC               |

Parameters are passed to the runbook this way (their names must be lowercase) :

```hcl
  parameters = {
    subscriptionid    = var.subscription-id
    resourcegroupname = azurerm_resource_group.rg.name
    tagname           = "StopStartSchedule"
    timezone          = "Romance Standard Time"
  }
```
## Terraform

In its actual state, this sample will deploy the following resources:
- A resource group
- An automation account (without the mandatory RunAsAccount, must be created manually)
- Powershell modules needed by the runbook (Az.Account, etc.) in the automation account
- Powershell runbooks and schedules
  - **Update powershell modules** with a schedule : once a month
  - **Start and Stop VM** with 2 schedules to run the script every half hour : on every plain hour (i.e. 10:00) and one every hour and a half (i.e 10:30)