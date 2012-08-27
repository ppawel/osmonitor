#!/bin/bash

cd /home/ppawel/osmonitor/src

ruby run_road_report.rb "OSMonitor/Poland_Major_Roads" &> ~/log/report_poland_major_roads.log &
ruby run_road_report.rb "OSMonitor/Poland_Regional_Roads" &> ~/log/report_poland_regional_roads.log &
