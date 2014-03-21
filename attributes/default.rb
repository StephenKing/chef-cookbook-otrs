#
# Cookbook Name:: otrs
# Attributes:: default

default['otrs']['version'] = "3.3.5"

default['otrs']['fqdn'] = fqdn

default['otrs']['prefix'] = "/opt"

default['otrs']['database']['host'] = "localhost"
default['otrs']['database']['user'] = "otrs"
default['otrs']['database']['password'] = nil
default['otrs']['database']['name'] = "otrs"

default['otrs']['kernel_config']['email'] = "otrs@otrs.example.org"
default['otrs']['kernel_config']['organization'] = "Example Association"
default['otrs']['kernel_config']['system_id'] = nil # must be numeric only!

default['otrs']['server_aliases'] = nil

default['otrs']['logging']['loglevel'] = 'info'
default['otrs']['logging']['to_syslog'] = false

default[:apache][:listen_ports] = [ 80 ]
