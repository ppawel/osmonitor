#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

. $AUTH_FILE

cd $ROOT_DIR/sql

psql -f pgsnapshot_schema_0.6.sql -U $user $database
psql -f pgsnapshot_schema_0.6_action.sql -U $user $database
psql -f pgsnapshot_schema_0.6_bbox.sql -U $user $database
psql -f pgsnapshot_schema_0.6_linestring.sql -U $user $database
psql -f osmonitor.sql -U $user $database
