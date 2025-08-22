# Cookbook:: minio
# Provider:: config

include Minio::Helpers

action :add do
  begin
    user = new_resource.user
    s3_bucket = new_resource.s3_bucket
    s3_malware_bucket = new_resource.s3_malware_bucket
    s3_endpoint = new_resource.s3_endpoint
    s3_malware_endpoint = new_resource.s3_malware_endpoint
    managers_with_minio = new_resource.managers_with_minio
    cdomain = get_cdomain

    if !s3_ready?
      s3_user = generate_random_key(20)
      s3_password = generate_random_key(40)
      s3_malware_user = generate_random_key(20)
      s3_malware_password = generate_random_key(40)
    else
      s3_user = new_resource.access_key_id
      s3_password = new_resource.secret_key_id
      s3_malware_user = new_resource.malware_access_key_id
      s3_malware_password = new_resource.malware_secret_key_id
    end

    dnf_package 'minio' do
      action :upgrade
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

    service 'minio' do
      service_name 'minio'
      ignore_failure true
      supports status: true, reload: true, restart: true, enable: true
      action [:enable, :start]
      only_if { exists_minio_conf? }
    end

    template '/etc/default/minio' do
      source 'minio.erb'
      variables(
        s3_user: s3_user,
        s3_password: s3_password
      )
      notifies :restart, 'service[minio]', :delayed
    end

    unless s3_ready?
      template '/etc/redborder/s3_init_conf.yml' do
        source 's3_init_conf.yml.erb'
        cookbook 'minio'
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_bucket: s3_bucket,
          s3_endpoint: s3_endpoint,
          s3_malware_user: s3_malware_user,
          s3_malware_password: s3_malware_password,
          s3_malware_bucket: s3_malware_bucket,
          s3_malware_endpoint: s3_malware_endpoint,
          cdomain: cdomain
        )
      end

      template '/root/.s3cfg_initial' do
        source 's3cfg_initial.erb'
        cookbook 'minio'
        variables(
          s3_user: s3_user,
          s3_password: s3_password,
          s3_endpoint: s3_endpoint,
          cdomain: cdomain
        )
      end
    end

    ruby_block 'check_minio_replication' do
      block do
        if managers_with_minio.count > 1 && mcli?(node['name'])
          if replication_started?
            if !member_of_replication_cluster?(node['name']) && follower?
              add_to_minio_replication(managers_with_minio, node['name'])
              Chef::Log.info("Added node to Minio replication : #{node['name']}")
            end
          elsif follower?
            add_to_minio_replication(managers_with_minio, node['name'])
            Chef::Log.info("Minio replication started on #{managers_with_minio}")
          end
        else
          Chef::Log.info('no Minio replication on 1 node minio cluster')
        end
      end
      action :run
      only_if { s3_running? }
    end

    Chef::Log.info('Minio cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :add_malware do
  begin
    create_malware_credentials = new_resource.create_malware_credentials
    s3_endpoint = new_resource.s3_endpoint
    s3_malware_endpoint = new_resource.s3_malware_endpoint
    cdomain = get_cdomain

    if create_malware_credentials
      Chef::Log.info('Creating new malware credentials')
      s3_malware_user = generate_random_key(20)
      s3_malware_password = generate_random_key(40)
    else
      s3_malware_user = new_resource.malware_access_key_id
      s3_malware_password = new_resource.malware_secret_key_id
    end

    template '/root/.s3cfg_malware_initial' do
      source 's3cfg_malware_initial.erb'
      cookbook 'minio'
      variables(
        s3_user: s3_malware_user,
        s3_password: s3_malware_password,
        s3_endpoint: s3_endpoint,
        s3_malware_endpoint: s3_malware_endpoint,
        cdomain: cdomain
      )
    end

    template '/etc/redborder/s3_malware_policy.json' do
      source 's3_malware_policy.json.erb'
      cookbook 'minio'
    end

    ruby_block 'configure_malware' do
      block do
        create_malware_user(s3_malware_user, s3_malware_password)
        create_malware_policy(s3_malware_user, '/etc/redborder/s3_malware_policy.json')
        Chef::Log.info('Malware user and policy created')
      end
    end

    Chef::Log.info('Added malware user and policy to Minio')
  rescue => e
    Chef::Log.error("Error creating malware user and policy: #{e.message}")
  end
end

action :add_s3_conf_nginx do
  s3_hosts = new_resource.s3_hosts
  cdomain = get_cdomain

  service 'nginx' do
    service_name 'nginx'
    ignore_failure true
    supports status: true, reload: true, restart: true, enable: true
    action [:nothing]
  end

  template '/etc/nginx/conf.d/s3.conf' do
    ignore_failure true
    source 's3.conf.erb'
    owner 'nginx'
    group 'nginx'
    mode '0644'
    cookbook 'nginx'
    variables(s3_hosts: s3_hosts, cdomain: cdomain)
    notifies :restart, 'service[nginx]', :delayed
  end
end

action :add_mcli do
  managers_with_minio = new_resource.managers_with_minio
  s3_user = new_resource.access_key_id
  s3_password = new_resource.secret_key_id
  s3_malware_user = new_resource.malware_access_key_id
  s3_malware_password = new_resource.malware_secret_key_id
  s3_malware_endpoint = new_resource.s3_malware_endpoint

  directory '/root/.mcli' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  directory '/root/.mcli/share' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  file '/root/.mcli/share/downloads.json' do
    action :touch
    not_if { ::File.exist?('/root/.mcli/share/downloads.json') }
  end

  file '/root/.mcli/share/uploads.json' do
    action :touch
    not_if { ::File.exist?('/root/.mcli/share/uploads.json') }
  end

  template '/root/.mcli/config.json' do
    source 'mcli_config.json.erb'
    cookbook 'minio'
    variables(s3_user: s3_user,
              s3_password: s3_password,
              managers_with_minio: managers_with_minio,
              s3_malware_user: s3_malware_user,
              s3_malware_password: s3_malware_password,
              s3_malware_endpoint: s3_malware_endpoint)
  end
end

action :remove do
  begin
    ruby_block 'check_minio_replication' do
      block do
        if replication_started? && mcli?(node['name'])
          if member_of_replication_cluster?(node['name'])
            remove_from_minio_replication(node['name'])
            remove_data_from_disk
            Chef::Log.info("removed node from Minio replication : #{node['name']}")
          end
        else
          Chef::Log.info('no Minio replication started')
        end
      end
      action :run
      only_if { s3_running? }
    end

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
