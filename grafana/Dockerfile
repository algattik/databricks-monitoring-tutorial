ARG GRAFANA_VERSION="6.1.3"
ARG AZURE_MONITOR_PLUGIN_VERSION="0.3.0"

FROM grafana/grafana:${GRAFANA_VERSION}

USER grafana

RUN grafana-cli plugins install grafana-azure-monitor-datasource ${AZURE_MONITOR_PLUGIN_VERSION}

COPY target/provisioning/datasources/*.yaml /etc/grafana/provisioning/datasources/
COPY target/provisioning/dashboards/*.yaml /etc/grafana/provisioning/dashboards/
COPY target/dashboards/*.json /var/lib/grafana/dashboards/

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

USER root
RUN chown -R grafana:grafana /etc/grafana/provisioning /var/lib/grafana/dashboards
USER grafana
