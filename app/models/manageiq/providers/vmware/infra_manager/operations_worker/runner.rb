class ManageIQ::Providers::Vmware::InfraManager::OperationsWorker::Runner < ManageIQ::Providers::BaseManager::OperationsWorker::Runner
  def do_before_work_loop
    # Set the cache_scope to minimal for ems_operations
    MiqVim.cacheScope = :cache_scope_core

    # Prime the cache before starting the do_work loop
    ems.connect
  end
end
