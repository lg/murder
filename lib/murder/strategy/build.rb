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

require 'capistrano/recipes/deploy/strategy/copy'
require 'fileutils'
require 'tempfile'

module Capistrano
  module Deploy
    module Strategy
      class Build < Copy
        def deploy!
          if copy_cache
            if File.exists?(copy_cache)
              logger.debug "refreshing local cache to revision #{revision} at #{copy_cache}"
              system(source.sync(revision, copy_cache))
            else
              logger.debug "preparing local cache at #{copy_cache}"
              system(source.checkout(revision, copy_cache))
            end

            logger.debug "copying cache to deployment staging area #{destination}"
            Dir.chdir(copy_cache) do
              FileUtils.mkdir_p(destination)
              queue = Dir.glob("*", File::FNM_DOTMATCH)
              while queue.any?
                item = queue.shift
                name = File.basename(item)

                next if name == "." || name == ".."
                next if copy_exclude.any? { |pattern| File.fnmatch(pattern, item) }

                if File.symlink?(item)
                  FileUtils.ln_s(File.readlink(File.join(copy_cache, item)), File.join(destination, item))
                elsif File.directory?(item)
                  queue += Dir.glob("#{item}/*", File::FNM_DOTMATCH)
                  FileUtils.mkdir(File.join(destination, item))
                else
                  FileUtils.ln(File.join(copy_cache, item), File.join(destination, item))
                end
              end
            end
          else
            logger.debug "getting (via #{copy_strategy}) revision #{revision} to #{destination}"
            system(command)

            if copy_exclude.any?
              logger.debug "processing exclusions..."
              copy_exclude.each { |pattern| FileUtils.rm_rf(Dir.glob(File.join(destination, pattern), File::FNM_DOTMATCH)) }
            end
          end

          raise unless system("cd #{source_folder} && #{build_task}")
          remote_filename = File.join(releases_path, package)

          # MURDER CODE HERE
          if configuration[:murder] == true
            # create torrent on utility002
            puts "Creating torrent..."
            ENV["tag"] = release_name
            ENV["do_not_download_torrent"] = "yes"
            if configuration[:distribution_is_a_file]
              ENV["path_is_file"] = "yes"
              ENV["files_path"] = filename
            else
              ENV["files_path"] = source_folder
            end
            murder.create_torrent

            # start seeding on utility002
            puts "Starting seeding..."
            murder.start_seeding

            # peer everywhere
            puts "Peering..."
            if configuration[:distribution_is_a_file]
              ENV['destination_path'] = remote_filename
            else
              ENV['destination_path'] = releases_path
            end
            murder.peer

            # kill seeder
            puts "Done. Killing seeding and all peering..."
            murder.stop_peering
            murder.stop_seeding

            # delete torrent files on both seeder and peers (/tmp/tag.tgz, /tmp/tag.tgz.torrent)
            puts "Cleaning temp files..."
            murder.clean_temp_files

            puts "THANK YOU FOR USING MURDER, HAVE A NICE DAY"
          end

          if configuration[:murder] == false || (configuration[:murder] == true && configuration[:distribution_is_a_file])
            begin
              upload(filename, remote_filename) if configuration[:murder] == false
              run "cd #{releases_path} && #{decompress(remote_filename).join(" ")}"
            ensure
              run "rm -f #{remote_filename}"
            end
          end

        ensure
          FileUtils.rm filename rescue nil
          FileUtils.rm_rf destination rescue nil
        end

        def build_task
          @build_task ||= configuration[:build_task]
        end

        def copy_compression
          configuration[:copy_compression]
        end

        def dist_path
          configuration[:dist_path]
        end

        def filename
          @filename ||= File.join(tmpdir, File.basename(destination), dist_path, package)
        end

        def package
          configuration[:package_name] || "#{application}-#{revision[0, 8]}.#{copy_compression}"
        end

        def source_folder
          File.join(tmpdir, File.basename(destination))
        end
      end
    end
  end
end
