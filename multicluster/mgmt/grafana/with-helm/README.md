# Fetch chart
```
VERSION=3.8.3
helm fetch stable/grafana --version=$VERSION --untar
```

# Customize
Edit grafana/values.yaml

# Install
```
kubectl -n monitoring apply -f configuration
helm install grafana --name grafana --namespace monitoring
```
