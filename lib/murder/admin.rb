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

namespace :murder do
  desc <<-DESC
  SCPs a compressed version of all files from ./dist (the python Bittorrent library and custom scripts) to all server. The entire directory is sent, regardless of the role of each individual server. The path on the server is specified by remote_murder_path and will be cleared prior to transferring files over.
  DESC
  task :distribute_files, :roles => [:tracker, :seeder, :peer] do
    dist_path = File.expand_path('../../../dist', __FILE__)

    run "mkdir -p #{remote_murder_path}/"
    run "[ $(find '#{remote_murder_path}/'* | wc -l ) -lt 1000 ] && rm -rf '#{remote_murder_path}/'* || ( echo 'Cowardly refusing to remove files! Check the remote_murder_path.' ; exit 1 )"

    # TODO: Skip hidden (.*) files
    tmp = ENV['temp_path'] || default_temp_path

    system "tar -c -z -C #{dist_path} -f #{tmp}/murder_dist_to_upload.tgz ."
    upload("#{tmp}/murder_dist_to_upload.tgz", "#{tmp}/murder_dist.tgz", :via => :sftp)
    run "tar xf #{tmp}/murder_dist.tgz -C #{remote_murder_path}"
    run "rm #{tmp}/murder_dist.tgz"
    system "rm #{tmp}/murder_dist_to_upload.tgz"
  end

  desc "Starts the Bittorrent tracker (essentially a mini-web-server) listening on port 8998."
  task :start_tracker, :roles => :tracker do
    run("SCREENRC=/dev/null SYSSCREENRC=/dev/null screen -dms murder_tracker python #{remote_murder_path}/murder_tracker.py && sleep 0.2", :pty => true)
  end

  desc "If the Bittorrent tracker is running, this will kill the process. Note that if it is not running you will receive an error."
  task :stop_tracker, :roles => :tracker do
    run("pkill -f 'SCREEN.*murder_tracker.py'")
  end

  desc "Identical to stop_seeding, except this will kill all seeding processes. No 'tag' argument is needed."
  task :stop_all_seeding, :roles => :seeder do
    run("pkill -f \"SCREEN.*seeder-\"")
  end

  desc 'Sometimes peers can go on forever (usually because of an error). This command will forcibly kill all "murder_client.py peer" commands that are running.'
  task :stop_all_peering, :roles => :peer do
    run("pkill -f \"murder_client.py peer\"")
  end
end
