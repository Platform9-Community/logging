Loki is log aggregation system inspired by Prometheus. See the [repository](https://github.com/grafana/loki/) for details.

It indexes only log metadata (e.g., labels such as pod, node, and container), not the full text. The Grafana dashboard provides a basic query interface in its Explore tab.

Loki has the same architecture as Cortex, which means it is also multi-tenant and horizontally scalable. Because it is easy to find the specific logs for a specific time range, it is easy to correlate the logs with metrics. This makes Loki a good solution for diagnosing an issue in a workload cluster.