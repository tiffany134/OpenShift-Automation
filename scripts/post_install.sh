#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$SCRIPT_DIR/post_install.conf"
YAML_DIR=/root/OpenShift-Automation/yaml


# 檢查文件是否存在
[[ ! -f "$config_file" ]] && { echo -e "[$(date)] \e[31mERROR\e[0m：配置文件不存在"; exit 1; }

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

echo -e "[$(date)] \e[32mINFO\e[0m：post_install.conf 配置檔確認完畢，開始執行 post_install.sh"

# 主程式
main(){
#  approve_csr
 # mirror_source_config_v2
  #mirror_source_config
  #ocp_authentication
  csi_installation
  #infra_node_setup
  #create_gitea
 
}

# 驗證通過 CSR
approve_csr(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 approve_csr..."

  export KUBECONFIG=/root/ocp4/auth/kubeconfig
  # export YAML_DIR=/root/OpenShift-Automation/yaml

  TARGET_READY_COUNT=${TOTAL_NODE_NUMBER}
  CHECK_INTERVAL=$((5 * 60)) # 每 5 分鐘檢查一次
  MAX_WAIT_SECONDS=$((30 * 60)) # 最長等待 30 分鐘
  START_TIME=$(date +%s)

  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED_SECONDS" -ge "$MAX_WAIT_SECONDS" ]; then
        echo -e "[$(date)] \e[31mERROR\e[0m：等待超時（${MAX_WAIT_SECONDS}秒）"
        exit 1
    fi
    
    CURRENT_READY=$(oc get nodes -o json | \
        jq '[.items[] | select(.status.conditions[] | select(.reason == "KubeletReady" and .status == "True"))] | length')
    
    if [ "$CURRENT_READY" -eq "$TARGET_READY_COUNT" ]; then
        echo -e "$(date): \e[32mINFO\e[0m：所有節點就緒"
        break
    fi
    
    # 執行 CSR 核准
    oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
            | xargs -r oc adm certificate approve
    
    sleep $CHECK_INTERVAL
  done

  echo -e "[$(date)] \e[32mINFO\e[0m：approve_csr 執行完成"
}

#配置 mirror 來源
# mirror_source_config(){
#   echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 mirror_source_config..."

#   # 關閉預設 catalog source
#   oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'

#   # 查找 redhat operator catalogsource
#   redhat_operator_cs=$(find /root/oc-mirror-workspace/ -maxdepth 2 -path "*/results-*" -type f -name "catalogSource-cs-redhat-operator-index.yaml")
#   icsp=$(find /root/oc-mirror-workspace/ -maxdepth 2 -path "*/results-*" -type f -name "imageContentSourcePolicy.yaml")

#   # 檢查是否找到文件
#   if [ ! -f "$redhat_operator_cs" ] || [ ! -f "$icsp" ]; then
#     echo -e "[$(date)] \e[31mERROR\e[0m：未找到 catalogSource-cs-redhat-operator-index.yaml 和 imageContentSourcePolicy.yaml 文件"
#     exit 1
#   fi

#   # 找到文件後將 name 替換成 redhat-operators
#   sed -i.bak '/^ *name: /s/cs-redhat-operator-index/redhat-operators/' $redhat_operator_cs

#   # 將 CatalogSource apply 
#   oc apply -f $redhat_operator_cs
#   oc apply -f $icsp

