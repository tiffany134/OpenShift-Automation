#!/bin/bash

# 以下為執行shell範例
# sh authentication.sh


# 設定 KUBECONFIG 環境變數
export KUBECONFIG=/root/ocp4/auth/kubeconfig

# 建立 htpasswd 檔案來儲存使用者帳號與密碼資訊  
# - `-c` 建立新檔案 (若已存在，會覆蓋)  
# - `-B` 使用 bcrypt 加密密碼  
# - `-b` 直接從命令列提供使用者名稱與密碼 (非互動模式)
# 以下範例為建立ocpadmin帳號，密碼為P@ssw0rdocp
# htpasswd -c -B -b users.htpasswd ocpadmin P@ssw0rdocp

# 新增或更新使用者帳號與密碼
# 以下範例為批次建立 20 個使用者帳號 (user-01 ~ user-20)，密碼與帳號相同 
# for i in {01..20} ; do htpasswd -B -b users.htpasswd user-$i user-$i; done

# 建立一個名為 htpass-secret 的 Secret 來儲存 htpasswd 檔案，讓 OpenShift 用於使用者驗證   
# oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config  


# 建立一個名為 htpass-secret 的 Secret 來儲存 htpasswd 檔案，帳密為ocpadmin P@ssw0rdocp
oc apply -f secret_htpasswd.yaml


# 將資源套用至預設 OAuth 配置以新增identity provider。
oc apply -f oauth.yaml

# 賦予 ocpadmin 帳號 cluster-admin role
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin

# 刪除 kubeadmin 
oc delete secret kubeadmin -n kube-system