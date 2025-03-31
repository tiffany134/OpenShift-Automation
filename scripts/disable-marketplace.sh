#!/bin/bash

# 以下為執行shell範例
# sh disable-marketplace.sh


# export KUBECONFIG
export KUBECONFIG=/root/ocp4/auth/kubeconfig

# 關閉預設 catalog source
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'