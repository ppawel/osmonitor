#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

JAVACMD_OPTIONS=-Djava.io.tmpdir=/var/tmp
export JAVACMD_OPTIONS

cd $ROOT_DIR/data
osmosis -v 3 --truncate-pgsql authFile=$AUTH_FILE
