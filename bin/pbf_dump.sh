#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

. $AUTH_FILE

JAVACMD_OPTIONS="-Djava.io.tmpdir=/var/tmp -server"
export JAVACMD_OPTIONS

cd $ROOT_DIR/data
osmosis -v 3 --read-pbf $1.osm.pbf --lp --write-pgsql-dump
