# OpenShift Automation

The Goals is to automate the day1 and day2 operations as much as possible.

## Reference
- [Ansible Role for OpenShift Day1 Setup](https://github.com/CCChou/ocp_bastion_installer)
- [OpenShift Environment as a Service](https://github.com/CCChou/OpenShift-EaaS-Practice)


## Installation process (安裝流程)

### Preparation process (事前準備流程)

Preparations before entering the customer environment
在進入客戶環境前的準備事項

0. Fork the OpenShift-Automation github repo into your own repo (將 OpenShift Automation github repo fork 到自己的 repo 中)

1. Install KVM to create a RHEL Bastion server (安裝 KVM 建立一個 RHEL Bastion server)

2. Install ansible-builder on your local machine (在本地機器上安裝 ansible-builder)
```
yum install ansible-builder
```

3. Use ansible-builder to create an ansible execution environment image (使用 ansible-builder 建立 execution environment 鏡像)
```

```

4. Use the podman command to convert the ee image created in the previous step into a tar file (使用 podman 指令將前一步驟建立好的 ee 鏡像轉成 tar 檔)
```
podman save
```

5. Download the required rpm package (下載所需的 rpm 包)
```

```
  * rpm checkt list (rpm 包清單):
    - [ ]: 
    - [ ]: 
    - [ ]: 

6. Download the basic command(CLI tools) required (下載所需的基本指令工具(CLI))
```

```
  * CLI checkt list (指令工具清單):
    - [ ]: 
    - [ ]: 
    - [ ]: 


7. Use the oc-mirror command to pull the required image to the local machine (使用 oc-mirror 指令將所需的鏡像拉取到本機)
```

```
  * image checkt list (鏡像清單):
    - [ ]: openshift images
    - [ ]: operator images
    - [ ]: additional images
    

8. Use git clone to pull the OpenShift Automation git repo (使用 git clone 將 OpenShift Automation 的 git repo 拉取下來)
```

```

9. Modify the configuration in OpenShift Automation according to customer environment requirements (依客戶環境需求修改 OpenShift Automation 內的配置)
```

```

10. Tar all the prepared resources and ready for upload them into the customer's offline environment (將所有準備好的資源都 tar 起來準備放入客戶離線環境)
```

```
  * tar checkt list (tar包清單):
    - [ ]: 
    - [ ]: 
    - [ ]: 

### Disconnect installation process (離線安裝流程)

1. Unpack all prepared tar (解開所有準備好的 tar 包)
```

```

2. Install all rpm packages (安裝所有 rpm 包)
```

```

3. Use ansible to run automated configuration scripts (使用 ansible 運行自動化設定配置腳本)
```

```
  1. Setting up bastion server (設定 bastion 機)
     ```

     ```
  2. Setting up DNS server (設定 DNS 服務)
     ```

     ```
  3. Setting up HAproxy as Load Balancer (將 HAproxy 設定為負載平衡器)
     ```

     ```
  4. Install mirror registry (安裝 mirror registry)
     ```

     ```
  5. Setting up the OpenShift installation file (設定 OpenShift 安裝檔)
     ```

     ```
    1. Setting up httpd server and net-tool tool (建立 httpd 服務器和 net-tool 工具)
       ```

       ```
    2. Check and unpack the openshift-install command and the oc command (檢查並解開 openshift-install 指令和 oc 指令)
       ```

       ```
    3. Create an installation directory and configure the install config configuration content (建立安裝目錄並設定 install config 配置內容)
       ```

       ```
       * Content should be included in install config (install config 包含內容):
         - [ ]: pull secret
         - [ ]: ssh key
         - [ ]: CA
    4. Generate ignition file (產生 ignition 檔案)
       ```

       ```
    5. Import the generated ignition file into the httpd server and grant corresponding permissions (將產生的 ignition 檔案匯入 httpd 服務器給予對應權限)
       ```

       ```
  4. Call coreos-installer via curl to execute the coreos install command (透過 curl 的方式呼叫 coreos-installer 執行 coreos install 指令)
     ```

     ```
  5. Export kubeconfig for connection operation (匯出 kubeconfig 進行連線)
     ```

     ```
  6. Check the node health and decide whether to approve csr based on the installation architecture (檢查節點健康狀況，並根據安裝架構決定是否要通過 csr)
     ```

     ```
     * standard architecture (標準架構):
        ```

        ```
     * Compact Nodes architecture (三節點架構):
        ```

        ```
  7. Setting up OpenShift authentication and delete the kubeadmin user (設定身分認證並刪除 kubeadmin 用戶)
     ```

     ```
  8. Set the corresponding CSI storage interface (設定對應的 CSI 儲存介面)
     * nfs csi as example (以 nfs csi 為例):
  9. Set the infra node configuration according to the installation architecture (根據安裝架構設定 infra 節點配置)
     * standard architecture (標準架構):
        ```

        ```
     * Compact Nodes architecture (三節點架構):
        ```

        ```
  10. Install gitea as a GitOps source repository (安裝 gitea 做為 GitOps 來源庫)
     ```

     ```
  11. Import the EaaS git repo and run the corresponding Operator environment installation (匯入 EaaS git repo 並執行對應的 Operator 環境安裝)
