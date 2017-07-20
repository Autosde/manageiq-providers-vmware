class ManageIQ::Providers::Vmware::InfraManager::Inventory::Parser
  include Cluster
  include Datacenter
  include Folder
  include HostSystem
  include ResourcePool

  attr_reader :persister
  private     :persister

  def initialize(persister)
    @persister = persister
  end

  def parse(object, props)
    object_type = object.class.wsdl_name
    parse_method = "parse_#{object_type.underscore}"

    raise "Missing parser for #{object_type}" unless respond_to?(parse_method)

    send(parse_method, object, props)
  end

  def parse_compute_resource(object, props)
    persister.ems_clusters.manager_uuids << object._ref
    return if props.nil?

    cluster_hash = {
      :ems_ref => object._ref,
      :uid_ems => object._ref,
    }

    if props.include?("name")
      cluster_hash[:name] = URI.decode(props["name"])
    end

    parse_cluster_summary(cluster_hash, props)
    parse_cluster_das_config(cluster_hash, props)
    parse_cluster_drs_config(cluster_hash, props)
    parse_cluster_children(cluster_hash, props)

    persister.ems_clusters.build(cluster_hash)
  end
  alias parse_cluster_compute_resource parse_compute_resource

  def parse_datacenter(object, props)
    persister.ems_folders.manager_uuids << object._ref
    return if props.nil?

    dc_hash = {
      :ems_ref      => object._ref,
      :uid_ems      => object._ref,
      :type         => "EmsFolder",
      :ems_children => {},
    }

    if props.include?("name")
      dc_hash[:name] = URI.decode(props["name"])
    end

    parse_datacenter_children(dc_hash, props)

    persister.ems_folders.build(dc_hash)
  end

  def parse_datastore(object, props)
    persister.storages.manager_uuids << object._ref
    return if props.nil?

    storage_hash = {
      :ems_ref => object._ref,
    }

    if props.include?("summary.name")
      storage_hash[:name] = props["summary.name"]
    end
    if props.include?("summary.url")
      storage_hash[:location] = props["summary.url"]
    end

    persister.storages.build(storage_hash)
  end

  def parse_distributed_virtual_switch(object, props)
    persister.switches.manager_uuids << object._ref
    return if props.nil?

    switch_hash = {
      :uid_ems => object._ref,
      :shared  => true,
    }

    persister.switches.build(switch_hash)
  end
  alias parse_vmware_distributed_virtual_switch parse_distributed_virtual_switch

  def parse_folder(object, props)
    persister.ems_folders.manager_uuids << object._ref
    return if props.nil?

    folder_hash = {
      :ems_ref      => object._ref,
      :uid_ems      => object._ref,
      :type         => "EmsFolder",
      :ems_children => {},
    }

    if props.include?("name")
      folder_hash[:name] = URI.decode(props["name"])
    end

    parse_folder_children(folder_hash, props)

    persister.ems_folders.build(folder_hash)
  end

  def parse_host_system(object, props)
    persister.hosts.manager_uuids << object._ref
    return if props.nil?

    host_hash = {
      :ems_ref => object._ref,
    }

    parse_host_config(host_hash, props)
    parse_host_product(host_hash, props)
    parse_host_network(host_hash, props)
    parse_host_runtime(host_hash, props)
    parse_host_system_info(host_hash, props)
    parse_host_children(host_hash, props)

    host_hash[:type] = if host_hash.include?(:vmm_product) && !%w(esx esxi).include?(host_hash[:vmm_product].to_s.downcase)
                         "ManageIQ::Providers::Vmware::InfraManager::Host"
                       else
                         "ManageIQ::Providers::Vmware::InfraManager::HostEsx"
                       end

    host = persister.hosts.build(host_hash)

    parse_host_operating_system(host, props)
    parse_host_system_services(host, props)
    parse_host_hardware(host, props)
    parse_host_switches(host, props)
  end

  def parse_network(object, props)
  end
  alias parse_distributed_virtual_portgroup parse_network

  def parse_resource_pool(object, props)
    persister.resource_pools.manager_uuids << object._ref
    return if props.nil?

    rp_hash = {
      :ems_ref => object._ref,
      :uid_ems => object._ref,
      :vapp    => object.kind_of?(RbVmomi::VIM::VirtualApp),
    }

    if props.include?("name")
      rp_hash[:name] = URI.decode(props["name"])
    end

    parse_resource_pool_memory_allocation(rp_hash, props)
    parse_resource_pool_cpu_allocation(rp_hash, props)
    parse_resource_pool_children(rp_hash, props)

    persister.resource_pools.build(rp_hash)
  end
  alias parse_virtual_app parse_resource_pool

  def parse_virtual_machine(object, props)
    persister.vms_and_templates.manager_uuids << object._ref
    return if props.nil?

    vm_hash = {
      :ems_ref => object._ref,
      :vendor  => "vmware",
    }

    if props.include?("summary.config.uuid")
      vm_hash[:uid_ems] = props["summary.config.uuid"]
    end
    if props.include?("summary.config.name")
      vm_hash[:name] = URI.decode(props["summary.config.name"])
    end
    if props.include?("summary.config.vmPathName")
      vm_hash[:location] = props["summary.config.vmPathName"]
    end
    if props.include?("summary.config.template")
      vm_hash[:template] = props["summary.config.template"].to_s.downcase == "true"

      type = "ManageIQ::Providers::Vmware::InfraManager::#{vm_hash[:template] ? "Template" : "Vm"}"
      vm_hash[:type] = type
    end

    persister.vms_and_templates.build(vm_hash)
  end
end
