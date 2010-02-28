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

# Load the basic functionality from murder.rb
load "murder"

namespace :murder do
  task :distribute_files, :roles => [:tracker, :seeder, :peer] do
    dist_path = File.expand_path('../../dist', __FILE__)

    run "mkdir -p #{remote_murder_path}/"
    run "[ $(find '#{remote_murder_path}/'* | wc -l ) -lt 1000 ] && rm -rf '#{remote_murder_path}/'* || ( echo 'Cowardly refusing to remove files! Check the remote_murder_path.' ; exit 1 )"

    # TODO: Skip hidden (.*) files
    # TODO: Specifyable tmp file
    system "tar -c -z -C #{dist_path} -f /tmp/murder_dist.tgz ."
    upload("/tmp/murder_dist.tgz", "/tmp/murder_dist.tgz", :via => :sftp)
    run "tar xf /tmp/murder_dist.tgz -C #{remote_murder_path}"
    run "rm /tmp/murder_dist.tgz"
    system "rm /tmp/murder_dist.tgz"
  end

  task :start_tracker, :roles => :tracker do
    run("screen -dms murder_tracker python #{remote_murder_path}/murder_tracker.py", :pty => true)
  end

  task :stop_tracker, :roles => :tracker do
    run("pkill -f 'SCREEN.*murder_tracker.py'")
  end

  task :stop_all_seeding, :roles => :seeder do
    run("pkill -f \"SCREEN.*seeder-\"")
  end

  task :stop_all_peering, :roles => :peer do
    run("pkill -f \"murder_client.py peer\"")
  end
end
