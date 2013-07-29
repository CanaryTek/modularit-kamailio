#
# Cookbook Name:: kamailio
# Recipe:: default
#
# Copyright 2013, CanaryTek
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

case node['platform']
when "debian", "ubuntu"
  include_recipe 'apt'
when "centos","redhat"
  include_recipe 'yum'
  include_recipe "yum::epel"
end

# Install build dependencies
packages = node['kamailio']['build_deps'].split
packages.each do |pkg|
  package pkg do
    action :install
  end
end

case node['platform']
when "centos","redhat"
  bash "Workaround for http://tickets.opscode.com/browse/COOK-1210" do 
    code <<-EOH
      echo 0 > /selinux/enforce
    EOH
  end
end

version = node['kamailio']['server']['version']

remote_file "#{Chef::Config[:file_cache_path]}/#{node['kamailio']['server']['download_file']}" do
  source "#{node['kamailio']['server']['download_url']}/#{node['kamailio']['server']['download_file']}"
  action :create_if_missing
end

bash "compile-kamailio" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxvf #{node['kamailio']['server']['download_file']}
    cd kamailio-*
    make prefix=/usr cfg_prefix=/ cfg_target=/etc/kamailio/ modules_dirs="modules" SCTP=1 STUN=1 group_include="standard standard-dep stable mysql postgres radius presence" include_modules="snmpstats" cfg
    make bin_prefix=/usr cfg_prefix=/ cfg_target=/etc/kamailio/ modules_dirs="modules" all 
    make bin_prefix=/usr cfg_prefix=/ cfg_target=/etc/kamailio/ modules_dirs="modules" modules-all 
    make bin_prefix=/usr cfg_prefix=/ cfg_target=/etc/kamailio/ modules_dirs="modules" install
    install -m755 ./pkg/kamailio/centos/6/kamailio.init /etc/init.d/kamailio
    install -m644 ./pkg/kamailio/centos/6/kamailio.sysconfig /etc/sysconfig/kamailio
  EOH
  creates "/usr/sbin/kamailio"
end

#user node['graylog2']['web_user'] do
user "kamailio" do
  home "/var/tmp"
  comment "Kamailio user"
  supports :manage_home => false
  shell "/sbin/nologin"
end

