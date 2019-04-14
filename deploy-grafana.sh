#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Resources to be created
acr_name="$RESOURCE_NAME_PREFIX$BUILD_BUILDID"
webapp_name="$RESOURCE_NAME_PREFIX$BUILD_BUILDID"

# Deploy ACR
az acr create --resource-group $RESOURCE_GROUP --name $acr_name --sku Basic --admin-enabled -o table
az acr login --name $acr_name -o table

# Prepare resources for Docker container
target=grafana/target
mkdir -p $target/provisioning/datasources/
mkdir -p $target/provisioning/dashboards/
mkdir -p $target/dashboards/
cp spark-monitoring/perftools/dashboards/grafana/SparkMonitoringDashTemplate.json $target/dashboards/
cp grafana/datasources.yaml $target/provisioning/datasources/
cp grafana/dashboards.yaml $target/provisioning/dashboards/

# Build Docker container
container_tag="$acr_name.azurecr.io/grafana-databricks"
docker build -t "$container_tag" grafana
docker push "$container_tag"

# Deploy webapp with dummy initial container
az appservice plan create -g $RESOURCE_GROUP -n $webapp_name --is-linux --sku S1 -o table
az webapp create -g $RESOURCE_GROUP -n $webapp_name -p $webapp_name -i nginx -o table
az webapp config set -g $RESOURCE_GROUP -n $webapp_name --always-on true -o table
az webapp log config -g $RESOURCE_GROUP -n $webapp_name --web-server-logging filesystem --docker-container-logging filesystem -o table

GRAFANA_PASSWORD=$(uuidgen)

az webapp config appsettings set -g $RESOURCE_GROUP -n $webapp_name -o table --settings \
  WORKSPACE_ID=$LOG_ANALYTICS_WORKSPACE_ID \
  SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
  TENANT_ID=$TENANT_ID \
  CLIENT_ID=$LOG_ANALYTICS_READER_CLIENT_ID \
  CLIENT_SECRET=$LOG_ANALYTICS_READER_CLIENT_SECRET \
  ADMIN_PASSWORD=$GRAFANA_PASSWORD

az webapp config container set -n $webapp_name -g $RESOURCE_GROUP -c "$container_tag" -r $acr_name.azurecr.io -o table


webapp_url="https://$(az webapp show -g $RESOURCE_GROUP -n $webapp_name | jq -r .defaultHostName)"

function set_home_dashboard {
  echo
  echo "Trying to update Grafana home dashboard (will fail until Grafana is up)..."
  curl --silent --show-error --fail $webapp_url/api/org/preferences \
    -X PUT \
    -d '{"homeDashboardId":1}' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Basic $(echo -n admin:$GRAFANA_PASSWORD | base64)"
}
for i in {1..40}; do set_home_dashboard && break || sleep 10; done
echo


echo "Grafana deployed at"
echo "  $webapp_url"
echo "  user: admin"
echo "  password: $GRAFANA_PASSWORD"

