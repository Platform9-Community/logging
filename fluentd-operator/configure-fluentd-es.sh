RCol='\e[0m'    # Text Reset
Blu='\e[0;34m'
Gre='\e[0;32m'
Yel='\e[0;33m'
BBla='\e[1;30m'
URed='\e[4;31m'
On_Whi='\e[47m'

FLUENTD_OPERATOR_DEPLOYMENTS_PATH="$PWD/deployments"
FLUENTD_NAMESPACE="logging"

ELASTIC_USER="elastic"
ELASTIC_APP="app-elasticsearch"
ELASTIC_SVC="${ELASTIC_APP}-es-http"

function deploy_elastic_stack() {
  echo -e "\n[${Blu}ACTION${RCol}] Deploying elasticsearch operator and creating CRDs...\n"
  kubectl apply -f 'https://download.elastic.co/downloads/eck/1.1.2/all-in-one.yaml'
  echo -e "\n[${Gre}RESULT${RCol}] Successfully deployed elasticsearch operator"
  
  echo -e "\n[${Blu}ACTION${RCol}] Create a storage class and setting it to default\n"
  kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
  kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  echo -e "\n[${Gre}RESULT${RCol}] Created storage class for elasticsearch"

  echo -e "\n[${Blu}ACTION${RCol}] Deploying elasticsearch application\n"
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/elasticsearch.yaml
  echo -e "\n[${Blu}ACTION${RCol}] Deploying kibana application\n"
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/kibana.yaml
}

function wait_for_deployments() {
  echo -e "\n[${Blu}ACTION${RCol}] Waiting for elasticsearch to come up..."
  es_status="$(kubectl get elasticsearch app-elasticsearch --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)"
  until [[ "$es_status" == "green" ]] || [[ "$es_status" == "yellow" ]]; do printf '.'; sleep 5; es_status="$(kubectl get elasticsearch app-elasticsearch --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)"; done; echo
  echo -e "[${Gre}RESULT${RCol}] Elasticsearch application is up and running!!"
  echo -e "\n[${Blu}ACTION${RCol}] Waiting for kibana to come up..."
  kb_status=$(kubectl get kibana app-kibana --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)
  until [[ "$kb_status" == "green" ]] || [[ "$kb_status" == "yellow" ]]; do printf '.'; sleep 5; kb_status=$(kubectl get kibana app-kibana --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null); done; echo
  echo -e "[${Gre}RESULT${RCol}] Kibana application is up and running!!"
  echo -e "\n[${Gre}RESULT${RCol}] All resources are up and running. Moving forward..."
}

function connect_fluentd_es() {
  echo -e "\n[${Blu}ACTION${RCol}] Connecting fluentd with elasticsearch\n"
  
  ELASTIC_PASS=$(kubectl get secret app-elasticsearch-es-elastic-user --namespace=$FLUENTD_NAMESPACE -o go-template='{{.data.elastic | base64decode}}')
  sed "s/%CHANGE_SVC%/$ELASTIC_SVC/; s/%CHANGE_NAMESPACE%/$FLUENTD_NAMESPACE/; s/%CHANGE_USER%/$ELASTIC_USER/ ;s/%CHANGE_PASS%/$ELASTIC_PASS/" ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic-example.yaml > ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic.yaml
  
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/cr-fluentd-elastic.yaml
  FLUENTD_POD=$(kubectl get pod --namespace=$FLUENTD_NAMESPACE -l 'k8s-app=fluentd' -o=jsonpath='{.items[0].metadata.name}')
  kubectl delete pod --namespace=$FLUENTD_NAMESPACE $FLUENTD_POD > /dev/null

  echo -e "\n[${Gre}RESULT${RCol}] Successfully established connection between fluentd and elasticsearch!!"
}

function export_kibana() {
  echo -e "\n*****************************************************************"
  echo "You can now login into kibana using below credentials"
  echo -e "\n${Gre}USERNAME:${RCol} $ELASTIC_USER"
  echo -e "${Gre}PASSWORD:${RCol} $ELASTIC_PASS"
  echo -e "\n*****************************************************************"
  kubectl port-forward service/app-kibana-kb-http --namespace=$FLUENTD_NAMESPACE 5601 > /dev/null
}

deploy_elastic_stack
wait_for_deployments
connect_fluentd_es
export_kibana

trap "{ rm -rf ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic.yaml; }" EXIT INT QUIT STOP 
