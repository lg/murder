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

# Usage: python murder_make_torrent.py <file> <trackerhost:port> <target>
# Usage: python murder_make_torrent.py deploy.tar.gz tracker.twitter.com:8998 deploy.torrent

import warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)

from sys import argv, version, exit
from os.path import split
assert version >= '2', "Install Python 2.0 or greater"
from BitTornado.BT1.makemetafile import make_meta_file

if __name__ == '__main__':

  if len(argv) != 4:
    print "Incorrect number of arguments"
    print
    print """Usage:
    python murder_make_torrent.py <file> <trackerhost:port> <target>

    For example:
    python murder_make_torrent.py deploy.tar.gz tracker.twitter.com:8998 deploy.torrent
    """
    exit(1)

  try:
    params = {}
    params["target"] = argv[3]
    make_meta_file(argv[1], "http://" + argv[2] + "/announce", params)
  except ValueError, e:
    print str(e)
    exit(1)
