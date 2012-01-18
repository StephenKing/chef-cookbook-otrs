#
# Cookbook Name:: otrs
# Attributes:: default

default[:otrs][:version] = "3.1.0.beta3"

default[:otrs][:fqdn] = "otrs.example.org"

default[:otrs][:kernel_config][:email] = "otrs@otrs.example.org"
default[:otrs][:kernel_config][:organization] = "Example Association"
default[:otrs][:kernel_config][:system_id] = 74

default[:otrs][:database][:host] = "localhost"
default[:otrs][:database][:user] = "otrs"
default[:otrs][:database][:password] = nil
default[:otrs][:database][:name] = "otrs"

default[:otrs][:cron][:mailto] = "admin@example.com"