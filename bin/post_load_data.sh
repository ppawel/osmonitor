#!/bin/sh

ROOT_DIR=`dirname $0`/..
AUTH_FILE=$ROOT_DIR/authFile

. $AUTH_FILE

cd $ROOT_DIR/sql
psql -1 -f osmonitor_post_load_data.sql -U $user $database