#   echo -e "[$(date)] \e[32mINFO\e[0m：mirror_source_config 執行完成"
# }
#-----------------------------------------------------------------------
# 配置 mirror 來源 (適用於 oc mirror --v2)
_apply_single_mirror_config(){
  local root_dir="$1" # 使用更簡潔的變數名

  echo -e "[$(date)] \e[32mINFO\e[0m：處理目錄: \e[1m$root_dir\e[0m"

  local config_path="${root_dir}/cluster-resources"
  [[ ! -d "$config_path" ]] && { echo -e "[$(date)] \e[31mERROR\e[0m：未找到 'cluster-resources' 目錄於 '$root_dir'。"; return 1; }

  echo -e "[$(date)] \e[32mINFO\e[0m：在 \e[1m$config_path\e[0m 中尋找配置文件..."

  # 查找並應用 ImageContentSourcePolicy (ICSP)
  # 使用陣列收集，並循環應用
  local -a icsp_files=()
  [[ -f "${config_path}/idms-oc-mirror.yaml" ]] && icsp_files+=("${config_path}/idms-oc-mirror.yaml")
  [[ -f "${config_path}/itms-oc-mirror.yaml" ]] && icsp_files+=("${config_path}/itms-oc-mirror.yaml")

  if (( ${#icsp_files[@]} == 0 )); then
    echo -e "[$(date)] \e[31mERROR\e[0m：未找到任何 ImageContentSourcePolicy 文件 (idms-oc-mirror.yaml 或 itms-oc-mirror.yaml)。"
    return 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：找到並應用 ImageContentSourcePolicy 文件："
  printf "%s\n" "${icsp_files[@]}"
  for file in "${icsp_files[@]}"; do
    oc apply -f "$file"
  done

  # 查找並應用 CatalogSource (CS)
  local -a cs_files=()
  while IFS= read -r -d $'\0' file; do
    cs_files+=("$file")
  done < <(find "$config_path" -maxdepth 1 -type f \( -name "cc-redhat-operator-index-v*.yaml" -o -name "cs-redhat-operator-index-v*.yaml" \) -print0)

  if (( ${#cs_files[@]} == 0 )); then
    echo -e "[$(date)] \e[31mERROR\e[0m：未找到任何 CatalogSource 文件 (cc-redhat-operator-index-v*.yaml 或 cs-redhat-operator-index-v*.yaml)。"
    return 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：找到並應用 CatalogSource 文件："
  printf "%s\n" "${cs_files[@]}"
  for file in "${cs_files[@]}"; do
    oc apply -f "$file"
  done

  echo -e "[$(date)] \e[32mINFO\e[0m：成功處理目錄: \e[1m$root_dir\e[0m"
  return 0
}


# 函數：處理多個 oc mirror 工作目錄的配置應用 (供 main() 調用)
mirror_source_config_v2(){
  echo -e "[$(date)] \e[32mINFO\e[0m：啟動離線鏡像來源配置..."

  # 關閉預設 OperatorHub 來源 (這一步只執行一次)
  echo -e "[$(date)] \e[32mINFO\e[0m：關閉預設 OperatorHub 來源..."
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]' \
    || { echo -e "[$(date)] \e[31mERROR\e[0m：關閉預設 OperatorHub 來源失敗。"; exit 1; }

  # 定義 oc mirror 工作目錄 (請替換為你的實際路徑)
  local -a OCMIRROR_WORKSPACES=(
    "/root/install_source/mirror/generated/working-dir" # 範例路徑
  
  )

  # 迴圈處理每個工作目錄
  for path in "${OCMIRROR_WORKSPACES[@]}"; do
    echo -e "\n------------------------------------------------------------"
    echo -e "[$(date)] \e[34m處理中: $path\e[0m"
    
    _apply_single_mirror_config "$path" || {
      echo -e "[$(date)] \e[31mFATAL ERROR\e[0m：處理目錄 '$path' 失敗，終止操作。"
      exit 1
    }
    
    echo -e "------------------------------------------------------------"
  done

  echo -e "[$(date)] \e[32mINFO\e[0m：所有指定目錄處理完成。"
}
#-----------------------------------------------------------------------
# 建立 OCP 的認證機制
ocp_authentication(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 ocp_authentication..."

  # 建立一個名為 htpass-secret 的 Secret 來儲存 htpasswd 檔案，帳密為ocpadmin P@ssw0rdocp
  oc apply -f ${YAML_DIR}/authentication/secret_htpasswd.yaml
 
  # 將資源套用至預設 OAuth 配置以新增identity provider。
  oc apply -f ${YAML_DIR}/authentication/oauth.yaml

  # 賦予 ocpadmin 帳號 cluster-admin role
  oc adm policy add-cluster-role-to-user cluster-admin ocpadmin
  
  oc get secret htpass-secret -n openshift-config > /dev/null 2>&1
  htpass_secret_status=$?
  oc get secret kubeadmin -n kube-system > /dev/null 2>&1
  kubeadmin_secret_status=$?

  # 檢查 htpasswd Secret 和 kubeadmin secret 是否存在
  if [ $htpass_secret_status -eq 0 ] && [ $kubeadmin_secret_status -eq 0 ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：Secret [htpass-secret] 已存在，刪除 kubeadmin。"

    # 刪除 kubeadmin 
    oc delete secret kubeadmin -n kube-system

  # 檢查 htpasswd Secret 是否存在
  elif [ $htpass_secret_status -ne 0 ]; then
    echo -e "[$(date)] \e[31mERROR\e[0m：Secret [htpass-secret] 不存在，請確認是否建立 Secert。"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：ocp_authentication 執行完成"
}

# 安裝 CSI 及創建預設 storageclass
csi_installation(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 csi_installation..."

  # export OCP_DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
  export OCP_DOMAIN=ocp4.example.com
  export OCP_VERSION=418
    
  source /root/OpenShift-Automation/scripts/install_csi.sh

  # 主程式入口
  case "$CSI_MODULE" in
    nfs-csi)
      export STORAGE_CLASS_NAME=${NFS_STORAGE_CLASS_NAME}
      export STORAGE_NAMESPACE=${NFS_NAMESPACE}
      nfs_csi
      ;;
    trident)
      export STORAGE_CLASS_NAME=${TRIDENT_STORAGE_CLASS_NAME}
      export STORAGE_NAMESPACE=${TRIDENT_NAMESPACE}
      trident
      ;;
    *)
      echo -e "[$(date)] \e[32mINFO\e[0m：用法: $0 {nfs-nsi|trident} [目錄]"
      exit 1
      ;;
  esac
  
  wait

  # 檢查 StorageClass 是否創建成功
  if oc get storageclass ${STORAGE_CLASS_NAME} &> /dev/null; then
    echo -e "[$(date)] \e[32mINFO\e[0m： ${STORAGE_CLASS_NAME} 配置完成！CSI 及預設 storageclass 安裝完成！"
  else
    echo -e "[$(date)] \e[31mERROR\e[0m：CSI 及預設 StorageClass 創建失敗！"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：csi_installation 執行完成"
}

# 配置 infra 節點
infra_node_setup(){
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 infra_node_setup..."

  if [ "${INSTALL_MODE}" == "standard" ]; then
    # standard mode 時執行以下動作
    echo -e "[$(date)] \e[32mINFO\e[0m：配置 standard 模式"

    # 設定infra node mcp
    oc apply -f ${YAML_DIR}/infra/mcp_infra.yaml

    # 將 infra node role 改為 infra
    # for i in {01..03}; do
      for i in {1..3}; do

      oc label nodes infra$i.${OCP_DOMAIN} node-role.kubernetes.io/infra='';
      oc label nodes infra$i.${OCP_DOMAIN} node-role.kubernetes.io/worker-;
      oc adm taint node infra$i.${OCP_DOMAIN} \
      node-role.kubernetes.io/infra:NoSchedule \
      node-role.kubernetes.io/infra:NoExecute;
    done

    # 設定 Ingress pod to infra node
    oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas":3,"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}}'

    # Moving monitoring components to infra node 並設定 PV
    oc apply -f ${YAML_DIR}/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml

  elif [ "${INSTALL_MODE}" == "compact" ]; then
    # compact mode 時執行以下動作
    echo -e "[$(date)] \e[32mINFO\e[0m：配置 compact 模式"

    # monitoring components 設定 PV
    oc apply -f ${YAML_DIR}/infra/cm_cluster-monitoring-config-${INSTALL_MODE}.yaml
  else
    echo -e "[$(date)] \e[31mERROR\e[0m：模式配置錯誤"
    exit 1
  fi

  echo -e "[$(date)] \e[32mINFO\e[0m：infra_node_setup 執行完成"
}

# 創建 gitea server
create_gitea(){ 
  echo -e "[$(date)] \e[32mINFO\e[0m：開始執行 create_gitea..."
  export OCP_DOMAIN=ocp4.example.com
  export GITEA_VERSION=${GITEA_VERSION}
  export OCP_VERSION=418
  # 檢查 gitea pod 是否存在
  GITEA_STATUS=$(oc get pod -l app=gitea -n gitea -ojsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)

  if [ "${GITEA_STATUS}x" == "truex" ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：GITEA 已建立，請執行帳號登錄"OCP_VERSION
    exit 1
  fi

  oc get sa gitea-sa -n gitea > /dev/null 2>&1
  gitea_sa_status=$?

  # 建立 gitea 權限
  if [ $gitea_sa_status -eq 0 ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：ServiceAccount [gitea-sa] 已存在"
  else
    envsubst < ${YAML_DIR}/gitea/ns_gitea.yaml |oc apply -f -
    oc create sa gitea-sa -n gitea
    oc adm policy add-scc-to-user anyuid -z gitea-sa -n gitea
  fi
  
  # 配置鏡像參數
  envsubst < ${YAML_DIR}/gitea/create-gitea.yaml |oc apply -f -
  envsubst < ${YAML_DIR}/gitea/postgresql.yaml |oc apply -f -

  echo -e "[$(date)] \e[32mINFO\e[0m：create_gitea 執行完成"
  echo -e "[$(date)] \e[32mINFO\e[0m：post_install 腳本執行完成，GITEA 已建立，請執行帳號登錄"
}

main
