#!/bin/bash

# nfs_csi
nfs_csi(){
    echo "INFO：開始執行 nfs_csi..."

    # 配置NFS
    NFS_SC_DIR="/mnt/nfs"    
    NFS_CIDR=$(hostname -I | awk '{print $1}' | awk -F. '{print $1"."$2".0.0/16"}')    

    mkdir -p $NFS_SC_DIR
    chmod 777 $NFS_SC_DIR
    echo "$NFS_SC_DIR $NFS_CIDR(rw,sync,no_root_squash,no_subtree_check,no_wdelay)" | tee /etc/exports
    systemctl restart nfs-server rpcbind
    systemctl enable nfs-server rpcbind nfs-mountd

    CSI_TYPE=$1
    echo ${CSI_TYPE}
    
    # 創建 nfs namespace
    echo "INFO：創建 ${NFS_NAMESPACE}..."
    oc create namespace "${NFS_NAMESPACE}" || echo " ${NFS_NAMESPACE} 已存在。"

    # 創建 ServiceAccount 和 RBAC 權限
    envsubst < ${YAML_DIR}/${CSI_TYPE}/rbac.yaml |oc apply -f -
    
    # 創建 csi driver
    envsubst < ${YAML_DIR}/${CSI_TYPE}/csi-driver.yaml |oc apply -f -
    
    # 部署 NFS Controller
    if oc get deployment csi-nfs-controller -n "{$NFS_NAMESPACE}" &> /dev/null; then
        echo "INFO：NFS Controller 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/${CSI_TYPE}/deployment.yaml |oc apply -f -
    fi

    # 部署 NFS Node
    if oc get daemontset csi-nfs-node -n "{$NFS_NAMESPACE}" &> /dev/null; then
        echo "INFO：NFS Node Daemon 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/${CSI_TYPE}/daemonset.yaml |oc apply -f -
    fi

    # 創建 StorageClass
    envsubst < ${YAML_DIR}/${CSI_TYPE}/storageclass.yaml |oc apply -f -

    # 設置預設 StorageClass
    oc patch storageclass ${NFS_STORAGE_CLASS_NAME} -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

    echo "INFO：nfs_csi 執行完成"
}

# trident csi
trident(){
  echo "INFO：開始執行 trident..."
  
  CSI_TYPE=$1

  TRIDENT_TAR_FILE="/root/install_source/trident-installer-25.02.1.tar.gz"
  TRIDENT_TARGET_DIR="/root/install_source/"

  # 檢查文件是否存在，存在便解 tar
  if [ -f "$TRIDENT_TAR_FILE" ]; then
    echo "INFO：檢查到文件存在，開始解 tar..."
    tar -zxvf "$TRIDENT_TAR_FILE" -C "$TRIDENT_TARGET_DIR"
    echo "INFO：解 tar 完成！"
  else
    echo "ERROR：文件 $TRIDENT_TAR_FILE 不存在。"
    exit 1 
  fi

  # 創建 trident orchestrators crd
  envsubst < ${YAML_DIR}/$CSI_TYPE/tridentorchestrators-crd.yaml |oc apply -f -

  # 創建 trident namespace
  echo "INFO：創建 ${TRIDENT_NAMESPACE}..."
  envsubst < ${YAML_DIR}/$CSI_TYPE/namespace.yaml |oc apply -f -

  # 創建部署 bundle
  if oc get deployment trident-operator -n "{$NFS_NAMESPACE}" &> /dev/null; then
      echo "INFO：trident operator 已存在，跳過部署。"
  else
    envsubst < ${YAML_DIR}/$CSI_TYPE/deploy-bundle.yaml |oc apply -f -
  fi
  
  # 創建 trident orchestrator
  if oc get tridentorchestrator trident -n "{$NFS_NAMESPACE}" &> /dev/null; then
      echo "INFO：tridentorchestrator 已存在，跳過部署。"
  else
    envsubst < ${YAML_DIR}/$CSI_TYPE/tridentorchestrator.yaml |oc apply -f -
  fi

  # 讓 tridentctl CLI 可以執行
  cp -raf /root/install_source/trident-installer/tridentctl /usr/bin
  chmod a+x /usr/bin/tridentctl

  # 創建 trident backend
  tridentctl create backend -f ${YAML_DIR}/$CSI_TYPE/backend.json -n ${$TRIDENT_NAMESPACE}

  # 創建 StorageClass
  envsubst < ${YAML_DIR}/$CSI_TYPE/storageclass.yaml |oc apply -f -
  
  # 創建 volumesnapshotclass
  oc apply -f ${YAML_DIR}/$CSI_TYPE/volumesnapshotclass.yaml

  echo "INFO：trident 執行完成"
}

# 主程式入口
case "$1" in
  nfs-csi)
    nfs_csi
    ;;
  trident)
    trident
    ;;
  *)
    echo "INFO：用法: $0 {nfs-nsi|trident} [目錄]"
    exit 1
    ;;
esac