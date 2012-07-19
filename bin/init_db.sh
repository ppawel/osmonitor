#!/bin/sh

ROOT_DIR=`dirname $0`/../../..
AUTH_FILE=$ROOT_DIR/authFile

psql -f pgsnapshot_schema_0.6.sql -U postgres osmdb
psql -f pgsnapshot_schema_0.6_action.sql -U postgres osmdb
psql -f pgsnapshot_schema_0.6_bbox.sql -U postgres osmdb
psql -f pgsnapshot_schema_0.6_linestring.sql -U postgres osmdb
 
