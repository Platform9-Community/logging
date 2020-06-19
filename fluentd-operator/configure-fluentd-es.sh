#!/bin/bash

DU_FQDN="<DU_FQDN>"
DU_USERNAME="<DU_USERNAME>"
DU_PASSWORD="<DU_PASSWORD>"
DU_CLUSTER="<DU_CLUSTER_NAME>"

# SETTING COLOURS IN SCRIPT
RCol='\e[0m'    
Blu='\e[0;34m'
Gre='\e[0;32m'
Red='\e[0;31m'
Bk_Bla='\e[1;30m'
On_Whi='\e[47m'

FLUENTD_OPERATOR_DEPLOYMENTS_PATH="$PWD/deployments"
FLUENTD_NAMESPACE="logging"

ELASTIC_USER="elastic"
ELASTIC_APP="app-elasticsearch"
ELASTIC_SVC="${ELASTIC_APP}-es-http"

function cleanup() {
  rm -rf ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic.yaml
  rm -rf $PWD/kubeconfig
  exit
}
trap 'cleanup' SIGINT SIGQUIT SIGTSTP

function export_kubeconfig() {
  echo -e "\n[${Blu}ACTION${RCol}] Downloading kubeconfig for the cluster ${Bk_Bla}${On_Whi}$DU_CLUSTER${RCol} on DU ${Bk_Bla}${On_Whi}$DU_FQDN${RCol}"
  BASE_URL="https://$DU_FQDN"
  AUTH_REQUEST_PAYLOAD="{
  \"auth\":{
    \"identity\":{
      \"methods\":[
        \"password\"
      ],
      \"password\":{
        \"user\":{
          \"name\":\"$DU_USERNAME\",
          \"domain\":{
            \"id\":\"default\"
            },
          \"password\":\"$DU_PASSWORD\"
          }
        }
      }
    }
  }"
  
  # ===== KEYSTONE API CALLS ====== #
  KEYSTONE_URL="$BASE_URL/keystone/v3"
  
  X_AUTH_TOKEN=$(curl -si \
    -H "Content-Type: application/json" \
    $KEYSTONE_URL/auth/tokens\?nocatalog \
    -d "$AUTH_REQUEST_PAYLOAD" | sed -En 's#^x-subject-token:\s(.*)$#\1#p' | tr -d "\n\r")
  
  PROJECT_UUID=$(curl -s \
    -H "Content-Type: application/json" \
    -H "X-AUTH-TOKEN: $X_AUTH_TOKEN" \
    $KEYSTONE_URL/auth/projects | jq -r '.projects[0].id')

  # ===== QBERT API CALLS ====== #
  
  QBERT_URL="$BASE_URL/qbert/v3"
  
  CLUSTER_UUID=$(curl -s \
    -H "Content-Type: application/json" \
    -H "X-AUTH-TOKEN: $X_AUTH_TOKEN" \
    $QBERT_URL/$PROJECT_UUID/clusters | jq -r '.[] | select(.name == '\"$DU_CLUSTER\"') | .uuid')
  
  curl -s -o "kubeconfig"\
    -H "Content-Type: application/json" \
    -H "X-AUTH-TOKEN: $X_AUTH_TOKEN" \
    "$QBERT_URL/$PROJECT_UUID/kubeconfig/$CLUSTER_UUID"
 
  sed -i "s/__INSERT_BEARER_TOKEN_HERE__/$X_AUTH_TOKEN/" "$PWD/kubeconfig"
  export KUBECONFIG="$PWD/kubeconfig"
  echo -e "\n[${Gre}RESULT${RCol}] Kubeconfig for the cluster $DU_CLUSTER downloaded successfully"
}

function verify_fluentd_operator() {
  echo -e "\n[${Blu}ACTION${RCol}] Verifying fluentd-operator exists..."
  kubectl get namespace $FLUENTD_NAMESPACE > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo -e "\n[${Gre}RESULT${RCol}] Fluentd-operator is up and running..."
  else
    kubectl create namespace $FLUENTD_NAMESPACE
  fi
}

