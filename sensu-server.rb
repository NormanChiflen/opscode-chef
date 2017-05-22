include_recipe "s3curl"

secret = Chef::EncryptedDataBagItem.load_secret('/root/secret')
credentials = Chef::EncryptedDataBagItem.load("#{node.chef_environment}", "credentials", secret)
s3name=credentials['s3reader_name']

depot = Chef::DataBagItem.load("global", "depot")
depot_path=depot['sensu']['depotpath']
sensu_rpm_name=depot['sensu']['rpm']
sensu_plugin_name=depot['sensu']['gem']
json_gem_name=depot['sensu']['jsongem']
mail_gem_name=depot['sensu']['mailgem']
hipchat_gem_name=depot['sensu']['hipchatgem']
mixlib_cli_gem_name=depot['sensu']['mixlibcligem']
redis_rpm_name=depot['sensu']['redisrpm']

config = Chef::DataBagItem.load("#{node.chef_environment}", "sensu")

# download sensu rpm
execute "download_sensu_from_s3" do
  user "root"
  Chef::Log.info "downloading #{sensu_rpm_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{sensu_rpm_name} > #{Chef::Config[:file_cache_path]}/#{sensu_rpm_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{sensu_rpm_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{sensu_rpm_name}"
end

# download redis rpm
execute "download_redis_from_s3" do
  user "root"
  Chef::Log.info "downloading #{redis_rpm_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{redis_rpm_name} > #{Chef::Config[:file_cache_path]}/#{redis_rpm_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{redis_rpm_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{redis_rpm_name}"
end

# download json gem
execute "download_json_gem_from_s3" do
  user "root"
  Chef::Log.info "downloading #{json_gem_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{json_gem_name} > #{Chef::Config[:file_cache_path]}/#{json_gem_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{json_gem_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{json_gem_name}"
end

# download mixlib-cli gem
execute "download_mixlib_cli_gem_from_s3" do
  user "root"
  Chef::Log.info "downloading #{mixlib_cli_gem_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{mixlib_cli_gem_name} > #{Chef::Config[:file_cache_path]}/#{mixlib_cli_gem_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{mixlib_cli_gem_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{mixlib_cli_gem_name}"
end

# download sensu-plugin gem
execute "download_sensu-plugin_from_s3" do
  user "root"
  Chef::Log.info "downloading #{sensu_plugin_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{sensu_plugin_name} > #{Chef::Config[:file_cache_path]}/#{sensu_plugin_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{sensu_plugin_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{sensu_plugin_name}"
end

# download mail gem
execute "download_mail_gem_from_s3" do
  user "root"
  Chef::Log.info "downloading #{mail_gem_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{mail_gem_name} > #{Chef::Config[:file_cache_path]}/#{mail_gem_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{mail_gem_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{mail_gem_name}"
end

# download hipchat gem
execute "download_hipchat_gem_from_s3" do
  user "root"
  Chef::Log.info "downloading #{hipchat_gem_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{hipchat_gem_name} > #{Chef::Config[:file_cache_path]}/#{hipchat_gem_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{hipchat_gem_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{hipchat_gem_name}"
end


package "redis" do
    source "#{Chef::Config[:file_cache_path]}/#{redis_rpm_name}"
    provider Chef::Provider::Package::Rpm
    action :install
    notifies :run, "execute[enable_at_boot_redis]", :immediately
    notifies :start, "service[redis]", :immediately
end

package "ruby-devel" do
  action :install
end

package "ruby-ri" do
  action :install
end

package "ruby-rdoc" do
  action :install
end

package "ruby-shadow" do
  action :install
end

package "rubygems" do
  action :install
end


# install addition dependent gems
gem_package "json" do
    source "#{Chef::Config[:file_cache_path]}/#{json_gem_name}"
    provider Chef::Provider::Package::Rubygems
    action :install
end

gem_package "mixlib-cli" do
    source "#{Chef::Config[:file_cache_path]}/#{mixlib_cli_gem_name}"
    provider Chef::Provider::Package::Rubygems
    action :install
end

gem_package "sensu-plugin" do
    source "#{Chef::Config[:file_cache_path]}/#{sensu_plugin_name}"
    provider Chef::Provider::Package::Rubygems
    action :install
end

gem_package "mail" do
    source "#{Chef::Config[:file_cache_path]}/#{mail_gem_name}"
    provider Chef::Provider::Package::Rubygems
    action :install
end

gem_package "hipchat" do
    source "#{Chef::Config[:file_cache_path]}/#{hipchat_gem_name}"
    provider Chef::Provider::Package::Rubygems
    action :install
end



