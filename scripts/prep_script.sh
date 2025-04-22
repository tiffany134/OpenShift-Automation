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
  build_ee_image
  download_ansible
  get_tool
}


# 創建自動化的 ee 鏡像並封裝成 tar 檔
build_ee_image(){
  if [[ "$CUSTOM_EE" = "true" ]]; then
    echo "創建客製化 ee 並打包..."

    # 登入 registry.redhat.io
    mkdir ~/.docker
    podman login registry.redhat.io -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} --authfile=~/.docker/config.json
    
    # 創建 ee image 創建路徑
    mkdir ${EE_DIR} && cd ${EE_DIR}
  
    # 取得 ee.yaml 範本
    wget https://raw.githubusercontent.com/CCChou/OpenShift-Automation/refs/heads/main/ansible/execution-environment.yml
  
    # 創建 ee image
    ansible-builder build -v3 -f execution-environment.yml -t ${EE_IMAGE_NAME}
  
    # 將 ee image 包成 tar 檔
    podman save -o ${EE_IMAGE_NAME}-${VERSION_DATE}.tar ${EE_IMAGE_NAME}
  else
    echo "下載 ee 鏡像並打包..."

    # TODO 使用 podman login and pull ee image
    
    # 將 ee image 包成 tar 檔
    podman save -o ${EE_IMAGE_NAME}-${VERSION_DATE}.tar ${EE_IMAGE_NAME}
  fi
}

download_ansible(){
  # 下載 AAP rpm
  echo "開始下載 AAP rpm..."
  dnf install --enablerepo="${AAP_REPO}" --downloadonly --installroot=/root/rpm/rootdir --downloaddir="${AAP_DIR}" --releasever="${RHEL_MINOR_VERSION}" ansible-navigator

  # 將 AAP RPM 包打包成 tar 檔
  tar cvf ansible-navigator-rpm-${RHEL_MINOR_VERSION}-min.tar ${AAP_DIR}

}

# 下載安裝所需工具
get_tool(){
  echo "下載安裝工具..."

  # 下載 openshift client
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-client-linux-${ARCHITECTURE}-${RHEL_VERSION}-${OCP_RELEASE}.tar.gz
  echo "oc client 下載完成"

  # 下載 openshift install
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-install-${RHEL_VERSION}-${ARCHITECTURE}.tar.gz
  echo "oc install 下載完成"

  # 下載 oc mirror
  wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/oc-mirror.${RHEL_VERSION}.tar.gz
  echo "oc mirror 下載完成"

  # 下載 butane
  wget https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane-${ARCHITECTURE}
  echo "butane 下載完成"

  # 下載 latest helm
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/helm/${HELM_VERSION}/helm-linux-${ARCHITECTURE}.tar.gz
  echo "butane 下載完成"

  # 下載 latest mirror registry
  wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz
  echo "mirror registry 下載完成"
}

main