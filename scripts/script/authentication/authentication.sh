domain=ocp.ansible.lab

# export KUBECONFIG
export KUBECONFIG=/root/ocp4/auth/kubeconfig


# htpasswd identity provider
# htpasswd -c -B -b users.htpasswd ocpadmin P@ssw0rdocp
# for i in {01..20} ; do htpasswd -B -b users.htpasswd user-$i user-$i; done
# oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config
oc apply -f secret_htpasswd.yaml
oc apply -f oauth.yaml
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin

# delete kubeadmin 
# oc delete secret kubeadmin -n kube-system