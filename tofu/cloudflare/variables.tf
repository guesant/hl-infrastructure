variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "blog_hostname" {
  type = string
}

variable "state_passphrase" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "state_passphrase must be at least 32 characters."
  }
}
