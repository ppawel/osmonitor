#!/bin/sh

osm2pgsql -d osmdb -U postgres -j -G -l -v $1
