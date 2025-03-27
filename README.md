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
   1. Please ensure the ISO for installing virtual machine has been downloaded to your OS (RHEL) 請確定已於本地 OS 下載欲安裝的虛擬機之 ISO 檔
   2. Download the required rpm packages as the command below 按照下方指令下載所需要之 RPM 套件
      ``` dnf install libvirt qemu-kvm virt-install virt-manager virt-viewer -y 
      ```
   3. Enable libvirtd service 啟動 libvirtd 服務
      ``` systemctl enable --now libvirt
      ```
   4. Check the status of libvirtd service 檢查 libvirtd 狀態
      ``` systemctl status libvirtd 
      ```
   5. Configure network bridging 配置橋接網路
      - Please execute the command as below, and record the information of the NiC currently used by your OS (i.e. MAC address, ipv4 address, GW...) 請執行下方指令並記錄欲使用之實體網卡之資訊
        ``` ip a 
        ```
      - Delete the NiC 移除網卡
        ``` nmcli con delete ['nic profile name'] 
        ```
      - Add new network bridge 新增橋接網卡
        ``` nmcli con add con-name ['name of bridge'] type bridge ifname ['name of bridge'] ipv4.address ['ipv4 address of the nic you deleted'] ipv4.gateway ['gateway of the nic you deleted'] ipv4.dns ['ipv4 address of OCP bastion'] ipv4.method manual 
        ```
      >> i.e. nmcli con add con-name *br0* type bridge ifname *br0* ipv4.address *172.22.331.100* ipv4.gateway *172.22.331.10* ipv4.dns *172.22.331.100* ipv4.method manual 
      - Add slave for bridge 新增橋接網卡的 slave
        ``` nmcli con add con-name ['name of slave'] ifname ['name of the removed nic'] master ['name of bridge'] type bridge-slave autoconnect yes 
        ```
      >> i.e. nmcli con add con-name *br0-slave* ifname *ens23* master *br0* type bridge-slave autoconnect yes
      - Ensure MAC address of bridge and removed NiC are identical 請執行下方指令，並確認橋接網卡與已移除之網卡的 MAC 地址相同
        ``` ip a 
        ```
   6. Bring up KVM interface 叫出 KVM 介面
      ``` virt-manager 
      ```
   7. Click the button with monitor icon on the upper-left corner. Pick the first option and forward to next step 點左上角帶有螢幕的按鈕，並選擇第一個選項後進下一步
   8. The following step is to choose the ISO for installing OS, yet the path where the ISO file is located has to be added. Please click the box "Browse" and you may see the "Locate ISO media volume" window. Click the plus icon on the lower-left corner to add a new pool. Name the pool and enter the path where the ISO file is and your are good to move on to the next step. 下一步要選擇安裝作業系統用的映像檔，但必須先新增 ISO 所在的路徑作為 pool。請點選 Browse 按鈕，你將會看見 Locate ISO media volume 視窗。點選左下角的加號按鈕，於彈出的視窗中為 pool 命名並選擇 ISO 存放的位置後，即可進入下一步。
   9. Choose Memory and CPU settings. The minimal requirement for the node should be 16384 MB of Memory, and 8 core of CPUs to properly finish installing OpenShift. 選擇記憶體與核心數。順利完成安裝的最低規格為 8 核心、16384 MB 的記憶體。
   10. Create disk image for VM. The minimal requirements for disk should not be lower than 80 GB; or you had format a disk storage for your VM, you may select the second option to customize. 創建虛擬機存儲空間。最低規格不得低於 80 GB﹔若你有另外創建的存儲空間，請於第二個選項設定與配置。
   11. Finally, you may examine the configuration of your virtual machine, and please set the network selection below as "Bridge device" and enter its name. Click "Finish" button to run the installation process. 最後，請檢視您的虛擬機設定，並將網路選項設定為橋接裝置，並輸入其名稱。按下完成按鈕進入安裝程序。

2. Install ansible-builder on your local machine (在本地機器上安裝 ansible-builder)
``` yum install ansible-core ansible-builder 
```

3. Use ansible-builder to create an ansible execution environment image (使用 ansible-builder 建立 execution environment 鏡像)
```

```

4. Use the podman command to convert the ee image created in the previous step into a tar file (使用 podman 指令將前一步驟建立好的 ee 鏡像轉成 tar 檔)
```
podman save
```

