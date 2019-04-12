#!/bin/bash

for node_type in driver executor; do

conf_file="/home/ubuntu/databricks/spark/dbconf/log4j/$node_type/log4j.properties"

if grep -q "logAnalyticsAppender" $conf_file; then continue; fi

echo "BEGIN: Updating $node_type log4j properties file"

sed -i 's/log4j.rootCategory=.*/&, logAnalyticsAppender/g' $conf_file

cat << EOF >> $conf_file
# logAnalyticsAppender configuration
log4j.appender.logAnalyticsAppender=com.microsoft.pnp.logging.loganalytics.LogAnalyticsAppender
log4j.appender.logAnalyticsAppender.layout=com.microsoft.pnp.logging.JSONLayout
log4j.appender.logAnalyticsAppender.layout.LocationInfo=false
EOF

echo "END: Updating $node_type log4j properties"

done
