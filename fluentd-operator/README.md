# fluentd-operator

### Log pipeline management for Kubernetes ###
Logging operator provides Kubernetes native log management for developers and devops teams. Main benefits are:

* Configure logging using Kubernetes constructs. No need to learn log configurations.
* Flexibility and Reuse through Kubernetes Custom Resource Definitions.
* Handles logging service deployment and scaling.
* Support for popular datastores like ElasticSearch, S3 and Loki.

### Understanding ###
Logging operator uses fluent-bit and fluentd for collection and processing of logs respectively. The fluent-bit component is deployed as daemonset that performs log formatting and filtering. Fluentd is used as aggregator and buffer which ships logs to chosen datastore. 

**Output** is a Custom Resource Definition that defines a datastore where logs are to be stored. Currently, the operator supports ElasticSearch, S3 and Loki as log stores.

## Logging on PMK Cluster ###
If you are using a PMK provisioned cluster, fluentd-operator can be automatically enabled on the cluster by adding appropriate tags in the UI.

For deploying elasticsearch datastore, configuring with fluentd-operator and viewing the logs in Kibana, you can simply run the below script

```
./configure-fluentd-es.sh 
```

This script deploys ECK (Elastic Cloud on Kubernetes) along with elasticsearch and kibana deployments. It also creates the `Output` Custom Resource pointing to the elasticsearch deployment and automatically forwarding logs to Kibana.

Finally you can check the index (defined in Output CR) getting created in elasticsearch and can view the logs in Kibana.


### Installing Operator (manually) ###
If operator is not already installed, you can install and configure it with with the script provided in fluentd-operator repository
```
github.com/platform9/fluentd-operator/hack/deploy.sh
```

#### Configure datastore ####
The below example shows how to forward logs to an object storage like elasticsearch.

Create output CR indicating elasticsearch as destination. Note that elasticsearch should be deployed in the same cluster.
```yaml
apiVersion: logging.pf9.io/v1alpha1
kind: Output
metadata:
  name: objstore
spec:
  type: elasticsearch
  params:
    - name: url
      value: <ELASTIC_SERVICE_FQDN>
    - name: user
      value: <ELASTIC_USERNAME>
    - name: password
      value: <ELASTIC_PASSWORD>
    - name: index_name
      value: <INDEX_NAME_IN_ELASTIC>
```
