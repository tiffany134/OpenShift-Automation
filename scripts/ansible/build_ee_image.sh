# /bin/bash

unset $1
unset $2
unset $3
unset $4

export REGISTRY_USERNAME=$1
export REGISTRY_PASSWORD=$2
export EE_DIR=$(echo "${3:-eeimage}")
export EE_IMAGE_NAME=$(echo "${4:-eeimage}")
export VERSION_DATE=$(date +'%Y%m%d')

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