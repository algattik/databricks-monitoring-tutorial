#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Clone the repository to be compiled
git clone https://github.com/algattik/spark-monitoring.git

# Patch source for Spark 2.4.0
sed -ie "s/<spark.version>2.3.1</<spark.version>$SPARK_VERSION</" spark-monitoring/src/pom.xml

# Read Tenant ID and Subscription ID from current subscription
read TENANT_ID SUBSCRIPTION_ID <<< $(az account show --query '{tenantId:tenantId,id:id}' -o tsv)

# Install Databricks CLI
sudo apt-get install -y python3-setuptools
pip3 install wheel
pip3 install databricks-cli
sudo ln -s /home/vsts/.local/bin/* /usr/local/bin/

# Check installation
databricks clusters list

# The name of the Log Analytics instance where tests will be run. Generate a unique name.
LOGANALYTICS_INSTANCE="$RESOURCE_NAME_PREFIX$BUILD_BUILDID"

# Deploy Log Analytics instance from template and grant access from Grafana
az group deployment create -g $RESOURCE_GROUP --template-file spark-monitoring/perftools/deployment/loganalytics/logAnalyticsDeploy.json --parameters workspaceName="$LOGANALYTICS_INSTANCE" -o table

# Get an AAD authentication token for ARM
# NB: $servicePrincipalId and $servicePrincipalKey passed as env vars
curl="curl --silent --show-error --fail"
armToken=$($curl -X POST \
	--data-urlencode "grant_type=client_credentials" \
	--data-urlencode "client_id=$servicePrincipalId" \
	--data-urlencode "client_secret=$servicePrincipalKey" \
	--data-urlencode "resource=https://management.azure.com/" \
	"https://login.microsoftonline.com/$TENANT_ID/oauth2/token" \
| jq -r '.token_type + " " + .access_token')

# Get Log Analytics Workspace ID and Key
LOG_ANALYTICS_WORKSPACE_ID=$($curl -X GET -H "Authorization: $armToken" -H "Content-Type: application/json" https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$LOGANALYTICS_INSTANCE?api-version=2015-11-01-preview | jq -r .properties.customerId)
LOG_ANALYTICS_WORKSPACE_KEY=$($curl -X POST -d '' -H "Authorization: $armToken" -H "Content-Type: application/json" https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$LOGANALYTICS_INSTANCE/sharedKeys?api-version=2015-11-01-preview | jq -r .primarySharedKey)


# Set job variable from script, to be used by other scripts in the pipeline
echo "##vso[task.setvariable variable=TENANT_ID]$TENANT_ID"
echo "##vso[task.setvariable variable=SUBSCRIPTION_ID]$SUBSCRIPTION_ID"
echo "##vso[task.setvariable variable=LOGANALYTICS_INSTANCE]$LOGANALYTICS_INSTANCE"
echo "##vso[task.setvariable variable=LOG_ANALYTICS_WORKSPACE_ID]$LOG_ANALYTICS_WORKSPACE_ID"
echo "##vso[task.setvariable variable=LOG_ANALYTICS_WORKSPACE_KEY]$LOG_ANALYTICS_WORKSPACE_KEY"
