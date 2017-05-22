include_recipe "s3curl"
include_recipe "apache2"
include_recipe "python"


secret = Chef::EncryptedDataBagItem.load_secret('/root/secret')
credentials = Chef::EncryptedDataBagItem.load("#{node.chef_environment}", "credentials", secret)
s3name=credentials['s3reader_name']

depot = Chef::DataBagItem.load("global", "depot")
depot_path=depot['sensu']['depotpath']
nodejs_rpm_name=depot['sensu']['nodejsrpm']
statsd_tar_name=depot['sensu']['statsdtar']


# download sensu rpm
execute "download_nodejs_from_s3" do
  user "root"
  Chef::Log.info "downloading #{nodejs_rpm_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{nodejs_rpm_name} > #{Chef::Config[:file_cache_path]}/#{nodejs_rpm_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{nodejs_rpm_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{nodejs_rpm_name}"
end

execute "download_statsd_from_s3" do
  user "root"
  Chef::Log.info "downloading #{statsd_tar_name}"
  command "s3curl.pl --id=#{s3name} -- #{depot_path}#{statsd_tar_name} > #{Chef::Config[:file_cache_path]}/#{statsd_tar_name}"
  not_if {File.exists? "#{Chef::Config[:file_cache_path]}/#{statsd_tar_name}"}
  creates "#{Chef::Config[:file_cache_path]}/#{statsd_tar_name}"
end


execute "install_dev_tools" do
    user "root"
    command "yum groupinstall \"Development Tools\" -y"
end

package "python-devel" do
  options "--enablerepo=epel"
  arch "noarch"
end

package "pycairo" do
  options "--enablerepo=epel"
  arch "x86_64"
end

package "Django" do
  options "--enablerepo=epel"
  arch "noarch"
end

package "django-tagging" do
  options "--enablerepo=epel"
  arch "noarch"
end

package "python-twisted" do
  options "--enablerepo=epel"
  arch "noarch"
end

package "python-zope-interface" do
  options "--enablerepo=epel"
  arch "x86_64"
end


package "fontconfig" do
  options "--enablerepo=epel"
  arch "x86_64"
end

package "fontconfig-devel" do
  options "--enablerepo=epel"
  arch "x86_64"
end

package "mod_wsgi" do
  options "--enablerepo=epel"
  arch "x86_64"
end


package "nodejs" do
    source "#{Chef::Config[:file_cache_path]}/#{nodejs_rpm_name}"
    provider Chef::Provider::Package::Rpm
    action :install
    notifies :run, "execute[statsd_install]", :immediately
end


bash "untar_statsd" do
  code <<-EOF
    cd /opt
    sudo tar xvf #{Chef::Config[:file_cache_path]}/#{statsd_tar_name}
  EOF
end


cookbook_file "/etc/init.d/statsd" do
  source "statsd"
  mode 0755
  owner "root"
  group "root"
  notifies :run, "execute[add_statsd_init]", :immediately
  notifies :run, "execute[enable_at_boot_statsd]", :immediately
end

execute "add_statsd_init" do
  user "root"
  command "chkconfig --add statsd"
  action :nothing
end

execute "enable_at_boot_statsd" do
    user "root"
    command "/sbin/chkconfig statsd on"
    action :nothing
end

cookbook_file "/opt/statsd/local.js" do
  source "local.js"
  mode 0755
  owner "root"
  group "root"
end


python_pip "carbon" do
  action :install
  version "0.9.10"
end

execute "enable_at_boot_carbon" do
    user "root"
    command "/sbin/chkconfig carbon on"
end

python_pip "whisper" do
  action :install
  version "0.9.10"
  notifies :run, "execute[create_db]", :immediately
  notifies :run, "execute[change_owner]", :immediately
  notifies :run, "execute[create_superuser]", :immediately
end

execute "create_db" do
    user "root"
    command "python /opt/graphite/webapp/graphite/manage.py syncdb --noinput"
    action :nothing
end

execute "change_owner" do
    user "root"
    command "chown -R apache:apache /opt/graphite/storage/"
    action :nothing
end

execute "create_superuser" do
    user "root"
    command "python /opt/graphite/webapp/graphite/manage.py createsuperuser --username=stats --email=stats@expedia.com --noinput"
    action :nothing
end


python_pip "graphite-web" do
  action :install
  version "0.9.10"
end


cookbook_file "/opt/graphite/conf/carbon.conf" do
  source "carbon.conf"
end

cookbook_file "/opt/graphite/conf/storage-schemas.conf" do
  source "storage-schemas.conf"
end

cookbook_file "/opt/graphite/conf/graphite.wsgi" do
  source "graphite.wsgi"
end

cookbook_file "/opt/graphite/webapp/graphite/local_settings.py" do
  source "local_settings.py"
end

cookbook_file "/etc/httpd/conf.d/graphite.conf" do
  source "graphite.conf"
end

cookbook_file "/etc/init.d/carbon" do
  source "carbon"
  mode 00755
  owner "root"
  group "root"
end



service "carbon" do
  action [:start]
end


service "statsd" do
    action [:start]
end

service "httpd" do
    action [:start]
end