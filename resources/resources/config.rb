actions :add, :remove, :register, :deregister
default_action :add

attribute :user, :kind_of => String, :default => "minio"
