ROOT_DIR=`dirname $0`/..

cd $ROOT_DIR/data
curl -v -R -z $1.osm.pbf http://download.geofabrik.de/osm/europe/$1.osm.pbf -o $1.osm.pbf
