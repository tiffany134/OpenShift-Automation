domain=ocp.ansible.lab

# export KUBECONFIG
export KUBECONFIG=/root/ocp4/auth/kubeconfig

# infra node
oc apply -f mcp_infra.yaml

for i in {01..03} ;
do
        oc label nodes infra$i.$domain node-role.kubernetes.io/infra='';
        oc label nodes infra$i.$domain node-role.kubernetes.io/worker-;
        oc adm taint node infra$i.$domain \
        node-role.kubernetes.io/infra:NoSchedule \
        node-role.kubernetes.io/infra:NoExecute;
done

# Ingress pod to infra node
oc patch ingresscontroller/default -n  openshift-ingress-operator  --type=merge -p '{"spec":{"replicas":3,"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"key": "node-role.kubernetes.io/infra","operator": "Exists"}]}}}'

# Moving monitoring components to infra node
oc apply -f cm_cluster-monitoring-config.yaml
