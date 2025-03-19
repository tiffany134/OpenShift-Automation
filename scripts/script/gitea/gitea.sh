REGISTRY=bastion.ocp.ansible.lab:8443

# export KUBECONFIG
export KUBECONFIG=/root/ocp4/auth/kubeconfig

export REGISTRY=$REGISTRY
 
envsubst < create-gitea.yaml |oc apply -f -
envsubst < postgresql.yaml |oc apply -f -

#要再改個
oc create sa gitea-sa
oc adm policy add-scc-to-user anyuid -z gitea-sa