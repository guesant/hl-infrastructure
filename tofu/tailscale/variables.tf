variable "device_hostname" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.device_hostname))
    error_message = "device_hostname must be the bare hostname the node advertises to the tailnet."
  }
}

variable "internal_domain" {
  type = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.internal_domain)) && !endswith(var.internal_domain, ".invalid")
    error_message = "internal_domain must be the real internal DNS zone, not a placeholder under .invalid."
  }
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "state_passphrase must have at least 32 characters."
  }

  validation {
    condition     = !startswith(var.state_passphrase, "REPLACE_WITH_")
    error_message = "state_passphrase still holds the placeholder; run just tofu-state-passphrase."
  }
}
