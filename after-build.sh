#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Databricks cluster to be created
cluster_name="sparkmon$BUILD_BUILDID"

# Log analytics instance created by before-build.sh
read loganalytics_instance < loganalytics_instance.txt

read tenantId subscriptionId <<< $(az account show --query '{tenantId:tenantId,id:id}' -o tsv)

curl="curl --silent --show-error --fail "

# Get an AAD authentication token for ARM
# NB: $servicePrincipalId and $servicePrincipalKey passed as env vars
armToken=$($curl -X POST -v \
	--data-urlencode "grant_type=client_credentials" \
	--data-urlencode "client_id=$servicePrincipalId" \
	--data-urlencode "client_secret=$servicePrincipalKey" \
	--data-urlencode "resource=https://management.azure.com/" \
	"https://login.microsoftonline.com/$tenantId/oauth2/token" \
| jq -r '.token_type + " " + .access_token')

# Get Log Analytics Workspace ID and Key
wsId=$($curl -X GET -H "Authorization: $armToken" -H "Content-Type: application/json" https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$loganalytics_instance?api-version=2015-11-01-preview | jq -r .properties.customerId)
wsKey=$($curl -X POST -d '' -H "Authorization: $armToken" -H "Content-Type: application/json" https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$loganalytics_instance/sharedKeys?api-version=2015-11-01-preview | jq -r .primarySharedKey)

# Copy resources to Databricks
dbfs cp --overwrite spark-monitoring/src/spark-listeners/scripts/listeners.sh dbfs:/databricks/monitoring-staging/listeners.sh
dbfs cp --overwrite spark-monitoring/src/spark-listeners/scripts/metrics.properties dbfs:/databricks/monitoring-staging/metrics.properties
dbfs cp --overwrite spark-monitoring/src/spark-listeners/target/spark-listeners-1.0-SNAPSHOT.jar dbfs:/databricks/monitoring-staging/spark-listeners-1.0-SNAPSHOT.jar
dbfs cp --overwrite spark-monitoring/src/spark-listeners-loganalytics/target/spark-listeners-loganalytics-1.0-SNAPSHOT.jar dbfs:/databricks/monitoring-staging/spark-listeners-loganalytics-1.0-SNAPSHOT.jar

# Create Databricks cluster connected to Log Analytics
cluster=$(databricks clusters create --json "$(cat << JSON
{
  "cluster_name": "$cluster_name",
  "spark_version": "5.2.x-scala2.11",
  "node_type_id": "Standard_DS3_v2",
  "spark_conf": {
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
    }
  ],
  "spark_env_vars": {
    "PYSPARK_PYTHON": "/databricks/python3/bin/python3",
    "LOG_ANALYTICS_WORKSPACE_ID": "$wsId",
    "LOG_ANALYTICS_WORKSPACE_KEY": "$wsKey"
  },
  "autotermination_minutes": 120
}
JSON
)"
)

# Copy and run sample notebooks

cluster_id=$(echo $cluster | jq -r .cluster_id)

databricks workspace import_dir sample-jobs/notebooks /Shared/monitoring-tutorial --overwrite

dbfs cp --overwrite sample-jobs/log4j.properties dbfs:/monitoring-tutorial/log4j.properties

for notebook in sample-jobs/notebooks/*.scala; do

  notebook_name=$(basename $notebook .scala)
  notebook_path=/Shared/monitoring-tutorial/$notebook_name
  run=$(databricks runs submit --json "$(cat << JSON
  {
    "name": "IntegrationTest",
    "existing_cluster_id": "$cluster_id",
    "timeout_seconds": 1200,
    "notebook_task": { 
      "notebook_path": "$notebook_path"
    }
  }
JSON
  )")

  # Echo job web page URL to task output to facilitate debugging
  run_id=$(echo $run | jq .run_id)
  echo "Running notebook $notebook_path"
  databricks runs get --run-id "$run_id" | jq -r .run_page_url


done

