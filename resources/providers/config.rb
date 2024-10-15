action :add do
  begin

    user = new_resource.user
    s3_bucket = new_resource.s3_bucket
    s3_endpoint = new_resource.s3_endpoint
    managers_with_minio = new_resource.managers_with_minio

    if !Minio::Helpers.s3_ready?
      s3_user = Minio::Helpers.generate_random_key(20)
      s3_password = Minio::Helpers.generate_random_key(40)
    else
      s3_user = new_resource.access_key_id
      s3_password = new_resource.secret_key_id
    end

    dnf_package 'minio' do
      action :upgrade
      flush_cache [:before]
    end

    execute 'create_user' do
      command '/usr/sbin/useradd -r minio'
      ignore_failure true
      not_if 'getent passwd minio'
    end

    %w(/var/minio /var/minio/data /etc/minio).each do |path|
      directory path do
        owner user
        group user
        mode '0755'
        action :create
      end
    end

    # MC tool configuration
    directory '/root/.mcli' do
      owner 'root'
      group 'root'
      mode '0755'
      action :create
    end

    template '/root/.mcli/config.json' do
      source 'mcli_config.json.erb'
      variables(
        s3_user: s3_user,
        s3_password: s3_password,
        managers_with_minio: managers_with_minio
      )
      notifies :restart, 'service[minio]', :delayed
    end

    service 'minio' do
      service_name 'minio'
      ignore_failure true
      supports status: true, reload: true, restart: true, enable: true
      action [:enable, :start]
      only_if { Minio::Helpers.exists_minio_conf? }
    end

    template '/etc/default/minio' do
      source 'minio.erb'
      variables(
        s3_user: s3_user,
        s3_password: s3_password
      )
      notifies :restart, 'service[minio]', :delayed
    end

    unless Minio::Helpers.s3_ready?
      template '/etc/redborder/s3_init_conf.yml' do
        source 's3_init_conf.yml.erb'
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_bucket: s3_bucket,
          s3_endpoint: s3_endpoint
        )
      end

      template '/root/.s3cfg_initial' do
        source 's3cfg_initial.erb'
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_endpoint: s3_endpoint
        )
      end
    end

    Chef::Log.info('Minio cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :add_s3_conf_nginx do
  service 'nginx' do
    service_name 'nginx'
    ignore_failure true
    supports status: true, reload: true, restart: true, enable: true
    action [:nothing]
  end

  execute 'rb_sync_minio_cluster' do
    command '/usr/lib/redborder/bin/rb_sync_minio_cluster.sh'
    action :nothing
  end

  s3_hosts = new_resource.s3_hosts
  template '/etc/nginx/conf.d/s3.conf' do
    ignore_failure true
    source 's3.conf.erb'
    owner 'nginx'
    group 'nginx'
    mode '0644'
    cookbook 'nginx'
    variables(s3_hosts: s3_hosts)
    notifies :restart, 'service[nginx]', :delayed
    notifies :run, 'execute[rb_sync_minio_cluster]', :delayed
    only_if { Minio::Helpers.check_remote_hosts(s3_hosts) }
  end
end

action :remove do
  begin

    service 'minio' do
      service_name 'minio'
      ignore_failure true
      supports status: true, enable: true
      action [:stop, :disable]
    end

    Chef::Log.info('Minio cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  ipaddress = new_resource.ipaddress

  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers && !node['minio']['registered']
      query = {}
      query['ID'] = "s3-#{node['hostname']}"
      query['Name'] = 's3'
      query['Address'] = ipaddress
      query['Port'] = node['minio']['port']
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        retries 3
        retry_delay 2
        action :nothing
      end.run_action(:run)

      node.normal['minio']['registered'] = true

      Chef::Log.info('Minio service has been registered on consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if consul_servers && node['minio']['registered']
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/s3-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['minio']['registered'] = false

      Chef::Log.info('Minio service has been deregistered from consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
