#!/bin/bash

# 清除前四個參數的環境變數
unset $1
unset $2
unset $3
unset $4

# 設定參數（可以在執行腳本時傳入）
export BASTION_IP=$1
export TARBALL_PATH=$(echo "${2:-/root/install_source/ansible-navigator-rpm-9.4-min.tar}")
export TAR_DEST_PATH=$(echo "${3:-/root/install_source/ansible-navigator-rpm-9.4}")
export EE_IMAGE_TAR=$(echo "${4:-eeimage}")
export EE_IMAGE_NAME=$(basename "$EE_IMAGE_TAR" .tar)

# Mount DVD/image 掛光碟到機器上
mount /dev/sr0 /mnt

# 建立 yum repository
cat << EOF > /etc/yum.repos.d/dvd.repo
[BaseOS]
name=BaseOS
baseurl=file:///mnt/BaseOS
enabled=1
gpgcheck=0

[AppStream]
name=AppStream
baseurl=file:///mnt/AppStream
enabled=1
gpgcheck=0
EOF

# 解開所有準備好的 tar 包
mkdir -p ${TAR_DEST_PATH}
tar xvf ${TARBALL_PATH} -C ${TAR_DEST_PATH}

# 安裝所有 rpm 包
yum localinstall -y ${TAR_DEST_PATH}/* --allowerasing

# 於 bastion 產生 ssh-key，並設定免密登入
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< y
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 從 tar 檔中載入容器映像檔到 Podman 的本地鏡像庫
podman load -i ${EE_IMAGE_TAR}

# 使用 ansible 運行自動化設定配置腳本
ansible-navigator run \
  --eei ${EE_IMAGE_NAME} \
  -i ../../roles/inventory \
  -m stdout ../../roles/install.yml
