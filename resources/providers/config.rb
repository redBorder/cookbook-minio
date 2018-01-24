# Cookbook Name:: example
#
# Provider:: config
#

action :add do #Usually used to install and configure something
  begin
     # ... your code here ...

     template "PATH/template1" do
       source "template1.erb"
       cookbook "example"
       #...
     end

     Chef::Log.info("Example cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do #Usually used to uninstall something
  begin
     # ... your code here ...
     Chef::Log.info("Example cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do #Usually used to register in consul
  begin
     # ... your code here ...
     Chef::Log.info("Example cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do #Usually used to deregister from consul
  begin
     # ... your code here ...
     Chef::Log.info("Example cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end
