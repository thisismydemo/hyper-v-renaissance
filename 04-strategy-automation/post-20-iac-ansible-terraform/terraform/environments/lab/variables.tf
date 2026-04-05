variable "hyperv_user" {
  type        = string
  description = "User account used by the Terraform Hyper-V provider."
}

variable "hyperv_password" {
  type        = string
  description = "Password for the Hyper-V provider account."
  sensitive   = true
}

variable "hyperv_host" {
  type        = string
  description = "Hostname or IP of the Hyper-V host endpoint."
}

variable "hyperv_port" {
  type        = number
  description = "WinRM port used by the provider."
  default     = 5986
}

variable "hyperv_use_https" {
  type        = bool
  description = "Whether the provider should use WinRM over HTTPS."
  default     = true
}

variable "hyperv_insecure" {
  type        = bool
  description = "Whether to skip certificate validation for the provider connection."
  default     = true
}

variable "hyperv_use_ntlm" {
  type        = bool
  description = "Whether the provider should use NTLM authentication."
  default     = true
}

variable "hyperv_tls_server_name" {
  type        = string
  description = "Optional TLS server name override for WinRM."
  default     = ""
}

variable "hyperv_cacert_path" {
  type        = string
  description = "Optional CA certificate path for WinRM TLS validation."
  default     = ""
}

variable "hyperv_cert_path" {
  type        = string
  description = "Optional client certificate path."
  default     = ""
}

variable "hyperv_key_path" {
  type        = string
  description = "Optional client private key path."
  default     = ""
}

variable "switch_name" {
  type        = string
  description = "Name of the lab virtual switch."
}

variable "switch_type" {
  type        = string
  description = "Hyper-V switch type. Use Internal for isolated labs or External when binding physical adapters."
  default     = "Internal"
}

variable "net_adapter_names" {
  type        = list(string)
  description = "Physical adapter names to bind to the switch when using an External switch."
  default     = []
}

variable "vm_name" {
  type        = string
  description = "Name of the lab VM."
}

variable "vm_path" {
  type        = string
  description = "Parent path for the VM configuration."
}

variable "vhd_path" {
  type        = string
  description = "Absolute VHDX path."
}

variable "vhd_size_bytes" {
  type        = number
  description = "VHDX size in bytes."
}

variable "processor_count" {
  type        = number
  description = "Number of virtual processors."
  default     = 2
}

variable "use_static_memory" {
  type        = bool
  description = "Whether to disable dynamic memory."
  default     = false
}

variable "memory_startup_bytes" {
  type        = number
  description = "Startup memory in bytes."
  default     = 4294967296
}

variable "memory_minimum_bytes" {
  type        = number
  description = "Minimum memory in bytes for dynamic memory."
  default     = 2147483648
}

variable "memory_maximum_bytes" {
  type        = number
  description = "Maximum memory in bytes for dynamic memory."
  default     = 8589934592
}

variable "guest_bootstrap_enabled" {
  type        = bool
  description = "Whether to copy and run the guest PowerShell bootstrap script over WinRM."
  default     = false
}

variable "guest_bootstrap_host" {
  type        = string
  description = "Guest hostname or IP reachable via WinRM after provisioning."
  default     = ""
}

variable "guest_bootstrap_user" {
  type        = string
  description = "Guest administrator account used for WinRM bootstrap."
  default     = ""
}

variable "guest_bootstrap_password" {
  type        = string
  description = "Guest administrator password used for WinRM bootstrap."
  default     = ""
  sensitive   = true
}

variable "guest_computer_name" {
  type        = string
  description = "Desired computer name to apply inside the guest."
  default     = ""
}

variable "guest_time_zone_id" {
  type        = string
  description = "Guest time zone to configure."
  default     = "UTC"
}

variable "guest_feature_names" {
  type        = list(string)
  description = "Windows features to install during bootstrap."
  default     = []
}

variable "guest_directory_paths" {
  type        = list(string)
  description = "Directories to create during guest bootstrap."
  default     = []
}
