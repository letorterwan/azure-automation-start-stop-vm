# Locals used globally
locals {
  base_name = "startstoppoc"
  region    = "West Europe"
  common_tags = {
    env = "POC"
  }
  vm_tags = {
    StopStartSchedule = "Weekdays=17:00-17:30 / Weekends=0"
  }

  # Schedules Start Time (as they cannot start in the past, the date and time must be updated prior first deployment)
  schedule_updatepsmodules_start_time = "2021-12-31T05:00:00+01:00" # A future update should manage this more dynamically
  # List here all shedules to create in UTC time, the timezone attribute will be added to this as a parameter of the jobs
  startandstop_schedules = {
      schedule1 = "2021-12-31T13:00:00+00:00"
      schedule2 = "2021-12-31T13:30:00+00:00"
    }
}
