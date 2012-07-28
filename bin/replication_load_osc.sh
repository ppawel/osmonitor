#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

JAVACMD_OPTIONS=-Djava.io.tmpdir=/var/tmp
export JAVACMD_OPTIONS

osmosis --read-xml-change $ROOT_DIR/data/replication/diff.osc.gz --write-pgsql-change authFile=$AUTH_FILE
