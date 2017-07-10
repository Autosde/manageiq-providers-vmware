class ManageIQ::Providers::Vmware::InfraManager::Inventory::Parser
  module VirtualMachine
    def parse_virtual_machine_config(vm_hash, props)
      if props.include?("config.cpuAffinity.affinitySet")
        affinity_set = props["config.cpuAffinity.affinitySet"]

        cpu_affinity = nil
        cpu_affinity = affinity_set.kind_of?(Array) ? affinity_set.join(",") : affinity_set.to_s if affinity_set

        vm_hash[:cpu_affinity] = cpu_affinity
      end
      if props.include?("config.defaultPowerOps.standbyAction")
        standby_act = props["config.defaultPowerOps.standbyAction"]
        vm_hash[:standby_action] = standby_act unless standby_act.nil?
      end
      if props.include?("config.cpuHotAddEnabled")
        vm_hash[:cpu_hot_add_enabled] = props["config.cpuHotAddEnabled"]
      end
      if props.include?("config.cpuHotRemoveEnabled")
        vm_hash[:cpu_hot_remove_enabled] = props["config.cpuHotRemoveEnabled"]
      end
      if props.include?("config.memoryHotAddEnabled")
        vm_hash[:memory_hot_add_enabled] = props["config.memoryHotAddEnabled"]
      end
      if props.include?("config.hotPlugMemoryLimit")
        vm_hash[:memory_hot_add_limit] = props["config.hotPlugMemoryLimit"]
      end
      if props.include?("config.hotPlugMemoryIncrementSize")
        vm_hash[:memory_hot_add_increment] = props["config.hotPlugMemoryIncrementSize"]
      end
    end

    def parse_virtual_machine_summary(vm_hash, props)
      if props.include?("summary.config.uuid")
        uuid = props["summary.config.uuid"]
        unless uuid.blank?
          vm_hash[:uid_ems] = MiqUUID.clean_guid(uuid) || uuid
        end
      end
      if props.include?("summary.config.name")
        vm_hash[:name] = URI.decode(props["summary.config.name"])
      end
      if props.include?("summary.config.vmPathName")
        pathname = props["summary.config.vmPathName"]
        begin
          _storage_name, location = VmOrTemplate.repository_parse_path(pathname)
        rescue
          location = VmOrTemplate.location2uri(pathname)
        end
        vm_hash[:location] = location
      end
      if props.include?("summary.config.template")
        vm_hash[:template] = props["summary.config.template"].to_s.downcase == "true"

        type = "ManageIQ::Providers::Vmware::InfraManager::#{vm_hash[:template] ? "Template" : "Vm"}"
        vm_hash[:type] = type
      end
      if props.include?("summary.guest.toolsStatus")
        tools_status = props["summary.guest.toolsStatus"]
        tools_status = nil if tools_status.blank?

        vm_hash[:tools_status] = tools_status
      end

      parse_virtual_machine_summary_runtime(vm_hash, props)
    end

    def parse_virtual_machine_summary_runtime(vm_hash, props)
      if props.include?("summary.runtime.connectionState")
        vm_hash[:connection_state] = props["summary.runtime.connectionState"]
      end
      if props.include?("summary.runtime.host") && !props["summary.runtime.host"].nil?
        host = props["summary.runtime.host"]
        vm_hash[:host] = persister.hosts.lazy_find(host._ref)
      end
      if props.include?("summary.runtime.bootTime")
        vm_hash[:boot_time] = props["summary.runtime.bootTime"]
      end
      if props.include?("summary.runtime.powerState")
        vm_hash[:raw_power_state] = if props["summary.config.template"]
                                      "never"
                                    else
                                      props["summary.runtime.powerState"]
                                    end
      end
    end

    def parse_virtual_machine_memory_allocation(vm_hash, props)
      if props.include?("resourceConfig.memoryAllocation.reservation")
        vm_hash[:memory_reserve] = props["resourceConfig.memoryAllocation.reservation"]
      end
      if props.include?("resourceConfig.memoryAllocation.expandableReservation")
        expandable_reservation = props["resourceConfig.memoryAllocation.expandableReservation"]
        vm_hash[:memory_reserve_expand] = expandable_reservation.to_s.downcase == "true"
      end
      if props.include?("resourceConfig.memoryAllocation.limit")
        vm_hash[:memory_limit] = props["resourceConfig.memoryAllocation.limit"]
      end
      if props.include?("resourceConfig.memoryAllocation.shares.shares")
        vm_hash[:memory_shares] = props["resourceConfig.memoryAllocation.shares.shares"]
      end
      if props.include?("resourceConfig.memoryAllocation.shares.level")
        vm_hash[:memory_shares_level] = props["resourceConfig.memoryAllocation.shares.level"]
      end
    end

    def parse_virtual_machine_cpu_allocation(vm_hash, props)
      if props.include?("resourceConfig.cpuAllocation.reservation")
        vm_hash[:cpu_reserve] = props["resourceConfig.cpuAllocation.reservation"]
      end
      if props.include?("resourceConfig.cpuAllocation.expandableReservation")
        expandable_reservation = props["resourceConfig.cpuAllocation.expandableReservation"]
        vm_hash[:cpu_reserve_expand] = expandable_reservation.to_s.downcase == "true"
      end
      if props.include?("resourceConfig.cpuAllocation.limit")
        vm_hash[:cpu_limit] = props["resourceConfig.cpuAllocation.limit"]
      end
      if props.include?("resourceConfig.cpuAllocation.shares.shares")
        vm_hash[:cpu_shares] = props["resourceConfig.cpuAllocation.shares.shares"]
      end
      if props.include?("resourceConfig.cpuAllocation.shares.level")
        vm_hash[:cpu_shares_level] = props["resourceConfig.cpuAllocation.shares.level"]
      end
    end

    def parse_virtual_machine_resource_config(vm_hash, props)
      parse_virtual_machine_cpu_allocation(vm_hash, props)
      parse_virtual_machine_memory_allocation(vm_hash, props)
    end

    def parse_virtual_machine_operating_system(vm, props)
      return unless props.include?("summary.config.guestFullName")

      guest_full_name = props["summary.config.guestFullName"]

      persister.operating_systems.build(
        :vm_or_template => vm,
        :product_name   => guest_full_name.blank? ? "Other" : guest_full_name
      )
    end

    def parse_virtual_machine_hardware(vm, props)
      hardware_hash = {:vm_or_template => vm}

      if props.include?("summary.config.guestId")
        guest_id = props["summary.config.guestId"]
        hardware_hash[:guest_os] = guest_id.blank? ? "Other" : guest_id.to_s.downcase.chomp("guest")
      end
      if props.include?("summary.config.guestFullName")
        guest_full_name = props["summary.config.guestFullName"]
        hardware_hash[:guest_os_full_name] = guest_full_name.blank? ? "Other" : guest_full_name
      end
      if props.include?("summary.config.uuid")
        uuid = props["summary.config.uuid"]
        bios = MiqUUID.clean_guid(uuid) || uuid
        hardware_hash[:bios] = bios unless bios.blank?
      end
      if props.include?("summary.config.numCpu")
        hardware_hash[:cpu_total_cores] = props["summary.config.numCpu"].to_i
      end
      if props.include?("config.hardware.numCoresPerSocket")
        # cast numCoresPerSocket to an integer so that we can check for nil and 0
        cpu_cores_per_socket                 = props["config.hardware.numCoresPerSocket"].to_i
        hardware_hash[:cpu_cores_per_socket] = cpu_cores_per_socket.zero? ? 1 : cpu_cores_per_socket
        hardware_hash[:cpu_sockets]          = hardware_hash[:cpu_total_cores] / hardware_hash[:cpu_cores_per_socket]
      end
      if props.include?("summary.config.annotation")
        annotation = props["summary.config.annotation"]
        hardware_hash[:annotation] = annotation.present? ? annotation : nil
      end
      if props.include?("summary.config.memorySizeMB")
        memory_size_mb = props["summary.config.memorySizeMB"]
        hardware_hash[:memory_mb] = memory_size_mb unless memory_size_mb.blank?
      end
      if props.include?("config.version")
        config_version = props["config.version"]
        hardware_hash[:virtual_hw_version] = config_version.to_s.split('-').last unless config_version.blank?
      end

      persister.hardwares.build(hardware_hash)
    end

    def parse_virtual_machine_custom_attributes(vm, props)
      available_field = if props.include?("availableField")
                          props["availableField"]
                        end
      custom_values = if props.include?("summary.customValue")
                        props["summary.customValue"]
                      end

      key_to_name = {}
      available_field.to_a.each { |af| key_to_name[af["key"]] = af["name"] }

      custom_values.to_a.each do |cv|
        persister.custom_attributes.build(
          :resource => vm,
          :section  => "custom_field",
          :name     => key_to_name[cv["key"]],
          :value    => cv["value"],
          :source   => "VC",
        )
      end
    end

    def parse_virtual_machine_snapshots(vm, props)
    end
  end
end
