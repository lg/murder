# Copyright 2010 Twitter, Inc.
# Copyright 2010 Larry Gadea <lg@twitter.com>
# Copyright 2010 Matt Freels <freels@twitter.com>
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

Capistrano::Configuration.instance(:must_exist).load do

  load_paths.push File.expand_path('../', __FILE__)

  load 'murder/murder'
  load 'murder/admin'

  # no default defaults...
  set :default_tag, ''
  set :default_seeder_files_path, ''
  set :default_destination_path, ''

  # default remote dist path in app shared directory
  set(:remote_murder_path) { "#{shared_path}/murder" }

  # roles
  excluded_roles = [:peer, :tracker, :seeder]

  # get around the fact that find_servers does not work in role evaluation
  # (it tries to evaluate all roles, leading to infinite recursion)
  role :peer do
    roles.reject{|k,v| excluded_roles.include? k }.values.map{|r| r.send(:servers)}.flatten.uniq.reject{|s| s.options[:no_release] }
  end

  role(:tracker) { roles[:peer].servers.first }
  role(:seeder) { roles[:peer].servers.first }

end
