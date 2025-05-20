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

  # OCP FQDN
  export OCP_DOMAIN=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")

  # gitea route url 及帳號密碼
  export GITEA_URL=${GITEA_ADMIN}:${GITEA_PASSWORD}@gitea-gitea.apps.${OCP_DOMAIN}
  export GITEA_REPO=gitea-gitea.apps.${OCP_DOMAIN}/${GITEA_ADMIN}

  # 預設 storageclass
  export DEFAULT_SC=$(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class == "true")]}{.metadata.name}{"\n"}{end}')

}

# 創建 gitops repo
create_git_repo(){

  # 使用 gitea api 創建 repo
  curl -k -X POST "https://${GITEA_URL}/api/v1/admin/users/pocuser/repos" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "OpenShift-EaaS-Practice",
       "default_branch": "main",
       "private": false,
       "auto_init": false 
     }'
}

# 更新 gitops repo 內的參數
update_gitops_content(){
  
  tar xzvf /root/install_source/gitops.tar -C /root
    
  # 將 git repo 替換成 gitea repo
  grep -rl --null 'github.com\/CCChou' OpenShift-EaaS-Practice/ | \
    xargs -0 sed -i "s#github.com/CCChou#${GITEA_REPO}#g"

  # 將 quay.io 替換成 mirror quay
  grep -rl --null 'quay.io' OpenShift-EaaS-Practice/ | \
    xargs -0 sed -i "s#quay.io#${REGISTRY_URL}#g"
  
  # 變更預設 storageclass
  yq eval '.patches[].patch |= sub("value: \"gp3-csi\"", "value: \"\(env(${DEFAULT_SC}))\"")' \
    /root/OpenShift-EaaS-Practice/clusters/${GITOPS_CLUSTER_TYPE}/overlays/loki-configuration/kustomization.yaml
}

# 將本地 git 推送至 gitea
push_git(){

  cd /root/OpenShift-EaaS-Practice/

  git config --global http.sslVerify false
  git config --global user.email "${GITEA_ADMIN}@example.com"
  git config --global user.name "${GITEA_ADMIN}"

  git remote set-url origin https://${GITEA_REPO}/OpenShift-EaaS-Practice.git
  git push origin --all

}

# 執行 gitops 自動化腳本
execute_gitops(){
  
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

  echo "=== operators 建置完畢，請於 ArgoCD UI 確認部署完成 ==="
  
}

main