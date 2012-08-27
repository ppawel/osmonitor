#!/bin/bash

# Add osmosis executable to the PATH.
export PATH=/home/ppawel/osmosis/bin:$PATH

# Makes sure we exit if flock fails.
set -e

(
  # Try to lock on the lock file (fd 200)
  flock -x -n 200

  /home/ppawel/osmonitor/bin/replication_update.sh &>> ~/replication.log

) 200>/var/lock/osmonitor_replication.lock
