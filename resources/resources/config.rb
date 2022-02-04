actions :add, :remove, :register, :deregister
default_action :add

attribute :user, :kind_of => String, :default => "minio"
attribute :group, :kind_of => String, :default => "minio"
attribute :port, :kind_of => Fixnum, :default => 9000