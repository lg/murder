Murder by Larry Gadea <lg@twitter.com> and Matt Freels <freels@twitter.com>  

Copyright 2010 Twitter Inc.


DESCRIPTION
-----------

Murder is a method of using Bittorrent to distribute files to a large amount
of servers within a production environment. This allows for scaleable and fast
deploys in environments of hundreds to tens of thousands of servers where
centralized distribution systems wouldn't otherwise function. A "Murder" is
normally used to refer to a flock of crows, which in this case applies to a
bunch of servers doing something.

For an intro video, see:
[Twitter - Murder Bittorrent Deploy System](http://vimeo.com/11280885)


QUICK START
-----------

For the impatient, `gem install murder` and add these lines to your Capfile:

    require 'murder'

    set :deploy_via, :murder
    after 'deploy:setup', 'murder:distribute_files'
    before 'murder:start_seeding', 'murder:start_tracker'
    after 'murder:stop_seeding', 'murder:stop_tracker'


HOW IT WORKS
------------

In order to do a Murder transfer, there are several components required to be
set up beforehand -- many the result of BitTorrent nature of the system. Murder
is based on BitTornado.

- A torrent tracker. This tracker, started by running the 'murder_tracker.py'
script, runs a self-contained server on one machine. Although technically this
is still a centralized system (everyone relying on this tracker), the
communication between this server and the rest is minimal and normally
acceptable. To keep things simple tracker-less distribution (DHT) is currently
not supported. The tracker is actually just a mini-httpd that hosts a
/announce path which the Bittorrent clients update their state onto.

- A seeder. This is the server which has the files that you'd like to
deploy onto all other servers. The files are placed into a directory
that a torrent gets created from. Murder will tgz up the directory and
create a .torrent file (a very small file containing basic hash
information about the tgz file). This .torrent file lets the peers
know what they're downloading. The tracker keeps track of which
.torrent files are currently being distributed. Once a Murder transfer
is started, the seeder will be the first server many machines go to to
get pieces. These pieces will then be distributed in a tree-fashion to
the rest of the network, but without necessarily getting the parts
from the seeder.

- Peers. This is the group of servers (hundreds to tens of thousands) which
will be receiving the files and distributing the pieces amongst themselves.
Once a peer is done downloading the entire tgz file, it will continue seeding
for a while to prevent a hotspot effect on the seeder.


CONFIGURATION AND USAGE
-----------------------

Murder integrates with Capistrano. The most simple way to use it is as
a deploy strategy, by setting `:deploy_via` to `:murder`. By default,
murder makes the same assumptions that cap makes. All servers without
`:no_release => true` will act as peers. Additionally, murder will
automatically use the first peer as both tracker and seeder. you may
redefine the `tracker`, `seeder` and `peer` roles yourself to change
these defaults, for instance, if you want to set up a dedicated
tracker.

All involved servers must have python installed and the related murder
support files (BitTornado, etc.). To upload the support files to the
tracker, seeder, and peers, run:

    cap murder:distribute_files

By default, these will go in `shared/murder` in your apps deploy
directory. Override this by setting the variable
`remote_murder_path`. For convenience, you can add an after hook to
run this on `deploy:setup`:

    after 'deploy:setup', 'murder:distribute_files'

Before deploying, you must start the tracker:

    cap murder:start_tracker

To have this happen automatically during a deploy, add the following hooks:

    before 'murder:start_seeding', 'murder:start_tracker'
    after 'murder:stop_seeding', 'murder:stop_tracker'

At this point you should be able to deploy normally:

    cap deploy


MANUAL USAGE (murder without a deploy strategy)
-----------------------------------------------

Murder can also be used as a general mechanism to distribute files
across a generic set of servers. To do so create a Capfile, require
murder, and manually define roles:

    require 'rubygems'
    require 'murder'

    set :remote_murder_path, '/opt/local/murder' # or some other directory

    role :peer, 'host1', 'host2', 'host3', 'host4', 'host5', host6', host7'
    role :seeder, 'host1'
    role :tracker, 'host1'

To distribute a directory of files, first make sure that murder is set
up on all hosts, then manually run the murder cap tasks:

1. Start the tracker:

        cap murder:start_tracker

2. Create a torrent from a directory of files on the seeder, and start seeding:

        scp -r ./files host1:~/files
        cap murder:create_torrent tag="Deploy1" files_path="~/files"
        cap murder:start_seeding tag="Deploy1"

3. Distribute the torrent to all peers:

        cap murder:peer tag="Deploy1" destination_path="/tmp"

4. Stop the seeder and tracker:

        cap murder:stop_seeding tag="Deploy1"
        cap murder:stop_tracker

When this finishes, all peers will have the files in /tmp/Deploy1


TASK REFERENCE
--------------

`distribute_files`:
  SCPs a compressed version of all files from ./dist (the python Bittorrent
library and custom scripts) to all server. The entire directory is sent,
regardless of the role of each individual server. The path on the server is
specified by remote_murder_path and will be cleared prior to transferring
files over.

`start_tracker`:
  Starts the Bittorrent tracker (essentially a mini-web-server) listening on
port 8998.

`stop_tracker`:
  If the Bittorrent tracker is running, this will kill the process. Note that
if it is not running you will receive an error.

`create_torrent`:
  Compresses the directory specified by the passed-in argument 'files_path'
and creates a .torrent file identified by the 'tag' argument. Be sure to use
the same 'tag' value with any following commands. Any .git directories will be
skipped. Once completed, the .torrent will be downloaded to your local
/tmp/TAG.tgz.torrent.

`download_torrent`:
  Although not necessary to run, if the file from create_torrent was lost, you
can redownload it from the seeder using this task. You must specify a valid
'tag' argument.

`start_seeding`:
  Will cause the seeder machine to connect to the tracker and start seeding.
The ip address returned by the 'host' bash command will be announced to the
tracker. The server will not stop seeding until the stop_seeding task is
called. You must specify a valid 'tag' argument (which identifies the .torrent
in /tmp to use)

`stop_seeding`:
  If the seeder is currently seeding, this will kill the process. Note that if
it is not running, you will receive an error. If a peer was downloading from
this seed, the peer will find another host to receive any remaining data. You
must specify a valid 'tag' argument.

`stop_all_seeding`:
  Identical to stop_seeding, except this will kill all seeding processes. No
'tag' argument is needed.

`peer`:
  Instructs all the peer servers to connect to the tracker and start download
and spreading pieces and files amongst themselves. You must specify a valid
'tag' argument. Once the download is complete on a server, that server will
fork the download process and seed for 30 seconds while returning control to
Capistrano. Cap will then extract the files to the passed in
'destination_path' argument to destination_path/TAG/*. To not create this tag
named directory, pass in the 'no_tag_directory=1' argument. If the directory
is empty, this command will fail. To clean it, pass in the
'unsafe_please_delete=1' argument. The compressed tgz in /tmp is never
removed. When this task completes, all files have been transferred and moved
into the requested directory.

`stop_all_peering`:
  Sometimes peers can go on forever (usually because of an error). This
command will forcibly kill all "murder_client.py peer" commands that are
running.

CONFIG REFERENCE
----------------

Variables
---------

`default_tag`:
  A tag name to use by default such that a tag parameter doesn't need to be
manually entered on every task. Not recommended to be used since files will be
overwritten.

`default_seeder_files_path`:
  A path on the seeder's file system where the files to be distributed are
stored.

`default_destination_path`:
  A path on the peers' file system where the files that were distributed
should be decompressed into.

`remote_murder_path`:
 A path where murder will look for its support files on each host. `cap
murder:distribute_files` will upload murder support files here.


Roles
-----

`tracker`:
  Host on which to run the BitTorrent tracker

`seeder`:
  Host which will be the source of the files to be distributed via BitTorrent

`peers`:
  All hosts to which files should be distributed
