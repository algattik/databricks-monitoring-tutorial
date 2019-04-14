#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Databricks cluster to be created
cluster_name="sparkmon$BUILD_BUILDID"

# Copy resources to Databricks
dbfs cp --overwrite spark-monitoring/src/spark-listeners/scripts/listeners.sh dbfs:/databricks/monitoring-staging/listeners.sh
dbfs cp --overwrite spark-monitoring/src/spark-listeners/scripts/metrics.properties dbfs:/databricks/monitoring-staging/metrics.properties
dbfs cp --overwrite spark-monitoring/src/spark-listeners/target/spark-listeners-1.0-SNAPSHOT.jar dbfs:/databricks/monitoring-staging/spark-listeners-1.0-SNAPSHOT.jar
dbfs cp --overwrite spark-monitoring/src/spark-listeners-loganalytics/target/spark-listeners-loganalytics-1.0-SNAPSHOT.jar dbfs:/databricks/monitoring-staging/spark-listeners-loganalytics-1.0-SNAPSHOT.jar
dbfs cp --overwrite configure-log4j-to-logAnalytics.sh dbfs:/databricks/monitoring-staging/configure-log4j-to-logAnalytics.sh

# Create Databricks cluster connected to Log Analytics
cluster_def=$(cat << JSON
{
  "cluster_name": "$cluster_name",
  "spark_version": "5.3.x-scala2.11",
  "node_type_id": "Standard_DS3_v2",
  "spark_conf": {
    "spark.metrics.namespace": "$cluster_name",
    "spark.extraListeners": "com.databricks.backend.daemon.driver.DBCEventLoggingListener,org.apache.spark.listeners.UnifiedSparkListener",
    "spark.unifiedListener.sink": "org.apache.spark.listeners.sink.loganalytics.LogAnalyticsListenerSink",
    "spark.unifiedListener.logBlockUpdates": "false"
  },
  "autoscale": {
    "min_workers": 1,
    "max_workers": 3
  },
  "init_scripts": [
    {
      "dbfs": {
        "destination": "dbfs:/databricks/monitoring-staging/listeners.sh"
      }
    },
    {
      "dbfs": {
        "destination": "dbfs:/databricks/monitoring-staging/configure-log4j-to-logAnalytics.sh"
      }
    }
  ],
  "spark_env_vars": {
    "PYSPARK_PYTHON": "/databricks/python3/bin/python3",
    "LOG_ANALYTICS_WORKSPACE_ID": "$LOG_ANALYTICS_WORKSPACE_ID",
    "LOG_ANALYTICS_WORKSPACE_KEY": "$LOG_ANALYTICS_WORKSPACE_KEY"
  },
  "autotermination_minutes": 120
}
JSON
)
cluster=$(databricks clusters create --json "$cluster_def")

# Copy and run sample notebooks

cluster_id=$(echo $cluster | jq -r .cluster_id)

databricks workspace import_dir sample-jobs/notebooks /Shared/monitoring-tutorial --overwrite

dbfs cp --overwrite sample-jobs/log4j.properties dbfs:/monitoring-tutorial/log4j.properties

for notebook in sample-jobs/notebooks/*.scala; do

  notebook_name=$(basename $notebook .scala)
  notebook_path=/Shared/monitoring-tutorial/$notebook_name
  job_cluster_spec=$(echo "$cluster_def" | jq ".spark_conf.\"spark.metrics.namespace\" = \"$notebook_name\" | del(.autotermination_minutes) | del(.cluster_name)")

  job=$(databricks jobs create --json "$(cat << JSON
  {
    "name": "Sample $notebook_name",
    "new_cluster": $job_cluster_spec,
    "timeout_seconds": 1200,
    "notebook_task": { 
      "notebook_path": "$notebook_path"
    }
  }
JSON
  )")
  job_id=$(echo $job | jq .job_id)

  run=$(databricks jobs run-now --job-id $job_id)

  # Echo job web page URL to task output to facilitate debugging
  run_id=$(echo $run | jq .run_id)
  echo "Running notebook $notebook_path"
  databricks runs get --run-id "$run_id" | jq -r .run_page_url


done

