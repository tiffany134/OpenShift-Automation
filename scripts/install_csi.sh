#!/bin/bash

# nfs-csi
nfs-csi(){

    # 配置NFS
    NFS_SC_DIR="/mnt/nfs"    
    NFS_CIDR=$(hostname -I | awk '{print $1}' | awk -F. '{print $1"."$2".0.0/16"}')    

    mkdir -p $NFS_SC_DIR
    chmod 777 $NFS_SC_DIR
    echo "$NFS_SC_DIR $NFS_CIDR(rw,sync,no_root_squash,no_subtree_check,no_wdelay)" | tee /etc/exports
    systemctl restart nfs-server rpcbind
    systemctl enable nfs-server rpcbind nfs-mountd

    CSI_TYPE=$1
    
    # 創建 nfs namespace
    echo "創建 ${NFS_NAMESPACE}..."
    oc create namespace "${NFS_NAMESPACE}" || echo " ${NFS_NAMESPACE} 已存在。"

    # 創建 ServiceAccount 和 RBAC 權限
    envsubst < ${YAML_DIR}/$CSI_TYPE/rbac.yaml |oc apply -f -
    
    # 創建 csi driver
    envsubst < ${YAML_DIR}/$CSI_TYPE/csi-driver.yaml |oc apply -f -
    
    # 部署 NFS Controller
    if oc get deployment csi-nfs-controller -n "{$NFS_NAMESPACE}" &> /dev/null; then
        echo "NFS Controller 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/$CSI_TYPE/deployment.yaml |oc apply -f -
    fi

    # 部署 NFS Node
    if oc get daemontset csi-nfs-node -n "{$NFS_NAMESPACE}" &> /dev/null; then
        echo "NFS Node Daemon 已存在，跳過部署。"
    else
      envsubst < ${YAML_DIR}/$CSI_TYPE/daemonset.yaml |oc apply -f -
    fi

    # 創建 StorageClass
    envsubst < ${YAML_DIR}/$CSI_TYPE/storageclass.yaml |oc apply -f -

    # 檢查 StorageClass 是否創建成功
    if oc get storageclass ${NFS_STORAGE_CLASS_NAME} &> /dev/null; then
        echo "{$NFS_STORAGE_CLASS_NAME} 配置完成！"
    else
        echo "StorageClass 創建失敗！"
        exit 1
    fi

    # 設置預設 StorageClass
    oc patch storageclass ${NFS_STORAGE_CLASS_NAME} -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
}

# trident csi
trident(){

  # 創建 trident orchestrators crd
  envsubst < ${YAML_DIR}/$CSI_TYPE/tridentorchestrators-crd.yaml |oc apply -f -

  # 創建 trident namespace
  echo "創建 ${TRIDENT_NAMESPACE}..."
  envsubst < ${YAML_DIR}/$CSI_TYPE/namespace.yaml |oc apply -f -

  # 創建部署 bundle
  if oc get deployment trident-operator -n "{$NFS_NAMESPACE}" &> /dev/null; then
      echo "trident operator 已存在，跳過部署。"
  else
    envsubst < ${YAML_DIR}/$CSI_TYPE/deploy-bundle.yaml |oc apply -f -
  fi
  
  # 創建 trident orchestrator
  envsubst < ${YAML_DIR}/$CSI_TYPE/tridentorchestrator.yaml |oc apply -f -

  # 創建 trident backend
  tridentctl create backend -f ${YAML_DIR}/$CSI_TYPE/backend.json -n ${$TRIDENT_NAMESPACE}

  # 創建 StorageClass
  envsubst < ${YAML_DIR}/$CSI_TYPE/storageclass.yaml |oc apply -f -

  # 檢查 StorageClass 是否創建成功
  if oc get storageclass ${TRIDENT_STORAGE_CLASS_NAME} &> /dev/null; then
      echo "${TRIDENT_STORAGE_CLASS_NAME} 配置完成！"
  else
      echo "StorageClass 創建失敗！"
      exit 1
  fi

}

# 主程式入口
case "$1" in
  nfs-csi)
    nfs-csi
    ;;
  trident)
    trident
    ;;
  *)
    echo "用法: $0 {nfs-nsi|trident} [目錄]"
    exit 1
    ;;
esac