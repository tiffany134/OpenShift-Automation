#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$SCRIPT_DIR/operators_install.conf"

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

echo "INFO：operators_install.conf 配置檔確認完畢，開始執行 operators_install.sh"

# 主程式
main(){
  define_global_env
  create_git_repo
  update_gitops_content
  push_git
  execute_gitops
}

# 設定全域環境變數
define_global_env(){
  echo "INFO：開始執行 define_global_env..."

  # OCP FQDN
  export OCP_DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
  export ENCODED_PASSWORD=$(jq -rn --arg v "${GITEA_PASSWORD}" '$v|@uri')
  export REGISTRY_URL="bastion.${OCP_DOMAIN}:8443/ocp418"

  # gitea route url 及帳號密碼
  export GITEA_URL=${GITEA_ADMIN}:${ENCODED_PASSWORD}@gitea-gitea.apps.${OCP_DOMAIN}
  export GITEA_REPO=gitea-gitea.apps.${OCP_DOMAIN}/${GITEA_ADMIN}

  # 預設 storageclass
  export DEFAULT_SC=$(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class == "true")]}{.metadata.name}{"\n"}{end}')

  echo "INFO：define_global_env 執行完成"
}

# 創建 gitops repo
create_git_repo(){
  echo "INFO：開始執行 create_git_repo..."

  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -k GET "https://${GITEA_URL}/api/v1/repos/${GITEA_ADMIN}/OpenShift-EaaS-Practice")

  if [ "${RESPONSE}" = "200" ]; then
    echo "INFO：程式庫已存在！"
  else
    echo "INFO：程式庫未找到。建立 OpenShift-EaaS-Practice 程式庫"
    
    # 使用 gitea api 創建 repo
    curl -k -X POST "https://${GITEA_URL}/api/v1/admin/users/${GITEA_ADMIN}/repos" \
       -H "Content-Type: application/json" \
       -d '{
         "name": "OpenShift-EaaS-Practice",
         "default_branch": "main",
         "private": false,
         "auto_init": false 
       }'
  fi

  echo "INFO：create_git_repo 執行完成"
}

# 搜尋 EaaS 內要替換的文件
collect_eaas_target_files(){
  echo "INFO：開始執行 collect_eaas_target_files..."

  local tmpfile=$(mktemp)

  # pattern 內條件 1 & 2：在目標目錄中搜索
  for pattern in "${REPLACE_PATTERNS[@]:0:2}"; do
    grep -rl --null "$pattern" "${OCP_EAAS_DIR}/" >> "$tmpfile"
  done
  
  # pattern 內條件 3：單獨處理特殊文件
  if [[ -f "$LOKI_KUSTOMIZATION_FILE" ]] && grep -q 'gp3-csi' "$LOKI_KUSTOMIZATION_FILE"; then
    printf "%s\0" "$LOKI_KUSTOMIZATION_FILE" >> "$tmpfile"
  fi
  
  # 去重並返回結果
  sort -zu "$tmpfile" | uniq -z
  rm "$tmpfile"  
}

# 更新 gitops repo 內的參數
update_gitops_content(){
  echo "INFO：開始執行 update_gitops_content..."

  OCP_EAAS_DIR="/root/OpenShift-EaaS-Practice"
  BACKUP_EAAS_DIR="/tmp/ocp-eaas-backup"

  REPLACE_PATTERNS=(
    'github.com/CCChou'
    'quay.io'
    'gp3-csi'
  )

  LOKI_KUSTOMIZATION_FILE="${OCP_EAAS_DIR}/clusters/${GITOPS_CLUSTER_TYPE}/overlays/loki-configuration/kustomization.yaml"

  # 子函數：搜尋要被替換的目標檔案
  collect_eaas_target_files() {
    local tmpfile=$(mktemp)

    # 搜尋 pattern 1、2
    for pattern in "${REPLACE_PATTERNS[@]:0:2}"; do
      grep -rlZ "$pattern" "${OCP_EAAS_DIR}/" >> "$tmpfile"
    done

    # 加入特殊 Loki 檔案
    if [[ -f "$LOKI_KUSTOMIZATION_FILE" ]] && grep -q 'gp3-csi' "$LOKI_KUSTOMIZATION_FILE"; then
      printf "%s\0" "$LOKI_KUSTOMIZATION_FILE" >> "$tmpfile"
    fi

    sort -zu "$tmpfile"
    rm -f "$tmpfile"
  }

  # 檢查 .bootstrap 是否存在
  if [[ ! -d "${OCP_EAAS_DIR}/.bootstrap" ]]; then
    echo "ERROR：找不到 .bootstrap 目錄，請確認該資料夾存在！"
    exit 1
  fi

  # 建立備份（首次才備份）
  if [[ ! -d "$BACKUP_EAAS_DIR" ]]; then
    echo "INFO：初始化備份目錄: $BACKUP_EAAS_DIR"
    mkdir -p "$BACKUP_EAAS_DIR"

    collect_eaas_target_files | while IFS= read -r -d '' file; do
      rel_path="${file#$OCP_EAAS_DIR/}"
      dest_path="$BACKUP_EAAS_DIR/$rel_path"
      mkdir -p "$(dirname "$dest_path")"
      cp -v "$file" "$dest_path"
    done
  fi

  # 還原備份
  echo "INFO：還原備份文件..."
  rsync -a --exclude=".git" "$BACKUP_EAAS_DIR/" "$OCP_EAAS_DIR/"

  # 開始替換操作
  echo "INFO：開始替換操作..."

  collect_eaas_target_files | xargs -0 sed -i "s#github.com/CCChou#${GITEA_REPO}#g"
  collect_eaas_target_files | xargs -0 sed -i "s#quay.io#${REGISTRY_URL}#g"

  if [[ -f "$LOKI_KUSTOMIZATION_FILE" ]]; then
    sed -i "s#gp3-csi#${DEFAULT_SC}#g" "$LOKI_KUSTOMIZATION_FILE"
  fi

  echo "INFO：替換操作完成！備份文件保存在: $BACKUP_EAAS_DIR"
  echo "INFO：update_gitops_content 執行完成"
}

# 將本地 git 推送至 gitea
push_git(){
  echo "INFO：開始執行 push_git..."

  cd /root/OpenShift-EaaS-Practice/

  git config --global http.sslVerify false
  git config --global user.email "${GITEA_ADMIN}@example.com"
  git config --global user.name "${GITEA_ADMIN}"

  git commit -a -m 'update'
  git remote set-url origin https://${GITEA_URL}/${GITEA_ADMIN}/OpenShift-EaaS-Practice.git
  git push origin --all

  echo "INFO：push_git 執行完成"
}

# 執行 gitops 自動化腳本
execute_gitops(){
  echo "INFO：開始執行 execute_gitops..."
  
  cd /root/OpenShift-EaaS-Practice/
  
  # 執行 bootstrap_gitea.sh 腳本
  .bootstrap/bootstrap_gitea.sh \
    https://${GITEA_REPO}/OpenShift-EaaS-Practice.git \
    ${GITOPS_CLUSTER_TYPE}  \
    ${OCP_ADMIN} \
    ${GIT_REVISION} \
    ${ARGOCD_INSTALL_MODE} \
    ${GITEA_ADMIN} \
    ${GITEA_PASSWORD}

  echo "INFO：execute_gitops 執行完成"
  echo "INFO：operators 建置完畢，請於 ArgoCD UI 確認部署完成"    
}

main
