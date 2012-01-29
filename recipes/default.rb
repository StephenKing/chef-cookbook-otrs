#
# Cookbook Name:: otrs
# Recipe:: default
#
# Copyright 2012, Steffen Gebert / TYPO3 Association
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


############################
# System configuration

# create a unix user account for OTRS
user "otrs" do
  comment "OTRS user"
  home "#{node.otrs.prefix}/otrs"
  shell "/bin/bash"
  group node['apache']['group']
  system true
end

# Generate random system_id
node.set_unless['otrs']['kernel_config']['system_id'] = rand(9999)

############################
# Perl setup

include_recipe "perl"

# Required Perl modules
cpan_modules = [
  "Compress::Zlib",
  "DBI",
  "DBD::mysql",
  "Digest:MD5",
  "Crypt::PasswdMD5",
  "CSS:Minifier",
  "GD",
  "GD::Text",
  "GD::Text:Align",
  "GD::Graph",
  "GD::Graph::lines",
  "IO::Socket::SSL",
  "JavaScript:Minifier",
  "JSON::XS",
  "LWP::UserAgent",
  "Mail::IMAPClient",
  "MIME::Base64",
  "Net::DNS",
  "Net::IMAP::Simple::SSL",
  "Net::LDAP",
  "Net::SMTP::TLS::ButMaintained",
  "PDF::API2",
  "Text::CSV_XS",
  "XML::Parser"
]

cpan_modules.each do |cpan_module|
  cpan_module #{cpan_module}
end


############################
# Download & extract OTRS

# Download OTRS source code
remote_file "#{node.otrs.prefix}/otrs-#{node.otrs.version}.tar.gz" do
  source "http://ftp.otrs.org/pub/otrs/otrs-#{node.otrs.version}.tar.gz"
  mode "0644"
  action :create_if_missing
  notifies :run, "script[extract]", :immediately
end

# Extract downloaded file
script "extract" do
  interpreter "bash"
  user "root"
  cwd node['otrs']['prefix']
  action :nothing
  code <<-EOH
  tar xfz #{node.otrs.prefix}/otrs-#{node.otrs.version}.tar.gz
  EOH
end

# Create symlink from otrs/ to otrs-a.b.c./
link "#{node.otrs.prefix}/otrs" do
  to "#{node.otrs.prefix}/otrs-#{node.otrs.version}"
end

############################
# MySql setup

# Install MySQL server

include_recipe "mysql::server"
include_recipe "mysql::client"
include_recipe "database"

# generate the password
::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
node.set_unless['otrs']['database']['password'] = secure_password

mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}


begin
  gem_package "mysql" do
    action :install
  end
  Gem.clear_paths  
  require 'mysql'
  m=Mysql.new("localhost","root",node['mysql']['server_root_password']) 

  if m.list_dbs.include?("otrs") == false
    # create otrs database
    mysql_database 'otrs' do
      connection mysql_connection_info
      action :create
      notifies :run, "execute[otrs_schema]", :immediately
      notifies :run, "execute[otrs_initial_insert]", :immediately
      notifies :run, "execute[otrs_schema-post]", :immediately
    end

    # create otrs user
    mysql_database_user 'otrs' do
      connection mysql_connection_info
      password node['otrs']['database']['password']
      action :create
    end

    # Grant otrs
    mysql_database_user 'otrs' do
      connection mysql_connection_info
      password node['otrs']['database']['password']
      database_name 'otrs'
      host 'localhost'
      privileges [:select,:update,:insert,:create,:alter,:drop,:delete]
      action :grant
    end
    
    execute "otrs_schema" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < #{node.otrs.prefix}/otrs/scripts/database/otrs-schema.mysql.sql"
      action :nothing
    end
    
    execute "otrs_initial_insert" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < #{node.otrs.prefix}/otrs/scripts/database/otrs-initial_insert.mysql.sql"
      action :nothing
    end
    
    execute "otrs_schema-post" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < #{node.otrs.prefix}/otrs/scripts/database/otrs-schema-post.mysql.sql"
      action :nothing
    end
  end
rescue LoadError
  Chef::Log.info("Missing gem 'mysql'")
end

##########################
# Configuration files

# install OTRS configuration file
template "#{node.otrs.prefix}/otrs/Kernel/Config.pm" do
  source "Config.pm.erb"
  owner "otrs"
  group "root"
  mode "644"
  notifies :run, "execute[SetPermissions]"
  notifies :run, "execute[RebuildConfig]"
  notifies :run, "execute[DeleteCache]"
end

