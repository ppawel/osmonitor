#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

. $AUTH_FILE

JAVACMD_OPTIONS=-Djava.io.tmpdir=/var/tmp
export JAVACMD_OPTIONS

osmosis -v 3 --truncate-pgsql authFile=$AUTH_FILE

cd $ROOT_DIR/data
osmosis -v 3 --read-pbf $1.osm.pbf --write-pgsql authFile=$AUTH_FILE

cd $ROOT_DIR/sql
psql -1 -f osmonitor_post_load_data.sql -U $user $database
