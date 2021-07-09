# Locals used globally
locals {
  base_name = "startstoppoc"
  region    = "West Europe"
  common_tags = {
    env = "POC"
  }
  vm_tags = {
    StopStartSchedule = "Weekdays=16:00-17:30 / Weekends=0"
  }
}
