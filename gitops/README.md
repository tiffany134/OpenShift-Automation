# gitops 腳本單獨執行方式

## 執行腳本
```bash
./bootstrap.sh [your gitops repo] [your cluster name] [admin username] [pin]
``` 

## 參數說明
```bash
export gitops_repo=$1 #<your newly created repo>
export cluster_name=$2 #<your cluster name, default hub>
export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
export platform_base_domain=${cluster_base_domain#*.}
export admin_username=$3  #<your admin username, default admin>
export pin=$4 #<your target revision>
```