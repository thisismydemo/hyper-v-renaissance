output "vm_name" {
  description = "Virtual machine name."
  value       = try(hyperv_machine_instance.dynamic[0].name, hyperv_machine_instance.static[0].name)
}

output "vm_id" {
  description = "Terraform resource identifier for the VM."
  value       = try(hyperv_machine_instance.dynamic[0].id, hyperv_machine_instance.static[0].id)
}

output "vhd_path" {
  description = "Path to the VM's VHDX."
  value       = hyperv_vhd.this.path
}