function deploy_elastic_stack() {
  echo -e "\n[${Blu}ACTION${RCol}] Deploying elasticsearch operator and creating CRDs...\n"
  kubectl apply -f 'https://download.elastic.co/downloads/eck/1.1.2/all-in-one.yaml'
  echo -e "\n[${Gre}RESULT${RCol}] Successfully deployed elasticsearch operator"
  
  echo -e "\n[${Blu}ACTION${RCol}] Create a storage class and setting it to default\n"
  kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  echo -e "\n[${Gre}RESULT${RCol}] Created storage class for elasticsearch"

  echo -e "\n[${Blu}ACTION${RCol}] Deploying ${Bk_Bla}${On_Whi}elasticsearch${RCol} application\n"
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/elasticsearch.yaml
  echo -e "\n[${Blu}ACTION${RCol}] Deploying ${Bk_Bla}${On_Whi}kibana${RCol} application\n"
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/kibana.yaml
}

function wait_for_deployments() {
  echo -e "\n[${Blu}ACTION${RCol}] Waiting for elasticsearch and kibana deployments to come up..."
  es_status="$(kubectl get elasticsearch app-elasticsearch --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)"
  until [[ "$es_status" == "green" ]] || [[ "$es_status" == "yellow" ]]; do printf '.'; sleep 5; es_status="$(kubectl get elasticsearch app-elasticsearch --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)"; done
  kb_status=$(kubectl get kibana app-kibana --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null)
  until [[ "$kb_status" == "green" ]] || [[ "$kb_status" == "yellow" ]]; do printf '.'; sleep 5; kb_status=$(kubectl get kibana app-kibana --namespace=$FLUENTD_NAMESPACE -o=jsonpath='{.status.health}' 2> /dev/null); done; echo
  echo -e "\n[${Gre}RESULT${RCol}] All the deployments are up and running. Moving forward..."
}

function connect_fluentd_es() {
  echo -e "\n[${Blu}ACTION${RCol}] Connecting fluentd with elasticsearch\n"
  
  ELASTIC_PASS=$(kubectl get secret app-elasticsearch-es-elastic-user --namespace=$FLUENTD_NAMESPACE -o go-template='{{.data.elastic | base64decode}}')
  sed "s/%CHANGE_SVC%/$ELASTIC_SVC/; s/%CHANGE_NAMESPACE%/$FLUENTD_NAMESPACE/; s/%CHANGE_USER%/$ELASTIC_USER/ ;s/%CHANGE_PASS%/$ELASTIC_PASS/" ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic-example.yaml > ${FLUENTD_OPERATOR_DEPLOYMENTS_PATH}/cr-fluentd-elastic.yaml
  
  kubectl apply -f $FLUENTD_OPERATOR_DEPLOYMENTS_PATH/cr-fluentd-elastic.yaml
  FLUENTD_POD=$(kubectl get pod --namespace=$FLUENTD_NAMESPACE -l 'k8s-app=fluentd' -o=jsonpath='{.items[0].metadata.name}')
  kubectl delete pod --namespace=$FLUENTD_NAMESPACE $FLUENTD_POD > /dev/null

  echo -e "\n[${Gre}RESULT${RCol}] Successfully established connection between ${Bk_Bla}${On_Whi}fluentd and elasticsearch${RCol}!!"
}

function export_kibana() {
  echo -e "\n*****************************************************************"
  echo "You can now login into kibana from your browser using below credentials"
  echo -e "\n${Gre}URL:${RCol} https://localhost:5601"
  echo -e "${Gre}USERNAME:${RCol} $ELASTIC_USER"
  echo -e "${Gre}PASSWORD:${RCol} $ELASTIC_PASS"

  echo -e "\n[${Red}NOTE${RCol}] Make sure you are connected to VPN while accessing Kibana"
  echo -e "\n*****************************************************************"
  kubectl port-forward service/app-kibana-kb-http --namespace=$FLUENTD_NAMESPACE 5601 > /dev/null
}

echo -e "\n[${Red}NOTE${RCol}] Make sure you are connected to VPN before running the script"
export_kubeconfig
verify_fluentd_operator
deploy_elastic_stack
wait_for_deployments
connect_fluentd_es
export_kibana
