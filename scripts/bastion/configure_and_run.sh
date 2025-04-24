#!/bin/bash

# 清除前三個參數的環境變數
unset $1
unset $2
unset $3
unset $4

# 設定參數（可以在執行腳本時傳入）
export TARBALL_PATH="${1:-/root/install_source/ansible-navigator-rpm-9.4-min.tar}"
export TAR_DEST_PATH="${2:-/root/install_source/ansible-navigator-rpm-9.4}"
export EE_IMAGE_TAR="${3:-/root/install_source/eeimage-v1.tar}"
export EE_IMAGE_NAME="${4:-quay.io/rhtw/ee-bas-auto:v1.0}"

# 確認參數
echo "[INFO] TARBALL_PATH   = $TARBALL_PATH"
echo "[INFO] TAR_DEST_PATH  = $TAR_DEST_PATH"
echo "[INFO] EE_IMAGE_TAR   = $EE_IMAGE_TAR"
echo "[INFO] EE_IMAGE_NAME  = $EE_IMAGE_NAME"

# 解開所有準備好的 tar 包
mkdir -p ${TAR_DEST_PATH}
tar xvf ${TARBALL_PATH} -C ${TAR_DEST_PATH} --strip-components=1

# 安裝所有 rpm 包
yum localinstall -y ${TAR_DEST_PATH}/* --allowerasing --skip-broken

# 於 bastion 產生 ssh-key，並設定免密登入
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 從 tar 檔中載入容器映像檔到 Podman 的本地鏡像庫
podman load -i ${EE_IMAGE_TAR}

# 使用 ansible 運行自動化設定配置腳本
ansible-navigator run --eei ${EE_IMAGE_NAME} --pp missing -i /root/OpenShift-Automation/roles/inventory -m stdout /root/OpenShift-Automation/roles/install.yml
