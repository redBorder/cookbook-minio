module Minio
    module Helpers
      def self.check_remote_port(host, port)
        nc_out = `nc -zv #{host} #{port} 2>&1`
      
        process_status = $?
      
        if process_status.exitstatus == 0
          return true
        else
          return false
        end
      end
  
      def self.check_remote_hosts(hosts)
        all_alive = true
        hosts.each do | host |
          host, port = host.split(":")
          all_alive = false if !Minio::Helpers.check_remote_port(host, port)
        end
  
        all_alive
      end
    end
  end
  