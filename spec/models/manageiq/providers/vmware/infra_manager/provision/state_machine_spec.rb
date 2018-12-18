describe ManageIQ::Providers::Vmware::InfraManager::Provision do
  context "::StateMachine" do
    before do
      ems      = FactoryBot.create(:ems_vmware_with_authentication)
      template = FactoryBot.create(:template_vmware, :ext_management_system => ems)
      vm       = FactoryBot.create(:vm_vmware)
      options  = {:src_vm_id => template.id}

      @task = FactoryBot.create(:miq_provision_vmware, :clone_to_vm, :source => template, :destination => vm, :state => 'pending', :status => 'Ok', :options => options)
      allow(@task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)
      allow(@task).to receive_messages(:dest_cluster => FactoryBot.create(:ems_cluster, :ext_management_system => ems))
    end

    include_examples "polling destination power status in provider"
  end
end
