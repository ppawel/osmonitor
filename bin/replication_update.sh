#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

JAVACMD_OPTIONS=-Djava.io.tmpdir=/var/tmp
export JAVACMD_OPTIONS

osmosis --rri workingDirectory=$ROOT_DIR/data/replication --log-progress-change --simc --buffer-change bufferCapacity=6666 --write-pgsql-change authFile=$AUTH_FILE
