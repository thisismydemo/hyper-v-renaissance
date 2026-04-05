variable "vm_name" {
  type        = string
  description = "Name of the Hyper-V virtual machine."
}

variable "vm_path" {
  type        = string
  description = "Parent path where Hyper-V stores the VM configuration."
}

variable "vhd_path" {
  type        = string
  description = "Absolute path to the VHDX file."
}

variable "vhd_size_bytes" {
  type        = number
  description = "Virtual disk size in bytes."
}

variable "switch_name" {
  type        = string
  description = "Virtual switch to attach the VM to."
}

variable "processor_count" {
  type        = number
  description = "Number of virtual processors."
  default     = 2
}

variable "use_static_memory" {
  type        = bool
  description = "Whether the VM should use static memory."
  default     = false
}

variable "memory_startup_bytes" {
  type        = number
  description = "Startup memory in bytes."
  default     = 4294967296
}

variable "memory_minimum_bytes" {
  type        = number
  description = "Minimum dynamic memory in bytes."
  default     = 2147483648
}

variable "memory_maximum_bytes" {
  type        = number
  description = "Maximum dynamic memory in bytes."
  default     = 8589934592
}

variable "wait_for_ips" {
  type        = bool
  description = "Whether the provider should wait for guest IP assignment."
  default     = false
}

variable "secure_boot_enabled" {
  type        = bool
  description = "Whether secure boot should be enabled."
  default     = true
}
