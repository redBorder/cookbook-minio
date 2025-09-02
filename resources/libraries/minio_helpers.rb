module Minio
  module Helpers
    def check_remote_port(host, port)
      `nc -zv #{host} #{port} 2>&1`

      process_status = $?

      process_status.exitstatus == 0
    end

    def generate_random_key(len)
      chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
      key = ''
      len.times { key << chars[rand(chars.size)] }
      key
    end

    def check_remote_hosts(hosts)
      all_alive = true
      hosts.each do |host|
        host, port = host.split(':')
        all_alive = false unless Minio::Helpers.check_remote_port(host, port)
      end
      all_alive
    end

    def exists_minio_conf?
      File.exist?('/etc/default/minio')
    end

    def s3_ready?
      command_output = `serf members list`

      nodes = command_output.split("\n")
      leader_node = nodes.find { |node| node.include?('s3=ready') }

      if leader_node
        true
      else
        false
      end
    end

    def s3_running?
      system('systemctl is-active minio --quiet')
    end

    def mcli?(node_name)
      File.exist?('/usr/local/bin/mcli') && system("/usr/local/bin/mcli alias ls | grep -q ^#{node_name}")
    end

    def replication_started?
      !system("/usr/local/bin/mcli admin replicate info local | grep -i 'SiteReplication is not enabled'")
    end

    def follower?
      !Dir.exist?('/var/minio/data/bucket')
    end

    def member_of_replication_cluster?(node_name)
      system("/usr/local/bin/mcli admin replicate info local | grep #{node_name}")
    end

    def add_to_minio_replication(s3_hosts, node_name)
      s3_nodes = s3_hosts.dup
      s3_nodes.delete(node_name)
      s3_nodes = s3_nodes.join(' ') + ' ' + node_name
      system("/usr/local/bin/mcli admin replicate add #{s3_nodes}")
    end

    def remove_from_minio_replication(node_name)
      system("/usr/local/bin/mcli admin replicate rm #{node_name} #{node_name} --force")
    end

    def remove_data_from_disk
      system('rm -rf /var/minio/data')
    end

    def get_cdomain
      if File.exist?('/etc/redborder/cdomain')
        File.read('/etc/redborder/cdomain').strip
      else
        'redborder.cluster'
      end
    end

    def create_malware_user(s3_malware_user, s3_malware_password)
      user_exists = system("/usr/local/bin/mcli admin user info local #{s3_malware_user} > /dev/null 2>&1")
      return true if user_exists

      system("/usr/local/bin/mcli admin user add local #{s3_malware_user} #{s3_malware_password}")
    end

    def create_malware_policy(s3_malware_user, template_path)
      system("/usr/local/bin/mcli admin policy create local malware-policy #{template_path}")
      system("/usr/local/bin/mcli admin policy attach local malware-policy --user #{s3_malware_user}")
    end
  end
end
