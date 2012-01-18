#
# Cookbook Name:: otrs
# Recipe:: default
#
# Copyright 2012, Steffen Gebert, TYPO3 Association
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

#case node[:platform]
#when "ubuntu","debian"
  # install some dependencies
#  %w{ perl }.each do |pck|
#    package "#{pck}" do
#      action :install
#    end
#  end
#when "centos"
#  log "No centos Support yet"
#end


# Required Perl modules
cpan_modules = [
  "DBI",
  "DBD::mysql",
  "Digest:MD5",
  "CSS:Minifier",
  "Crypt::PasswdMD5",
  "MIME::Base64",
  "JavaScript:Minifier",
  "Net::DNS",
  "LWP::UserAgent",
  "Net::LDAP",
  "IO::Socket::SSL",
  "Net::IMAP::Simple::SSL",
  "GD",
  "GD::Text",
  "GD::Text:Align",
  "GD::Graph",
  "GD::Graph::lines",
  "JSON::XS",
  "Mail::IMAPClient",
  "PDF::API2",
  "Compress::Zlib",
  "Text::CSV_XS",
  "XML::Parser"
]

cpan_modules.each do |cpan_module|
  cpan_module #{cpan_module}
end

# todo executed CheckModules?

user "otrs" do
  comment "OTRS user"
  home "/usr/local/otrs"
  shell "/bin/bash"
  group "www-data"
  system true
  # TODO same group as web server
end

# installation of OTRS
script "extract" do
  interpreter "bash"
  user "root"
  cwd "/usr/local"
  action :nothing
  #notifies :restart, "service[otrs]"
  code <<-EOH
  tar xvfz /usr/local/otrs-#{node.otrs.version}.tar.gz
  EOH
end

# Download OTRS source code
remote_file "/usr/local/otrs-#{node.otrs.version}.tar.gz" do
  source "http://ftp.otrs.org/pub/otrs/otrs-#{node.otrs.version}.tar.gz"
  mode "0644"
  action :create_if_missing
  notifies :run, "script[extract]", :immediately
end



############################
# MySql setup

# Install MySQL server

include_recipe "mysql::server"
include_recipe "mysql::client"
include_recipe "database"

# generate the password
::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
node.set_unless[:otrs][:database][:password] = secure_password

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
      notifies :create, "template[/usr/local/otrs-#{node.otrs.version}/Kernel/Config.pm]"
      notifies :run, "execute[otrs_schema]"
      notifies :run, "execute[otrs_initial_insert]"
      notifies :run, "execute[otrs_schema-post]"
    end

    # create otrs user
    mysql_database_user 'otrs' do
      connection mysql_connection_info
      password node[:otrs][:database][:password]
      action :create
    end

    # Grant otrs
    mysql_database_user 'otrs' do
      connection mysql_connection_info
      password node[:otrs][:database][:password]
      database_name 'otrs'
      host 'localhost'
      privileges [:select,:update,:insert,:create,:alter,:drop,:delete]
      action :grant
    end
    
    execute "otrs_schema" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < /usr/local/otrs-#{node.otrs.version}/scripts/database/otrs-schema.mysql.sql"
      action :nothing
    end
    
    execute "otrs_initial_insert" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < /usr/local/otrs-#{node.otrs.version}/scripts/database/otrs-initial_insert.mysql.sql"
      action :nothing
    end
    
    execute "otrs_schema-post" do
      command "/usr/bin/mysql -u root #{node.otrs.database.name} -p#{node.mysql.server_root_password} < /usr/local/otrs-#{node.otrs.version}/scripts/database/otrs-schema-post.mysql.sql"
      action :nothing
    end
  end
rescue LoadError
  Chef::Log.info("Missing gem 'mysql'")
end



##########################
# Configuration files
# install OTRS configuration file
template "/usr/local/otrs-#{node.otrs.version}/Kernel/Config.pm" do
  source "Kernel/Config.pm.erb"
  owner "otrs"
  group "root"
  mode "644"
end

template "/usr/local/otrs-#{node.otrs.version}/Kernel/Config/GenericAgent.pm" do
  source "Kernel/Config/GenericAgent.pm.erb"
  owner "otrs"
  group "root"
  mode "644"
end

execute "set_permissions" do
  command "bin/otrs.SetPermissions.pl /usr/local/otrs-#{node.otrs.version} --otrs-user=otrs --otrs-group=www-data --web-user=www-data --web-group=www-data"
  cwd "/usr/local/otrs-#{node.otrs.version}"
  # todo more parameters
  user "root"
  action :nothing
end

##########################
# Apache setup

template "/usr/local/otrs-#{node.otrs.version}/scripts/apache2-perl-startup.pl" do
  source "apache2-perl-startup.pl.erb"
  owner "root"
  mode "655"
end

cpan_module "Apache::DBI"
package "libapache2-mod-perl2"

web_app "#{node.otrs.fqdn}" do
  server_name "#{node.otrs.fqdn}"
  server_aliases ["www.#{node.otrs.fqdn}"]
  docroot "/usr/local/otrs-#{node.otrs.version}"
end


#########################
# Cron jobs

cron "DeleteCache" do
  hour "0"
  minute "20"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.DeleteCache.pl --expired >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "LoaderCache" do
  hour "0"
  minute "30"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.LoaderCache.pl -o delete >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

#cron "fetchmail" do
#  minute "*/5"
#  command "[ -x /usr/bin/fetchmail ] && /usr/bin/fetchmail -a >> /dev/null"
#  user "otrs"
#  mailto "#{node.otrs.cron.mailto}"
#end

#cron "fetchmail_ssl" do
#  minute "*/5"
#  command "[ -x /usr/bin/fetchmail ] && /usr/bin/fetchmail -a --ssl >> /dev/null"
#  user "otrs"
#  mailto "#{node.otrs.cron.mailto}"
#end

cron "GenericAgent_db" do
  minute "*/10"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.GenericAgent.pl -c db >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "GenericAgent" do
  minute "*/20"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.GenericAgent.pl >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "PendingJobs" do
  hour "*/2"
  minute "45"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.PendingJobs.pl >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "cleanup" do
  hour "0"
  minute "10"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.cleanup >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "PostMasterMailbox" do
  minute "*/5"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.PostMasterMailbox.pl >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "RebuildTicketIndex" do
  hour "1"
  minute "1"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.RebuildTicketIndex.pl >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "DeleteSessionIDs" do
  hour "0"
  minute ""
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.DeleteSessionIDs.pl --expired >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end

cron "UnlockTickets" do
  minute "35"
  command "/usr/local/otrs-#{node.otrs.version}/bin/otrs.UnlockTickets.pl --timeout >> /dev/null"
  user "otrs"
  mailto "#{node.otrs.cron.mailto}"
end
