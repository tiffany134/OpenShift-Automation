# /bin/bash

# TODO 參數化

mount /dev/sr0 /mnt

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
tar xvf ansible-navigator-rpm-9.4-min.tar -C  ['解 tar 之路徑']

# 安裝所有 rpm 包
yum localinstall ['解 tar 之路徑']/* --allowerasing

# 於 bastion 產生 ssh-key，並設定免密登入
ssh-keygen
ssh-copy-id root@['bastion ip']

# 從 tar 檔中載入容器映像檔到 Podman 的本地鏡像庫
podman load -i ['包起來的 ee tar 檔名稱'].tar

# 使用 ansible 運行自動化設定配置腳本
ansible-navigator run --eei ${EE_IMAGE_NAME}:${VERSION_DATE} -i ../../roles/inventory -mstdout ../../roles/install.yml