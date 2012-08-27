#!/bin/bash

ruby /home/ppawel/osmonitor/src/run_road_report.rb "OSMonitor/Poland_Major_Roads" &> ~/log/report_poland_major_roads.log &
ruby /home/ppawel/osmonitor/src/run_road_report.rb "OSMonitor/Poland_Regional_Roads" &> ~/log/report_poland_regional_roads.log &
