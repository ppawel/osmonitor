#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

. $AUTH_FILE

cd $ROOT_DIR/sql

psql -1 -c 'SELECT OSM_RefreshChangedRoads()' -U $user $database
