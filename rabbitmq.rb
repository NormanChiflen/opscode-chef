include_recipe "s3curl"

secret = Chef::EncryptedDataBagItem.load_secret('/root/secret')
credentials = Chef::EncryptedDataBagItem.load("#{node.chef_environment}", "credentials", secret)
s3name=credentials['s3reader_name']

depot = Chef::DataBagItem.load("global", "depot")
depot_path=depot['sensu']['depotpath']
rabbitmq_rpm_name=depot['sensu']['rabbitmqrpm']

config = Chef::DataBagItem.load("#{node.chef_environment}", "sensu")

# download rabbitmq rpm
execute "download_rabbitmq_rpm_from_s3" do
  user "root"
  Chef::Log.info "downloading #{rabbitmq_rpm_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{rabbitmq_rpm_name} > #{Chef::Config[:file_cache_path]}/#{rabbitmq_rpm_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{rabbitmq_rpm_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{rabbitmq_rpm_name}"
end

package "erlang" do
  action :install
end

package "rabbitmq" do
   source "#{Chef::Config[:file_cache_path]}/#{rabbitmq_rpm_name}"
   provider Chef::Provider::Package::Rpm
   action :install
   notifies :run, "execute[enable_rabbitmq_plugins]", :immediately
   notifies :delete, "cookbook_file[rabbitmqinit]", :immediately
   notifies :create, "cookbook_file[rabbitmqinit]", :immediately
   notifies :start, "service[rabbitmq-server]", :immediately
   notifies :run, "execute[enable_at_boot_rabbitmq]", :immediately
   notifies :run, "execute[create_rabbitmq_vhost]", :immediately
   notifies :run, "execute[create_rabbitmq_user]", :immediately
   notifies :run, "execute[grant_rabbitmq_vhost_permissions]", :immediately
   notifies :run, "execute[grant_admin_rabbitmq_vhost_permissions]", :immediately
   notifies :restart, "service[rabbitmq-server]", :delayed
end

directory "/etc/rabbitmq/ssl" do
  owner "root"
  action :create
  recursive true
end

cookbook_file "rabbitmqinit" do
  path "/etc/init.d/rabbitmq-server"    
  source "rabbitmq-server"
  mode 755
  owner "root"
  group "root"
end

execute "enable_at_boot_rabbitmq" do
    user "root"
    command "/sbin/chkconfig rabbitmq-server on"
    action :nothing
end



template "/etc/rabbitmq/ssl/server_key.pem" do
  source "template.pem.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(:cert => config['rabbitmq']['key'])
  notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/ssl/server_cert.pem" do
  source "template.pem.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(:cert => config['rabbitmq']['cert'])
  notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/ssl/cacert.pem" do
  source "template.pem.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(:cert => config['rabbitmq']['cacert'])
  notifies :restart, "service[rabbitmq-server]", :delayed
end

template "/etc/rabbitmq/rabbitmq.config" do
   source "rabbitmq.config.erb"
   owner "root"
   group "root"
   mode "644"
   variables(:rabbitmq_port => node[:sensu][:rabbitmq_port])
   notifies :restart, "service[rabbitmq-server]", :delayed
end

execute "enable_rabbitmq_plugins" do
    user "root"
    command "rabbitmq-plugins enable rabbitmq_management"
    action :nothing
end

execute "create_rabbitmq_vhost" do
    user "root"
    command "rabbitmqctl add_vhost /sensu"
    action :nothing
end

execute "create_rabbitmq_user" do
    user "root"
    command "rabbitmqctl add_user sensu sensu"
    action :nothing
end

execute "grant_rabbitmq_vhost_permissions" do
    user "root"
    command "rabbitmqctl set_permissions -p /sensu sensu \".*\" \".*\" \".*\""
    action :nothing
end

execute "grant_admin_rabbitmq_vhost_permissions" do
    user "root"
    command "rabbitmqctl set_permissions -p /sensu guest \".*\" \".*\" \".*\""
    action :nothing
end


# start the service
service "rabbitmq-server" do
  supports :restart => true, :status => true, :start => true
  action [:enable]
end