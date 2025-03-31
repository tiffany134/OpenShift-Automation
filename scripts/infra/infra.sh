#!/bin/bash

# sh infra.sh <clusterName>.<baseDomain> <mode>
# mode: 
# - standard: 叢集含有infra節點時
# - compact:  叢集沒有infra節點，即compact mode 或 3+2 節點

# 以下為執行shell範例
# sh infra.sh ocp.ansible.lab compact


#domain=ocp.ansible.lab
domain=$1

# 設定 KUBECONFIG 環境變數
export KUBECONFIG=/root/ocp4/auth/kubeconfig

if [ "$2" == "standard" ]; then
# standard mode 時執行以下動作

    # 設定infra node mcp
    oc apply -f mcp_infra.yaml

    # 將 infra node role 改為 infra
    for i in {01..03}; do
        oc label nodes infra$i.$domain node-role.kubernetes.io/infra='';
        oc label nodes infra$i.$domain node-role.kubernetes.io/worker-;
        oc adm taint node infra$i.$domain \
        node-role.kubernetes.io/infra:NoSchedule \
        node-role.kubernetes.io/infra:NoExecute;
    done

    # 設定 Ingress pod to infra node
    oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas":3,"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}}'

    # Moving monitoring components to infra node 並設定 PV
    oc apply -f cm_cluster-monitoring-config-$2.yaml

elif [ "$2" == "compact" ]; then
# compact mode 時執行以下動作

    # monitoring components 設定 PV
    oc apply -f cm_cluster-monitoring-config-$2.yaml

else

    echo "Usage: $0 {standard|compact}"
    exit 1

fi
