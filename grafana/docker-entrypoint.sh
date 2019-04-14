#!/bin/bash

set -euo pipefail

if [[ ! -z "$ADMIN_PASSWORD" ]]; then 
  grafana-cli admin reset-admin-password "$ADMIN_PASSWORD"
fi

sed -i \
  -e "s/\${DS_ALA}/Azure Monitor/g" \
  -e "s/YOUR_WORKSPACEID/$WORKSPACE_ID/g" \
  -e 's/"from": "now-5m",/"from": "now-1h",/g' \
  /var/lib/grafana/dashboards/SparkMonitoringDashTemplate.json

sed -i \
  -e "s/\$SUBSCRIPTION_ID/$SUBSCRIPTION_ID/g" \
  -e "s/\$TENANT_ID/$TENANT_ID/g" \
  -e "s/\$CLIENT_ID/$CLIENT_ID/g" \
  -e "s/\$WORKSPACE_ID/$WORKSPACE_ID/g" \
  -e "s/\$CLIENT_SECRET/$CLIENT_SECRET/g" \
  /etc/grafana/provisioning/datasources/datasources.yaml

#Call grafana entrypoint
/run.sh

