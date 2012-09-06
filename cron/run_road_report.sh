#!/bin/bash

# Add Ruby executable to the PATH.
export PATH=/home/ppawel/.rvm/bin:$PATH

# Avoid problems with language specific strings.
export LANG="en_US.utf8"

cd /home/ppawel/osmonitor/src

ruby run_road_report.rb $1 &> $2
