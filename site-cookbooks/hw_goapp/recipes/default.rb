#
# Cookbook Name:: hw_goapp
# Recipe:: default
#
# Copyright 2015, cvlc
#
# MIT Expat License
#
include_recipe "golang::packages"

app_packages = node["go"]["packages"]
runas = node["go"]["owner"]

app_packages.each do |package|
  app_name = package.split('/')[-1]

  template "/etc/init.d/#{app_name}" do
    source "service.rb"
    mode "0755"
    owner "root"
    group "root"
    variables({
      :name => app_name,
      :description => "This runs the Go app #{app_name} as a service",
      :username => runas,
      :command => "#{node["go"]["gobin"]}/#{app_name}"
    }) 
  end

  service "#{app_name}" do
    supports :start => true, :restart => true, :stop => true
    action [:enable, :start]
  end
end
