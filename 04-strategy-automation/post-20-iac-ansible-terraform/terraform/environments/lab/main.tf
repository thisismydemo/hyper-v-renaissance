resource "hyperv_network_switch" "lab" {
  name                                    = var.switch_name
  notes                                   = "Post 20 lab switch"
  allow_management_os                     = true
  enable_embedded_teaming                 = length(var.net_adapter_names) > 1
  enable_iov                              = false
  enable_packet_direct                    = false
  minimum_bandwidth_mode                  = "None"
  switch_type                             = var.switch_type
  net_adapter_names                       = var.net_adapter_names
  default_flow_minimum_bandwidth_absolute = 0
  default_flow_minimum_bandwidth_weight   = 0
  default_queue_vmmq_enabled              = false
  default_queue_vmmq_queue_pairs          = 16
  default_queue_vrss_enabled              = false
}

module "lab_vm" {
  source = "../../modules/hyperv-vm"

  vm_name              = var.vm_name
  vm_path              = var.vm_path
  vhd_path             = var.vhd_path
  vhd_size_bytes       = var.vhd_size_bytes
  switch_name          = hyperv_network_switch.lab.name
  processor_count      = var.processor_count
  use_static_memory    = var.use_static_memory
  memory_startup_bytes = var.memory_startup_bytes
  memory_minimum_bytes = var.memory_minimum_bytes
  memory_maximum_bytes = var.memory_maximum_bytes
}

resource "terraform_data" "guest_bootstrap" {
  count = var.guest_bootstrap_enabled ? 1 : 0

  triggers_replace = [module.lab_vm.vm_id]

  connection {
    type     = "winrm"
    host     = var.guest_bootstrap_host
    user     = var.guest_bootstrap_user
    password = var.guest_bootstrap_password
    https    = true
    insecure = true
  }

  provisioner "file" {
    source      = "../../../scripts/Invoke-HyperVGuestBootstrap.ps1"
    destination = "C:/Windows/Temp/Invoke-HyperVGuestBootstrap.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:/Windows/Temp/Invoke-HyperVGuestBootstrap.ps1 -ComputerName '${var.guest_computer_name}' -TimeZoneId '${var.guest_time_zone_id}' -FeatureNamesCsv '${join(",", var.guest_feature_names)}' -DirectoryPathsCsv '${join(",", var.guest_directory_paths)}'"
    ]
  }
}

output "lab_vm_name" {
  value       = module.lab_vm.vm_name
  description = "Name of the provisioned lab VM."
}

output "lab_vm_vhd_path" {
  value       = module.lab_vm.vhd_path
  description = "Path to the lab VM VHDX."
}
