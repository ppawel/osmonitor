ROOT_DIR=`dirname $0`/..

cd $ROOT_DIR/data/replication
osmosis -v 3 --rri workingDirectory=. --wxc diff.osc.gz
