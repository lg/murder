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

# no default defaults...
set :default_tag, ''
set :default_seeder_files_path, ''
set :default_destination_path, ''

# default remote dist path in app shared directory
set(:remote_murder_path) { "#{shared_path}/murder" }

namespace :murder do
  task :create_torrent, :roles => :seeder do
    require_tag
    if !(seeder_files_path = (default_seeder_files_path if default_seeder_files_path != "") || ENV['files_path'])
      puts "You must specify a 'files_path' parameter with the directory on the seeder which contains the files to distribute"
      exit(1)
    end

    if ENV['path_is_file']
      run "cp \"#{seeder_files_path}\" #{filename}"
    else
      run "tar -c -z -C #{seeder_files_path}/ -f #{filename} --exclude \".git*\" ."
    end

    tracker = find_servers(:roles => :tracker).first
    tracker_host = tracker.host
    tracker_port = variables[:tracker_port] || '8998'

    run "python #{remote_murder_path}/murder_make_torrent.py '#{filename}' #{tracker_host}:#{tracker_port} '#{filename}.torrent'"

    download_torrent unless ENV['do_not_download_torrent']
  end

  task :download_torrent, :roles => :seeder do
    require_tag
    download("#{filename}.torrent", "#{filename}.torrent", :via => :scp)
  end

  task :start_seeding, :roles => :seeder do
    require_tag
    run "screen -dms 'seeder-#{tag}' python #{remote_murder_path}/murder_client.py seeder '#{filename}.torrent' '#{filename}' `host $HOSTNAME | awk '{print $4}'`"
  end

  task :stop_seeding, :roles => :seeder do
    require_tag
    run("pkill -f \"SCREEN.*seeder-#{tag}\"")
  end

  task :peer, :roles => :peer do
    require_tag

    if !(destination_path = (default_destination_path if default_destination_path != "") || ENV['destination_path'])
      puts "You must specify a 'destination_path' parameter with the directory in which to place transferred (and extract) files. Note that inside this directory, a new directory named by the tag will be created. It is inside of this second diectory that the files which the torrent was created from will be placed. To not create this second directory, pass in parameter 'no_tag_directory=1'"
      exit(1)
    end

    if !ENV['no_tag_directory'] && !ENV['path_is_file']
      destination_path += "/#{tag}"
    end

    if !ENV['path_is_file']
      run "mkdir -p #{destination_path}/"
    end

    if ENV['unsafe_please_delete']
      run "rm -rf '#{destination_path}/'*"
    end
    if !ENV['no_tag_directory'] && !ENV['path_is_file']
      run "find '#{destination_path}/'* >/dev/null 2>&1 && echo \"destination_path #{destination_path} on $HOSTNAME is not empty\" && exit 1 || exit 0"
    end

    upload("#{filename}.torrent", "#{filename}.torrent", :via => :scp)
    run "/usr/bin/time -f %e python #{remote_murder_path}/murder_client.py peer '#{filename}.torrent' '#{filename}' `host $CAPISTRANO:HOST$ | awk '{print $4}'`"

    if ENV['path_is_file']
      run "cp #{filename} #{destination_path}"
    else
      run "tar xf #{filename} -C #{destination_path}"
    end
  end

  task :stop_peering, :roles => :peer do
    require_tag
    run("pkill -f \"murder_client.py peer.*#{filename}\"")
  end

  task :clean_temp_files, :roles => [:peer, :seeder] do
    require_tag
    run "rm -f #{filename} #{filename}.torrent || exit 0"
  end

  ###

  def require_tag
    if !(temp_tag = (default_tag if default_tag != "") || ENV['tag'])
      puts "You must specify a 'tag' parameter to identify the transfer"
      exit(1)
    end

    if (temp_tag.include?("/"))
      puts "Tag cannot contain a / character"
      exit(1)
    end

    set :tag, temp_tag
    set :filename, "/tmp/#{tag}.tgz"
  end
end