5. Download the required rpm package (下載所需的 rpm 包)
``` dnf install httpd dnsmasq haproxy net-tools policycoreutils-python-utils wget -y 
```
  * rpm checkt list (rpm 包清單):
    - [httpd]: Apache web server used for hosting web content or serving files, sometimes used in disconnected OpenSfhit installations.Apache 網頁伺服器，用於主機網頁內容或提供檔案，有時會在離線的 OpenShift 安裝中使用。
    - [dnsmasq]: Lightweight DNS and DNCP server, often used for name resolution and PXE booting in OpenShift bare metal installs. 輕量級的 DNS 與 DHCP 伺服器，常用於 OpenShift 裸機安裝中的名稱解析與 PXE 開機。
    - [haproxy]: High-performance TCP/HTTP load balancer, crucial for routing OpenShift API, ingress, and machine config traffic in disconnected setups.高效能的 TCP/HTTP 負載平衡器，在離線部署中負責轉送 OpenShift API、ingress 及 machine config 的流量。
    - [net-tools]: Provides basic network utilities (like *ifconfig*, *netstat*) for debugging and verifying network configuration during installation and troubleshooting. 提供基本的網路工具 (如 *ifconfig*、*netstat*) 用於安裝過程中與故障排除時的網路設定驗證與除錯。
    - [policycoreutils-python-utils]: SELinux tools in Python for managing and troubleshooting SELinux contexts and policies required by OpenShift services. 以 Python 撰寫的 SELinux 工具，協助管理與除錯 OpenShift 所需的 SELinux 內容與政策。
    - [wget]: Command line tool to download files over HTTP/S and FTP; used for fetching release files or RPMs in offline installs. 命令列工具，可透過 HTTP/S 或 FTP 下載檔案，常用於離線安裝中取得 release 檔案或 rpm 套件


6. Download the basic command(CLI tools) required (下載所需的基本指令工具(CLI))
``` wget ['url of the specific version'] 
```
  * CLI checkt list (指令工具清單):
    - openshift-client: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ ***Please choose a version 請選擇版號***
    - openshift-install: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ ***Please choose a verion 請選擇版號***
>> Please note that the download links for openshift-install and openshift-client will be available after selecting the desired version on the provided website. Additionally, make sure that both openshift-install and openshift-client are of the same version, and pay attention to whether the processor architecture matches your system's processor. 請注意，openshift-install 與 openshift-client 的下載連結會在進入上方提供的網址後，點選版本後即可下載。另外，openshift-install 與 openshift-client 需要為相同版號，且需要留意處理器架構是否與您的處理器相同。

7. Use the oc-mirror command to pull the required image to the local machine (使用 oc-mirror 指令將所需的鏡像拉取到本機)
   1. Get info of essential operator 取得常用 Operator 之資訊
     - Get operator channel info 取得 operator channel 資訊
      ``` podman login -u ['username 使用者名稱'] -p ['password密碼'] registry.redhat.io
      ```
      ```oc-mirror list operaotrs --catalogs --version=4.XX
      ```
      ```oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:4.XX > package.out
      ```
     - Examine and select the operator you wish to download in package.out
      ```oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:4.XX --package=['name of the operator']
      ```
     - Look up the operator package version of specific channel 查找指定的 channel 內的 package version
      ```oc-mirror list operators 
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
    * tar checkt list (tar包清單):
      - openshift-client: openshift-client: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ ***Please choose a version 請選擇版號***
      - openshift-install: openshift-client: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/***Please choose a version 請選擇版號***
      - oc-mirror: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.XX ***Please choose your preferred version 請選擇版號***

### Disconnect installation process (離線安裝流程)

1. Unpack all prepared tar (解開所有準備好的 tar 包)
```  
```

# 解 tar*

2. Install all rpm packages (安裝所有 rpm 包)
```  
```
# 裝 ansible rpm

3. Use ansible to run automated configuration scripts (使用 ansible 運行自動化設定配置腳本)
``` ```
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
     ``` export KUBECONFIG=/root/ocp4/auth/kubeconfig 
     ```
     >> Please note that the location of the kubeconfig file may vary depending on where you created the ocp4 directory. 請注意，kubeconfig 檔案的位置可能會因您建立 ocp4 目錄的位置而有所不同。
  6. Check the node health and decide whether to approve csr based on the installation architecture (檢查節點健康狀況，並根據安裝架構決定是否要通過 csr)
     ```haproxy = true
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
