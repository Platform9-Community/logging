# Promtail deployment

Promtail is an agent purpose-designed to process and ship logs to Loki. See the 
[docs](https://github.com/grafana/loki/blob/master/docs/promtail.md) for details.

We use this helm chart to deploy Promtail in a workload cluster, configured to 
send logs to Loki in the management cluster.