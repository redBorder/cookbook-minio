actions :add, :remove, :register, :deregister, :add_s3_conf_nginx
default_action :add

attribute :user, kind_of: String, default: 'minio'
attribute :group, kind_of: String, default: 'minio'
attribute :port, kind_of: Integer, default: 9000
attribute :access_key_id, kind_of: String, default: 'redborder'
attribute :secret_key_id, kind_of: String, default: 'redborder'
attribute :s3_bucket, kind_of: String, default: 'bucket'
attribute :s3_endpoint, kind_of: String, default: 's3.service'
attribute :ipaddress, kind_of: String, default: '127.0.0.1'
attribute :s3_hosts, kind_of: Array, default: ['localhost:9000']
attribute :managers_with_minio, kind_of: Array, default: ['localhost']