#!/bin/bash

export BAK_DIR="/etc/yum.repos.d/bak"

# Mount DVD/image 掛光碟到機器上
mount /dev/sr0 /mnt

# 備份原有 repo
mkdir -p "$BAK_DIR"
mv "/etc/yum.repos.d"/*.repo "$BAK_DIR"/ 2> /dev/null

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
