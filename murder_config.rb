# Copyright 2010 Twitter, Inc.
# Copyright 2010 Larry Gadea <lg@twitter.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Capistrano settings -- all optional depending on your env
set :user, "deployuser"
ssh_options[:port] = 22
ssh_options[:host_key] = 'ssh-dss'
ssh_options[:compression] = false
ssh_options[:forward_agent] = true

# General settings
set :remote_murder_path, "/usr/local/murder"

# set any of these empty to require user always specify
set :default_tag, ""
set :default_seeder_files_path, ""
set :default_destination_path, ""

# Servers (roles automatically generated)
# Note that you could generate this list automatically based on a database or
# an input file containing servers
set :host_suffix, ".twitter.com"
set :tracker_host, "murdertracker"
set :tracker_port, "8998"
set :seeder_host, "staging0001"
set :peers, %w(
  web0001 web0002 web0003 web0004 web0005 web0006
) 