Chef::Log.info "installing #{sensu_rpm_name}"
#install sensu package
package "sensu-client" do
    source "#{Chef::Config[:file_cache_path]}/#{sensu_rpm_name}"
    provider Chef::Provider::Package::Rpm
	action :install
	notifies :run, "execute[enable_at_boot_server]", :immediately
    notifies :run, "execute[enable_at_boot_api]", :immediately
    notifies :run, "execute[enable_at_boot_dashboard]", :immediately
    notifies :run, "execute[enable_at_boot_client]", :immediately
end

execute "enable_at_boot_redis" do
    user "root"
    command "/sbin/chkconfig redis on"
    action :nothing
end


execute "enable_at_boot_server" do
    user "root"
    command "/sbin/chkconfig sensu-server on"
    action :nothing
end

execute "enable_at_boot_api" do
    user "root"
    command "/sbin/chkconfig sensu-api on"
    action :nothing
end

execute "enable_at_boot_dashboard" do
    user "root"
    command "/sbin/chkconfig sensu-dashboard on"
    action :nothing
end

execute "enable_at_boot_client" do
    user "root"
    command "/sbin/chkconfig sensu-client on"
    action :nothing
end

directory "/etc/sensu/ssl" do
  owner "sensu"
  action :create
end

cookbook_file "/etc/init.d/sensu-server" do
  source "sensu-server"
  mode 755
  owner "root"
  group "root"
  notifies :start, "service[sensu-server]", :delayed
end

cookbook_file "/etc/init.d/sensu-api" do
  source "sensu-api"
  mode 755
  owner "root"
  group "root"
  notifies :start, "service[sensu-api]", :delayed
end

cookbook_file "/etc/init.d/sensu-dashboard" do
  source "sensu-dashboard"
  mode 755
  owner "root"
  group "root"
  notifies :start, "service[sensu-dashboard]", :delayed
end

cookbook_file "/etc/init.d/sensu-client" do
  source "sensu-client"
  mode 755
  owner "root"
  group "root"
  notifies :start, "service[sensu-client]", :delayed
end

template "/etc/sensu/ssl/client_cert.pem" do
  source "template.pem.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:cert => config['client']['cert'])
  notifies :restart, "service[sensu-client]", :delayed
end

template "/etc/sensu/ssl/client_key.pem" do
  source "template.pem.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:cert => config['client']['key'])
  notifies :restart, "service[sensu-client]", :delayed
end


template "/etc/rabbitmq/ssl/server_key.pem" do
  source "template.pem.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:cert => config['rabbitmq']['key'])
end

template "/etc/rabbitmq/ssl/server_cert.pem" do
  source "template.pem.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:cert => config['rabbitmq']['cert'])
end

template "/etc/rabbitmq/ssl/cacertcat.pem" do
  source "template.pem.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:cert => config['rabbitmq']['cacert'])
end


# create the client.json file
template "/etc/sensu/conf.d/client.json" do
  source "client.json.erb"
  owner "sensu"
  group "sensu"
  mode "0644"
  variables(:role => node[:roles][0],
	:hostname => node[:hostname],
	:ipaddress => node[:ipaddress])
  notifies :restart, "service[sensu-client]", :delayed
end

# create the redis.conf file
template "/etc/redis.conf" do
  source "redis.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
	:ipaddress => node[:ipaddress])
  notifies :restart, "service[redis]", :immediately
end


# create the config.json file
template "/etc/sensu/config.json" do
   source "config.json.erb"
   mode "644"
   variables(
        :rabbitmq_port => node[:sensu][:rabbitmq_port],
        :rabbitmq_host => node[:ipaddress],
        :rabbitmq_user => node[:sensu][:rabbitmq_user],
        :rabbitmq_pass => node[:sensu][:rabbitmq_pass],
        :rabbitmq_vhost => node[:sensu][:rabbitmq_vhost],
        :redis_host => node[:ipaddress],
        :redis_port => node[:sensu][:redis_port],
        :sensu_host => node[:ipaddress],
        :sensu_api_port => node[:sensu][:sensu_api_port],
        :sensu_dashboard_port => node[:sensu][:sensu_dashboard_port],
        :sensu_dashboard_user => node[:sensu][:sensu_dashboard_user],
        :sensu_dashboard_pass => node[:sensu][:sensu_dashboard_pass]       
        )
   notifies :restart, "service[sensu-client]", :delayed
end

service "sensu-server" do
      supports :restart => true, :status => true, :start => true
      action [:enable]
end

service "sensu-api" do
      supports :restart => true, :status => true, :start => true
      action [:enable]
end

service "sensu-dashboard" do
      supports :restart => true, :status => true, :start => true
      action [:enable]
end

service "sensu-client" do
      supports :restart => true, :status => true, :start => true
      action [:enable]
end

service "redis" do
      supports :restart => true, :status => true, :start => true
      action [:enable]
end

