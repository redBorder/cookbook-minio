module Minio
  module Helpers
    def self.check_remote_port(host, port)
      `nc -zv #{host} #{port} 2>&1`

      process_status = $?

      process_status.exitstatus == 0
    end

    def self.generate_random_key(len)
      chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
      key = ''
      len.times { key << chars[rand(chars.size)] }
      key
    end

    def self.check_remote_hosts(hosts)
      all_alive = true
      hosts.each do |host|
        host, port = host.split(':')
        all_alive = false unless Minio::Helpers.check_remote_port(host, port)
      end
      all_alive
    end

    def self.s3_ready?
      command_output = `serf members list`
    
      nodes = command_output.split("\n")
      leader_node = nodes.find { |node| node.include?('leader=ready') }
    
      if leader_node
        s3_tag = leader_node[/s3=([a-zA-Z0-9_-]+)/, 1]
        return s3_tag == 'ready'
      else
        return false
      end
    end
  end
end