template "#{node.otrs.prefix}/otrs/Kernel/Config/GenericAgent.pm" do
  source "GenericAgent.pm.erb"
  owner "otrs"
  group "root"
  mode "644"
  notifies :run, "execute[SetPermissions]"
  notifies :run, "execute[RebuildConfig]"
  notifies :run, "execute[DeleteCache]"
end

template "#{node.otrs.prefix}/otrs/Kernel/Config/Files/ZZZAuto.pm" do
  source "SysConfig.pm"
  owner node['apache']['user']
  group node['apache']['group']
  mode "664"
  notifies :run, "execute[SetPermissions]"
  notifies :run, "execute[RebuildConfig]"
  notifies :run, "execute[DeleteCache]"
end

############################
# OTRS house keeping

# Set file system permissions
execute "SetPermissions" do
  command "bin/otrs.SetPermissions.pl #{node.otrs.prefix}/otrs-#{node.otrs.version} --otrs-user=otrs --otrs-group=#{node.apache.group} --web-user=#{node.apache.user} --web-group=#{node.apache.group}"
  cwd "#{node.otrs.prefix}/otrs"
  user "root"
  action :nothing
end

execute "RebuildConfig" do
  command "bin/otrs.RebuildConfig.pl"
  cwd "#{node.otrs.prefix}/otrs"
  user "otrs"
  action :nothing
end

execute "DeleteCache" do
  command "bin/otrs.DeleteCache.pl"
  cwd "#{node.otrs.prefix}/otrs"
  user "otrs"
  action :nothing
end

##########################
# Apache setup

# set up mod_perl2
cpan_module "Apache::DBI"
package "libapache2-mod-perl2"

template "#{node.otrs.prefix}/otrs/scripts/apache2-perl-startup.pl" do
  source "apache2-perl-startup.pl.erb"
  owner "root"
  mode "655"
end

# create vhost
web_app node['otrs']['fqdn'] do
  server_name node['otrs']['fqdn']
  server_aliases ["www.#{node.otrs.fqdn}"]
  docroot "#{node.otrs.prefix}/otrs-#{node.otrs.version}"
end

# Disable Apache default site
apache_site "000-default" do
  enable false
end

#########################
# Cron jobs

cron "DeleteCache" do
  hour "0"
  minute "20"
  command "#{node.otrs.prefix}/otrs/bin/otrs.DeleteCache.pl --expired >> /dev/null"
  user "otrs"
end

cron "LoaderCache" do
  hour "0"
  minute "30"
  command "#{node.otrs.prefix}/otrs/bin/otrs.LoaderCache.pl -o delete >> /dev/null"
  user "otrs"
end

#cron "fetchmail" do
#  minute "*/5"
#  command "[ -x /usr/bin/fetchmail ] && /usr/bin/fetchmail -a >> /dev/null"
#  user "otrs"
#end

#cron "fetchmail_ssl" do
#  minute "*/5"
#  command "[ -x /usr/bin/fetchmail ] && /usr/bin/fetchmail -a --ssl >> /dev/null"
#  user "otrs"
#end

cron "GenericAgent_db" do
  minute "*/10"
  command "#{node.otrs.prefix}/otrs/bin/otrs.GenericAgent.pl -c db >> /dev/null"
  user "otrs"
end

cron "GenericAgent" do
  minute "*/20"
  command "#{node.otrs.prefix}/otrs/bin/otrs.GenericAgent.pl >> /dev/null"
  user "otrs"
end

cron "PendingJobs" do
  hour "*/2"
  minute "45"
  command "#{node.otrs.prefix}/otrs/bin/otrs.PendingJobs.pl >> /dev/null"
  user "otrs"
end

cron "cleanup" do
  hour "0"
  minute "10"
  command "#{node.otrs.prefix}/otrs/bin/otrs.cleanup >> /dev/null"
  user "otrs"
end

cron "PostMasterMailbox" do
  minute "*/5"
  command "#{node.otrs.prefix}/otrs/bin/otrs.PostMasterMailbox.pl >> /dev/null"
  user "otrs"
end

cron "RebuildTicketIndex" do
  hour "1"
  minute "1"
  command "#{node.otrs.prefix}/otrs/bin/otrs.RebuildTicketIndex.pl >> /dev/null"
  user "otrs"
end

cron "DeleteSessionIDs" do
  hour "0"
  minute ""
  command "#{node.otrs.prefix}/otrs/bin/otrs.DeleteSessionIDs.pl --expired >> /dev/null"
  user "otrs"
end

cron "UnlockTickets" do
  minute "35"
  command "#{node.otrs.prefix}/otrs/bin/otrs.UnlockTickets.pl --timeout >> /dev/null"
  user "otrs"
end