#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Clone the repository to be tested
git clone --single-branch --branch $GIT_BRANCH https://github.com/mspnp/spark-monitoring.git

# Patch source for Spark 2.4.0
sed -ie "s/<spark.version>2.3.1</<spark.version>$SPARK_VERSION</" spark-monitoring/src/pom.xml

# Install Databricks CLI
sudo apt-get install -y python3-setuptools
pip3 install wheel
pip3 install databricks-cli
sudo ln -s /home/vsts/.local/bin/* /usr/local/bin/

# Check installation
databricks clusters list

# The name of the Log Analytics instance where tests will be run. Generate a unique name.
loganalytics_instance="$RESOURCE_NAME_PREFIX$BUILD_BUILDID"
echo $loganalytics_instance > loganalytics_instance.txt

# Deploy Log Analytics instance from tempate
az group deployment create -g $RESOURCE_GROUP --template-file spark-monitoring/perftools/deployment/loganalytics/logAnalyticsDeploy.json --parameters workspaceName="$loganalytics_instance" serviceTier=PerGB2018 location="$LOG_ANALYTICS_LOCATION"

