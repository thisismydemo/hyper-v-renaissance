resource "hyperv_vhd" "this" {
  path = var.vhd_path
  size = var.vhd_size_bytes
}

resource "hyperv_machine_instance" "dynamic" {
  count                = var.use_static_memory ? 0 : 1
  name                 = var.vm_name
  path                 = var.vm_path
  generation           = 2
  processor_count      = var.processor_count
  dynamic_memory       = true
  memory_startup_bytes = var.memory_startup_bytes
  memory_minimum_bytes = var.memory_minimum_bytes
  memory_maximum_bytes = var.memory_maximum_bytes
  automatic_stop_action = "ShutDown"
  automatic_start_action = "StartIfRunning"
  checkpoint_type       = "Production"
  state                 = "Running"

  vm_firmware {
    enable_secure_boot = var.secure_boot_enabled ? "On" : "Off"
    secure_boot_template = "MicrosoftWindows"
    preferred_network_boot_protocol = "IPv4"
    console_mode = "None"
    pause_after_boot_failure = "Off"
    boot_order {
      boot_type           = "HardDiskDrive"
      controller_number   = "0"
      controller_location = "0"
    }
    boot_order {
      boot_type            = "NetworkAdapter"
      network_adapter_name = "lan"
      switch_name          = var.switch_name
    }
  }

  vm_processor {
    compatibility_for_migration_enabled               = false
    compatibility_for_older_operating_systems_enabled = false
    hw_thread_count_per_core                          = 0
    maximum                                           = 100
    reserve                                           = 0
    relative_weight                                   = 100
    maximum_count_per_numa_node                       = 0
    maximum_count_per_numa_socket                     = 0
    enable_host_resource_protection                   = false
    expose_virtualization_extensions                  = false
  }

  integration_services = {
    "Guest Service Interface" = false
    "Heartbeat"               = true
    "Key-Value Pair Exchange" = true
    "Shutdown"                = true
    "Time Synchronization"    = true
    "VSS"                     = true
  }

  network_adaptors {
    name                                       = "lan"
    switch_name                                = var.switch_name
    management_os                              = false
    is_legacy                                  = false
    dynamic_mac_address                        = true
    static_mac_address                         = ""
    mac_address_spoofing                       = "Off"
    dhcp_guard                                 = "Off"
    router_guard                               = "Off"
    port_mirroring                             = "None"
    ieee_priority_tag                          = "Off"
    vmq_weight                                 = 100
    iov_queue_pairs_requested                  = 1
    iov_interrupt_moderation                   = "Off"
    iov_weight                                 = 100
    ipsec_offload_maximum_security_association = 512
    maximum_bandwidth                          = 0
    minimum_bandwidth_absolute                 = 0
    minimum_bandwidth_weight                   = 0
    mandatory_feature_id                       = []
    resource_pool_name                         = ""
    test_replica_pool_name                     = ""
    test_replica_switch_name                   = ""
    virtual_subnet_id                          = 0
    allow_teaming                              = "On"
    not_monitored_in_cluster                   = false
    storm_limit                                = 0
    dynamic_ip_address_limit                   = 0
    device_naming                              = "Off"
    fix_speed_10g                              = "Off"
    packet_direct_num_procs                    = 0
    packet_direct_moderation_count             = 0
    packet_direct_moderation_interval          = 0
    vrss_enabled                               = true
    vmmq_enabled                               = false
    vmmq_queue_pairs                           = 16
    vlan_access                                = false
    vlan_id                                    = 0
    wait_for_ips                               = var.wait_for_ips
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    path                = hyperv_vhd.this.path
    controller_number   = 0
    controller_location = 0
  }
}

resource "hyperv_machine_instance" "static" {
  count                = var.use_static_memory ? 1 : 0
  name                 = var.vm_name
  path                 = var.vm_path
  generation           = 2
  processor_count      = var.processor_count
  static_memory        = true
  memory_startup_bytes = var.memory_startup_bytes
  automatic_stop_action = "ShutDown"
  automatic_start_action = "StartIfRunning"
  checkpoint_type       = "Production"
  state                 = "Running"

  vm_firmware {
    enable_secure_boot = var.secure_boot_enabled ? "On" : "Off"
    secure_boot_template = "MicrosoftWindows"
    preferred_network_boot_protocol = "IPv4"
    console_mode = "None"
    pause_after_boot_failure = "Off"
    boot_order {
      boot_type           = "HardDiskDrive"
      controller_number   = "0"
      controller_location = "0"
    }
    boot_order {
      boot_type            = "NetworkAdapter"
      network_adapter_name = "lan"
      switch_name          = var.switch_name
    }
  }

  vm_processor {
    compatibility_for_migration_enabled               = false
    compatibility_for_older_operating_systems_enabled = false
    hw_thread_count_per_core                          = 0
    maximum                                           = 100
    reserve                                           = 0
    relative_weight                                   = 100
    maximum_count_per_numa_node                       = 0
    maximum_count_per_numa_socket                     = 0
    enable_host_resource_protection                   = false
    expose_virtualization_extensions                  = false
  }

  integration_services = {
    "Guest Service Interface" = false
    "Heartbeat"               = true
    "Key-Value Pair Exchange" = true
    "Shutdown"                = true
    "Time Synchronization"    = true
    "VSS"                     = true
  }

  network_adaptors {
    name                                       = "lan"
    switch_name                                = var.switch_name
    management_os                              = false
    is_legacy                                  = false
    dynamic_mac_address                        = true
    static_mac_address                         = ""
    mac_address_spoofing                       = "Off"
    dhcp_guard                                 = "Off"
    router_guard                               = "Off"
    port_mirroring                             = "None"
    ieee_priority_tag                          = "Off"
    vmq_weight                                 = 100
    iov_queue_pairs_requested                  = 1
    iov_interrupt_moderation                   = "Off"
    iov_weight                                 = 100
    ipsec_offload_maximum_security_association = 512
    maximum_bandwidth                          = 0
    minimum_bandwidth_absolute                 = 0
    minimum_bandwidth_weight                   = 0
    mandatory_feature_id                       = []
    resource_pool_name                         = ""
    test_replica_pool_name                     = ""
    test_replica_switch_name                   = ""
    virtual_subnet_id                          = 0
    allow_teaming                              = "On"
    not_monitored_in_cluster                   = false
    storm_limit                                = 0
    dynamic_ip_address_limit                   = 0
    device_naming                              = "Off"
    fix_speed_10g                              = "Off"
    packet_direct_num_procs                    = 0
    packet_direct_moderation_count             = 0
    packet_direct_moderation_interval          = 0
    vrss_enabled                               = true
    vmmq_enabled                               = false
    vmmq_queue_pairs                           = 16
    vlan_access                                = false
    vlan_id                                    = 0
    wait_for_ips                               = var.wait_for_ips
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    path                = hyperv_vhd.this.path
    controller_number   = 0
    controller_location = 0
  }
}
