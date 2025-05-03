#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$SCRIPT_DIR/prep_config.conf"

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
  backup_local_yum
  env_prep
  git_clone
  build_ee_image
  download_ansible
  get_tools
  configre_aap_config
  configure_aap_main
  untar_oc_mirror
}

# 確保本地 yum 源
backup_local_yum() {
    
  export REPO_DIR="/etc/yum.repos.d"
  export BAK_DIR="$REPO_DIR/bak"

  # 將原有 repo 文件移至備份目錄
  mkdir -p "$BAK_DIR"
  mv "$REPO_DIR"/*.repo "$BAK_DIR"/ 2>/dev/null

}

# 準備基本環境資訊
env_prep(){

  # 定義需要檢查/創建的目錄列表（可以自行替換或擴展）
  CREATE_DIRS=(
    "/root/install_source"
    "/root/.docker"
    "/root/install/ocp418"
  )

  # 使用迴圈創建所有目錄
  for dir in "${CREATE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "目錄 $dir 已存在，跳過創建"
    else
        echo "目錄 $dir 不存在，正在創建..."
        mkdir -p "$dir"
        # 檢查 mkdir 是否成功
        if [ $? -eq 0 ]; then
            echo "創建成功"
        else
            echo "創建失敗" >&2  # 將錯誤輸出到 stderr
            exit 1                # 失敗時退出腳本
        fi
    fi
  done
    
  # 將 pull-secret 匯到 config.json
  cat /root/pull-secret | jq > /root/.docker/config.json
}

# 拉取自動化所需 repo
git_clone(){

  git clone https://github.com/CCChou/ocp_bastion_installer.git ${OCP_INSTALLER_DIR}

  mkdir ${GITOPS_DIR}
  git clone https://github.com/CCChou/OpenShift-EaaS-Practice.git ${GITOPS_DIR}
  tar cvf /root/install_source/gitops.tar ${GITOPS_DIR}

}

# 創建自動化的 ee 鏡像並封裝成 tar 檔
build_ee_image(){
  # 拉取 ee 鏡像
  podman pull quay.io/rhtw/ee-bas-auto:v1.0
    
  # 將 ee 鏡像包成 tar 檔
  podman save -o /root/install_source/${EE_IMAGE_NAME}-v1.tar ee-bas-auto:v1.0
}

# 下載 Ansible naigator 所需 rpm
download_ansible(){
  yum repolist
  # 下載 AAP rpm
  echo "開始下載 AAP rpm..."
  dnf install --enablerepo="${AAP_REPO}" --downloadonly --installroot=/root/rpm/rootdir --downloaddir="${AAP_DIR}" --releasever="${RHEL_MINOR_VERSION}" ansible-navigator -y

  # 將 AAP RPM 包打包成 tar 檔
  tar cvf /root/install_source/ansible-navigator-rpm-${RHEL_MINOR_VERSION}-min.tar ${AAP_DIR}
}

# 下載安裝所需工具
get_tools(){
  echo "下載安裝工具..."

  # 下載 openshift client
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-client-linux-${ARCHITECTURE}-${RHEL_VERSION}-${OCP_RELEASE}.tar.gz -P /root/install_source
  echo "oc client 下載完成"

  # 下載 openshift install
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-install-${RHEL_VERSION}-${ARCHITECTURE}.tar.gz -P /root/install_source
  echo "oc install 下載完成"

  # 下載 oc mirror
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/oc-mirror.${RHEL_VERSION}.tar.gz -P /root/install_source
  echo "oc mirror 下載完成"

  # 下載 butane
  wget https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane-${ARCHITECTURE} -P /root/install_source
  echo "butane 下載完成"

  # 下載 latest helm
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/helm/${HELM_VERSION}/helm-linux-${ARCHITECTURE}.tar.gz -P /root/install_source
  echo "butane 下載完成"

  # 下載 latest mirror registry
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz -P /root/install_source
  echo "mirror registry 下載完成"
}

# 配置 AAP inventory 資訊
configre_aap_config(){

# 設定 app inventory
cat << EOF > ${OCP_INSTALLER_DIR}/../inventory
bastion.${CLUSTER_DOMAIN}.${BASE_DOMAIN} ansible_host=${BASTION_IP}
EOF

}

# 配置 AAP main.yaml
configure_aap_main(){
  cp ${OCP_INSTALLER_DIR}/defaults/main.yml ${OCP_INSTALLER_DIR}/defaults/main.yml.bak

cat << EOF > ${OCP_INSTALLER_DIR}/defaults/main.yml
---
online: false

# compact or standard mode
mode: ${INSTALL_MODE}

# 依個人需求啟動或關閉防火牆與 SELinux 等服務與功能
firewalld_disable: true
selinux_disable: true 

# 啟用或停用 DNS配置、網卡(NIC)名稱、DNS 上游伺服器位址
dns_configure: true
interface: ens33
dns_upstream: 8.8.8.8

# 是否 DNS 檢查
dns_check: true
dns_ip: ${BASTION_IP}

# 是否啟用負載平衡配置
haproxy_configure: true

# 鏡像庫配置
registry_configure: true
mirrorRegistryDir: /root/install_source/mirror-registry.tar.gz
quayRoot: /mirror-registry
quayStorage: /mirror-registry/storage
registryPassword: ${REGISTRY_PASSWORD}

# OCP 相關配置
# 定義叢集名稱
clusterName: ${CLUSTER_DOMAIN}
# 定義叢集基礎域名
baseDomain: ${BASE_DOMAIN}
# 定義資源檔案之絕對路徑: 如公鑰、OCP 所需指令壓縮檔位置等
sshKeyDir: /root/.ssh/id_rsa.pub
ocpInstallDir: /root/install_source/openshift-install-${RHEL_VERSION}-${ARCHITECTURE}.tar.gz
ocpClientDir: /root/install_source/openshift-client-linux-${ARCHITECTURE}-${RHEL_VERSION}-${OCP_RELEASE}.tar.gz
# 連線安裝所需之 pull-secret 位置
pullSecretDir: /root/install_source/pull-secret.txt

# 從磁碟到鏡像的同步
mirror: true
ocmirrorSource: /root/install_source/oc-mirror.${RHEL_VERSION}.tar.gz
imageSetFile: /root/install_source
reponame: ocp418

# 節點的基本設定 (將不需要的節點註解掉)
bastion:
  name: bastion
  ip: ${BASTION_IP}
bootstrap:
  name: bootstrap
  ip: ${BOOTSTRAP_IP}
master:
- name: master01
  ip: ${MASTER01_IP}
- name: master02
  ip: ${MASTER02_IP}
- name: master03
  ip: ${MASTER03_IP}
# standard mode nodes
infra:
- name: infra01
  ip: ${INFRA01_IP}
- name: infra02
  ip: ${INFRA02_IP}
- name: infra03
  ip: ${INFRA03_IP}
worker: 
- name: worker01
  ip: ${WORKER01_IP}
- name: worker02
  ip: ${WORKER02_IP}
- name: worker03
  ip: ${WORKER03_IP}
EOF
}

# 解開 oc mirror 指令
untar_oc_mirror(){

  # 將 oc-mirror 指令解開使用
  tar -zxvf /root/install_source/oc-mirror.rhel9.tar.gz -C /usr/bin/

  chmod a+x /usr/bin/oc-mirror

  cp /root/OpenShift-Automation/yaml/imageset-config.yaml /root/install/ocp418

  echo "=== prep_script 腳本執行完成，請調整 /root/install/ocp418/imageset-config.yaml 配置後執行下個步驟 ==="
}

main
