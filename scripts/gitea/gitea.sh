#!/bin/bash

# sh gitea.sh
# sh gitea.sh <REGISTRY>/<reponame>

# 以下為執行shell範例
# ImageContentSourcePolicy將docker.io指向至mirror registry
# sh gitea.sh

# 指定images registry
# sh gitea.sh bastion.ocp.ansible.lab:8443/ocp416


#REGISTRY=bastion.ocp.ansible.lab:8443
REGISTRY="${1:-docker.io}"

# export KUBECONFIG
export KUBECONFIG=/root/ocp4/auth/kubeconfig

export REGISTRY=$REGISTRY
export GITEA_VERSION=1.21.7
 
envsubst < create-gitea.yaml |oc apply -f -
envsubst < postgresql.yaml |oc apply -f -

# 建立 gitea 權限
oc create sa gitea-sa
oc adm policy add-scc-to-user anyuid -z gitea-sa