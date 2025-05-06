#!/bin/bash
config_file="post_config.conf"

# 檢查文件是否存在
[[ ! -f "$config_file" ]] && { echo "ERROR：配置文件不存在"; exit 1; }

# 逐行讀取並解析
while IFS= read -r line || [[ -n "$line" ]]; do
  # 去除註解和空白
  line_clean=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # 跳過空行
  [[ -z "$line_clean" ]] && continue
  
  # 分割鍵值並賦值
  key=$(echo "$line_clean" | cut -d '=' -f 1 | xargs)
  value=$(echo "$line_clean" | cut -d '=' -f 2- | xargs)
  # 定義變量
  declare -- "$key=$value"
done < "$config_file"

# 主程式
main(){
  approve_csr
  mirror_source_config
  ocp_authentication
  infra_node_setup
  create_gitea
}

approve_csr(){
  KUBECONFIG=/root/ocp4/auth/kubeconfig

  TARGET_READY_COUNT=3
  CHECK_INTERVAL=$((5 * 60)) # 每 5 分鐘檢查一次
  MAX_WAIT_SECONDS=$((30 * 60)) # 最長等待 30 分鐘
  START_TIME=$(date +%s)

  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED_SECONDS" -ge "$MAX_WAIT_SECONDS" ]; then
        echo "$(date): ERROR：等待超時（${MAX_WAIT_SECONDS}秒）"
        exit 1
    fi
    
    CURRENT_READY=$(oc get nodes -o json | \
        jq '[.items[] | select(.status.conditions[] | select(.reason == "KubeletReady" and .status == "True"))] | length')
    
    if [ "$CURRENT_READY" -eq "$TARGET_READY_COUNT" ]; then
        echo "$(date): 所有節點就緒"
        exit 0
    fi
    
    # 執行 CSR 核准
    oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
            | xargs -r oc adm certificate approve
    
    sleep $CHECK_INTERVAL
  done
}

mirror_source_config(){
  # 關閉預設 catalog source
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'

  # 查找 redhat operator catalogsource
  redhat_operator_cs=$(find /root/oc-mirror-workspace/ -maxdepth 2 -path "*/result-*" -type f -name "catalogSource-cs-redhat-operator-index.yaml")

  # 檢查是否找到文件
  if [ -z "$redhat_operator_cs" ]; then
    echo "ERROR：未找到 catalogSource-cs-redhat-operator-index.yaml 文件"
    exit 1
  fi

  # 找到文件後將 name 替換成 redhat-operators
  sed -i.bak '/^ *name: /s/cs-redhat-operator-index/redhat-operators/' $redhat_operator_cs

  # 將 CatalogSource apply 
  oc apply -f $redhat_operator_cs
}

ocp_authentication(){
  # 建立一個名為 htpass-secret 的 Secret 來儲存 htpasswd 檔案，帳密為ocpadmin P@ssw0rdocp
  oc apply -f yaml/authentication/secret_htpasswd.yaml
 
  # 將資源套用至預設 OAuth 配置以新增identity provider。
  oc apply -f yaml/authentication/oauth.yaml

  # 賦予 ocpadmin 帳號 cluster-admin role
  oc adm policy add-cluster-role-to-user cluster-admin ocpadmin

  # 刪除 kubeadmin 
  oc delete secret kubeadmin -n kube-system
}

infra_node_setup(){
  if [ "$2" == "standard" ]; then
    # standard mode 時執行以下動作

    # 設定infra node mcp
    oc apply -f mcp_infra.yaml

    # 設定 OCP FQDN
    DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")

    # 將 infra node role 改為 infra
    for i in {01..03}; do
      oc label nodes infra$i.${DOMAIN} node-role.kubernetes.io/infra='';
      oc label nodes infra$i.${DOMAIN} node-role.kubernetes.io/worker-;
      oc adm taint node infra$i.${DOMAIN} \
      node-role.kubernetes.io/infra:NoSchedule \
      node-role.kubernetes.io/infra:NoExecute;
    done

    # 設定 Ingress pod to infra node
    oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas":3,"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}}'

    # Moving monitoring components to infra node 並設定 PV
    oc apply -f yaml/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml

  elif [ "$2" == "compact" ]; then
    # compact mode 時執行以下動作

    # monitoring components 設定 PV
    oc apply -f yaml/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml
  else
    echo "模式配置錯誤"
    exit 1
  fi
}

create_gitea(){
  # 配置鏡像參數
  envsubst < create-gitea.yaml |oc apply -f -
  envsubst < postgresql.yaml |oc apply -f -
  envsubst < postgresql.yaml |oc apply -f -

  # 建立 gitea 權限
  oc create sa gitea-sa
  oc adm policy add-scc-to-user anyuid -z gitea-sa
}

main