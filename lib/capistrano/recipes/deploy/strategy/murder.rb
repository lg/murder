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

require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy
      class Murder < Capistrano::Deploy::Strategy::Copy
        def upload(filename, remote_filename)
          puts "Uploading release to seeder..."
          configuration.upload(filename, remote_filename, :roles => :seeder)

          ENV["tag"] = File.basename(filename)
          ENV["path_is_file"] = "yes"
          ENV["files_path"] = remote_filename
          ENV['destination_path'] = remote_filename

          puts "Creating torrent..."
          murder.create_torrent

          puts "Starting seeding..."
          murder.start_seeding

          puts "Peering..."
          murder.peer

          puts "Done. Killing seeding and all peering..."
          murder.stop_peering
          murder.stop_seeding

          puts "Cleaning temp files..."
          murder.clean_temp_files

          puts "THANK YOU FOR USING MURDER, HAVE A NICE DAY"
        end
      end
    end
  end
end
