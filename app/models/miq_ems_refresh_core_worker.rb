class MiqEmsRefreshCoreWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["ems_inventory"]

  def self.has_required_role?
    return false if Settings.ems_refresh.vmwarews.streaming_refresh
    super
  end

  def self.ems_class
    ManageIQ::Providers::Vmware::InfraManager
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_REFRESH_CORE_WORKERS
  end

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      ems.nil? ? queue_name.titleize : "Core Refresh Worker for Provider: #{ems.name}"
    end
  end
end
