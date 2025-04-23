#!/bin/bash
config_file="prep_config.conf"

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
  env_prep
  git_clone
  build_ee_image
  download_ansible
  get_tool
  untar_oc_mirror
}

# 準備基本環境資訊
env_prep(){

  dnf install --enablerepo=${AAP_REPO} ansible-navigator

  # 定義需要檢查/創建的目錄列表（可以自行替換或擴展）
  CREATE_DIRS=(
    "/root/install_file"
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
            echo "創建失敗" > &2  # 將錯誤輸出到 stderr
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

  git clone https://github.com/CCChou/OpenShift-EaaS-Practice.git ${GITOPS_DIR}

}

# 創建自動化的 ee 鏡像並封裝成 tar 檔
build_ee_image(){
  if [[ "$CUSTOM_EE" = "true" ]]; then
    echo "創建客製化 ee 並打包..."
      
    # 創建 ee image 創建路徑
    mkdir ${EE_DIR} && cd ${EE_DIR}
      
    # 創建 ee image
    ansible-builder build -v3 -f ${EE_YAML_PATH} -t ${EE_IMAGE_NAME}
  
    # 將 ee image 包成 tar 檔
    podman save -o /root/install_file/${EE_IMAGE_NAME}-${VERSION_DATE}.tar ${EE_IMAGE_NAME}

  else
    echo "下載 ee 鏡像並打包..."

    # 拉取 ee 鏡像
    podman pull quay.io/rhtw/ee-bas-auto:v1.0
    
    # 將 ee 鏡像包成 tar 檔
    podman save -o /root/install_file/${EE_IMAGE_NAME}-${VERSION_DATE}.tar ee-bas-auto:v1.0
  fi
}

download_ansible(){
  # 下載 AAP rpm
  echo "開始下載 AAP rpm..."
  dnf install --enablerepo="${AAP_REPO}" --downloadonly --installroot=/root/rpm/rootdir --downloaddir="${AAP_DIR}" --releasever="${RHEL_MINOR_VERSION}" ansible-navigator -y

  # 將 AAP RPM 包打包成 tar 檔
  tar cvf /root/install_file/ansible-navigator-rpm-${RHEL_MINOR_VERSION}-min.tar ${AAP_DIR}
}

# 下載安裝所需工具
get_tool(){
  echo "下載安裝工具..."

  # 下載 openshift client
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-client-linux-${ARCHITECTURE}-${RHEL_VERSION}-${OCP_RELEASE}.tar.gz -P /root/install_file
  echo "oc client 下載完成"

  # 下載 openshift install
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-install-${RHEL_VERSION}-${ARCHITECTURE}.tar.gz -P /root/install_file
  echo "oc install 下載完成"

  # 下載 oc mirror
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/oc-mirror.${RHEL_VERSION}.tar.gz -P /root/install_file
  echo "oc mirror 下載完成"

  # 下載 butane
  wget https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane-${ARCHITECTURE} -P /root/install_file
  echo "butane 下載完成"

  # 下載 latest helm
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/helm/${HELM_VERSION}/helm-linux-${ARCHITECTURE}.tar.gz -P /root/install_file
  echo "butane 下載完成"

  # 下載 latest mirror registry
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz -P /root/install_file
  echo "mirror registry 下載完成"
}

untar_oc_mirror(){

  # 將 oc-mirror 指令解開使用
  tar -zxvf /root/install_file/oc-mirror.tar.gz -C /usr/local/bin/

  chmod a+x /usr/local/bin/oc-mirror

  cp /root/Openshift-Automation/yaml/imageset-config.yaml /root/install/ocp418
}

main
