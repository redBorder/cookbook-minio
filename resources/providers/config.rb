action :add do #Usually used to install and configure something
  begin

    user = new_resource.user

    yum_package "minio" do
      action :upgrade
      flush_cache [:before]
    end

    user user do
      action :create
      system true
    end

    %w[ /var/minio /var/minio/data /etc/minio ].each do |path|
      directory path do
        owner user
        group user
        mode 0755
        action :create
      end
    end

    service "minio" do
      service_name "minio"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true, :enable => true
      action [:start, :enable]
    end

     Chef::Log.info("Minio cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin

    service "minio" do
      service_name "minio"
      ignore_failure true
      supports :status => true, :enable => true
      action [:stop, :disable]
    end

    Chef::Log.info("Minio cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end
action :register do
  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers
      query = {}
      query["ID"] = "s3-#{node["hostname"]}"
      query["Name"] = "s3"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = 443
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
         command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
         retries 3
         retry_delay 2
         action :nothing
      end.run_action(:run)

      Chef::Log.info("Minio service has been registered on consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/nginx-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      Chef::Log.info("Minio service has been deregistered from consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
