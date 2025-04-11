# OpenShift Automation

在符合最多數化場景下執行 OpenShift 的 Day1 跟 Day2 安裝配置自動化

| 版號 | 發布日期 | 異動內容 |
| :----: | :----: | :---- |
| v0.1 | 2025/03/28 | 首次更新 |


## Related Projects
- [Ansible Role for OpenShift Day1 Setup](https://github.com/CCChou/ocp_bastion_installer)
- [OpenShift Environment as a Service](https://github.com/CCChou/OpenShift-EaaS-Practice)


## 安裝流程

### 事前準備流程

在進入客戶環境前的準備事項

0. 本機環境準備一台可對外連線的 RHEL 主機

1. 將 OpenShift Automation github repo fork 到自己的 repo 中
   - 連線至 [OpenShift-Automation Repo](https://github.com/CCChou/OCP-Automation.git)，並點選 fork
   ![Fork01](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork01.png?raw=true)

   - 確認名稱沒有衝突後點選 Create fork
   ![Fork02](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork02.png?raw=true)

   - 成功 Fork 後可看到以下畫面，左上為目前 fork 出來的 repo 名稱以及關聯的源頭，右側 Code 點擊後則可以取得此 repo 後續用於 clone 的連結
   ![Fork03](https://github.com/CCChou/OpenShift-Automation/blob/main/images/fork03.png?raw=true)

2. 註冊目前使用的本地機器
   ```bash
   subscription-manager register
   ```
   ```bash
   Username: ['你的 Red Hat 帳戶']
   Password: ['你的 Red Hat 帳戶密碼']
   ```

3. 在本地機器上安裝 ansible-builder 
   ```bash
   sudo dnf install --enablerepo=ansible-automation-platform-2.5-for-rhel-9-x86_64-rpms ansible-navigator
   ```

4. 使用 ansible-builder 建立 execution environment 鏡像
   - 創建存放檔案用的資料夾
     ``` bash
     mkdir ['自創路徑'] && cd  ['自創路徑']
     ```
   - 將 execution-environment.yml 下載到這個資料夾
     ```bash
     wget https://raw.githubusercontent.com/CCChou/OpenShift-Automation/refs/heads/main/ansible/execution-environment.yml
     ```
   - 建構 ee(execution-environment) 容器鏡像
     ```bash
     ansible-builder build -v3 -f execution-environment.yml -t ['你的 ee 映像檔名稱']
     ```
5. 使用 podman 指令將前一步驟建立好的 ee 鏡像轉成 tar 檔
   ```bash
   podman save -o ['包起來的 tar 檔名稱'].tar ['你的 ee 映像檔名稱']
   ```

6. 下載所需的 rpm 包，並將其存成 tar 檔 (作業系統: RHEL 9.4)
   - 將 AAP 所需的 rpm 包下載到指定目錄
     ```bash
     dnf install --enablerepo=ansible-automation-platform-2.4-for-rhel-9-x86_64-rpms --downloadonly --installroot=/root/rpm/rootdir --downloaddir=/root/rpm/downloadonly/aap-9.4 --releasever=9.4 ansible-navigator
     ```
   - 將下載的 rpm 包打包成 tar 檔
     ```bash
     tar xf ansible-navigator-rpm-9.4-min.tar -C /root/rpm/downloadonly/aap-9.4
     ```
     ![下載 rpm 包範例](https://github.com/CCChou/OpenShift-Automation/blob/main/images/rpm_sample.png)

7. 下載所需的基本指令工具(CLI)和系統檔案
   ```bash
   wget ['url of the specific version'] 
   ```
  * 指令工具及系統檔案清單:
    - [openshift-client](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
    - [openshift-install](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/)
    - [Butane config transpiler CLI](https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/)
    - [helm v3](https://mirror.openshift.com/pub/openshift-v4/clients/helm/)
    - [mirror-registry](https://mirror.openshift.com/pub/openshift-v4/clients/mirror-registry/)
    - [oc mirror plugin](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/)
    - [RHEL 開機用光碟 (REHL OS)](https://access.redhat.com/downloads/content/rhel)
    - [CoreOS 開機用光碟(rhcos)](https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/)
    > 請注意，點擊下載連結進入上方提供的網址後，點選版本後即可下載。另外，openshift-install 與 openshift-client 需要為相同版號，且需要留意處理器架構是否與您的處理器相同。

8. 使用 oc-mirror 指令將所需的鏡像拉取到本機
   1. 放 oc-mirror 可執行程式至指定目錄
      ```bash
      tar -zxvf oc-mirror.tar.gz -C /usr/local/bin/
      ```
      ```bash
      chmod a+x /usr/local/bin/oc-mirror
      ``` 
   2. 配置允許可以 mirror 的鏡像憑證 Configuring credentials that allow images to be mirrored
      - 到 [Red Hat Hybrid Cloud Console](https://console.redhat.com/openshift/downloads) 下載 pull secret 並儲存成 json 文件 
        ```bash
        cat /root/pull-secret > ~/.docker/config.json
        ```
   3. 取得常用 Operator 之資訊
      - 取得 operator 頻道資訊
        ```bash
        # version 請選擇要安裝的 OpenShift 版本
        oc-mirror list operators --catalogs --version=4.XX
        ```
        ```bash
        # image tag 請選擇要安裝的 OpenShift 版本
        oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX > package.out
        ```
      - 在上述匯出的 package.out 檔中檢查並你要下載的 operator
        ```bash
        # image tag 請選擇要安裝的 OpenShift 版本
        oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX --package=['operator 名稱']
        ```
      - 找指定的頻道內的 package 版本
        ```bash
        # image tag 請選擇要安裝的 OpenShift 版本
        oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:v4.XX --package=['operator 名稱'] --channel=['operator 頻道']
        ```
       > [Red Hat OpenShift Container Platform Operator Update Information Checker](https://access.redhat.com/labs/ocpouic/?upgrade_path=4.16%20to%204.18)
   4. 創建 imageSetConfiguration yaml 配置檔
       ```yaml
       apiVersion: mirror.openshift.io/v1alpha2
       kind: ImageSetConfiguration
       archiveSize: 4
       storageConfig:                                                      
         local:
           path: /root/install/ocp416/metadata
       mirror:
         platform:
           channels:
           - name: fast-4.16
             minVersion: 4.16.3
             maxVersion: 4.16.3
           graph: true
         operators:
         - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.16
           packages:
           - name: cluster-logging
             channels:
             - name: stable-5.9
               minVersion: 5.9.4
               maxVersion: 5.9.4
           - name: loki-operator 
             channels:
             - name: stable-5.9
               minVersion: 5.9.4
               maxVersion: 5.9.4
         additionalImages:
         - name: registry.redhat.io/rhel8/rhel-guest-image:latest
         - name: registry.redhat.io/rhel9/rhel-guest-image:latest
       ```
       > 完整請參考 ( yaml > imageset-config.yaml)，請注意頻道和鏡像標籤
   5. 將鏡像從特定的 ImageSetConfiguration 中同步到磁碟
      - 執行 oc mirror 指令將指定 ImageSetConfiguration 中的鏡像同步到磁碟上
        ```bash
        oc-mirror --config=./imageset-config.yaml file://.
        ```
      - 驗證是否已建鏡像 .tar 檔案
        ```bash
        ls

        mirror_seq1_000000.tar
        ```
   * 鏡像清單:
     - [openshift images]:
       - registry.redhat.io/ubi8/ubi:latest
       - registry.redhat.io/ubi9/ubi:latest
       - registry.redhat.io/rhel8/rhel-guest-image:latest
       - registry.redhat.io/rhel9/rhel-guest-image:latest
     - [operator images]: 
       - Virtualization
         - kubevirt-hyperconverged
         - mtv-operator
         - kubernetes-nmstate-operator
         - netobserv-operator
         - cluster-observability-operator
         - cluster-logging
         - loki-operator
         - tempo-product
         - opentelemetry-product
       - Storage
         - trident-operator
         - local-storage-operator
       - Day 2 Ops
         - node-healthcheck-operator
         - node-maintenance-operator
         - self-node-remediation
         - cincinnati-operator
         - openshift-gitops-operator
         - advanced-cluster-management
         - multicluster-engine
    - [additional images]: 
       - quay.io/stevewu/net-tools:latest
       - quay.io/containerdisks/fedora:latest
       - quay.io/containerdisks/centos:7-2009
       - quay.io/containerdisks/centos-stream:8
       - quay.io/containerdisks/centos-stream:9
       - docker.io/library/postgres:latest
       - docker.io/gitea/gitea:1.21.7
       - [nfs-csi](https://github.com/kubernetes-csi/csi-driver-nfs)
         - image: registry.k8s.io/sig-storage/csi-resizer:v1.13.1
         - image: registry.k8s.io/sig-storage/csi-provisioner:v5.2.0
         - image: registry.k8s.io/sig-storage/csi-snapshotter:v8.2.0
         - image: registry.k8s.io/sig-storage/livenessprobe:v2.15.0
         - image: registry.k8s.io/sig-storage/nfsplugin:v4.11.0
         - image: registry.k8s.io/sig-storage/snapshot-controller:v8.2.0

9. 使用 git clone 將你 fork 的 OpenShift Automation git repo 拉取下來 (URL 可參考步驟一)
   ```bash
   git clone [Forked Git URL]
   ```

10. 依客戶環境需求修改 OpenShift Automation 內的配置 (調整 role > ocp_bastion_installer > default > main.yml 內的配置)
    ```yaml
    ---
    online: false

    # compact or standard mode
    mode: compact

    # 依個人需求啟動或關閉防火牆與 SELinux 等服務與功能
    firewalld_disable: true
    selinux_disable: true 
    
    # 啟用或停用 DNS配置、網卡(NIC)名稱、DNS 上游伺服器位址
    dns_configure: true
    interface: ens33
    dns_upstream: 8.8.8.8
    
    # 是否 DNS 檢查
    dns_check: true
    dns_ip: 172.20.11.50
    
    # 是否啟用負載平衡配置
    haproxy_configure: true
    
    # 鏡像庫配置
    registry_configure: false
    mirrorRegistryDir: /root/install_source/mirror-registry.tar.gz
    quayRoot: /mirror-registry
    quayStorage: /mirror-registry/storage
    registryPassword: P@ssw0rd
    
    # OCP 相關配置
    # 定義叢集名稱
    clusterName: ocp4
    # 定義叢集基礎域名
    baseDomain: demo.lab
    # 定義資源檔案之絕對路徑: 如公鑰、OCP 所需指令壓縮檔位置等
    sshKeyDir: /root/.ssh/id_rsa.pub
    ocpInstallDir: /root/install_source/openshift-install-rhel9-amd64.tar.gz
    ocpClientDir: /root/install_source/openshift-client-linux-amd64-rhel9-4.16.26.tar.gz
    # 連線安裝所需之 pull-secret 位置
    pullSecretDir: /root/install_source/pull-secret.txt
    
    # 從磁碟到鏡像的同步
    mirror: false
    ocmirrorSource: /root/install_source/oc-mirror.rhel9.tar.gz
    imageSetFile: /root/install_source
    reponame: ocp416
    
    # 節點的基本設定 (將不需要的節點註解掉)
    bastion:
      name: bastion
      ip: 172.20.11.50
    bootstrap:
      name: bootstrap
      ip: 172.20.11.60
    master:
    - name: master01
      ip: 172.20.11.51
    - name: master02
      ip: 172.20.11.52
    - name: master03
      ip: 172.20.11.53
    infra:
    - name: infra01
      ip: 172.20.11.54
    - name: infra02
      ip: 172.20.11.55
    - name: infra03
      ip: 172.20.11.56
    worker: 
    - name: worker01
      ip: 172.20.11.57
    - name: worker02
      ip: 172.20.11.58
    - name: worker03
      ip: 172.20.11.59
    ```

11. 將所有準備好的資源都 tar 起來準備放入客戶離線環境
    * tar checkt list (tar包清單):
      - [x] ansible-navigator
      - [x] ee.tar
      - [x] git (調整配置後)
        - gitops
        - roles
        - scripts
      - [x] image
        - nfs
        - gitea
      - [x] mirror_seq
      - [x] qcow2
      - [x] ISO
        - RHEL OS
        - rhcos
      - [x] CLI tools
        - OpenShift command-line interface (oc)
        - Helm 3
        - Butane config transpiler CLI
      - [x] OpenShift installation
        - OpenShift for x86_64 Installer
      - [x] OpenShift disconnected installation tools
        - mirror registry for Red Hat OpenShift (mirror-registry)
        - OpenShift Client (oc) mirror plugin (oc-mirror)

### 離線安裝流程

0. Mount DVD/image 掛光碟到機器上
   ```bash
   mount /dev/sr0 /mnt
   
   vim /etc/yum.repos.d/local.repo
   
   [BaseOS]
   name = BaseOS
   baseurl = file:///mnt/BaseOS
   gpgcheck = 0
   enabled = 1
   
   [AppStream]
   name = AppStream
   baseurl = file:///mnt/AppStream
   gpgcheck = 0
   enabled = 1
   ```

1. 安裝 KVM 建立一個 RHEL Bastion server
   1. 請確定已於本地 OS 下載欲安裝的虛擬機之 ISO 檔
   2. 按照下方指令下載所需要之 RPM 套件
      ```bash
      dnf install libvirt qemu-kvm virt-install virt-manager virt-viewer -y 
      ```
   3. 啟動 libvirtd 服務
      ```bash 
      systemctl enable --now libvirtd
      ```
   4. 檢查 libvirtd 狀態
      ```bash
      systemctl status libvirtd 
      ```
   5. 配置橋接網路
      - 請執行下方指令並記錄欲使用之實體網卡之資訊 (i.e. MAC address, ipv4 address, GW...)
        ```bash 
        ip a 
        ```
      - 移除網卡
        ```bash
        nmcli con delete ['nic profile name'] 
        ```
      - 新增橋接網卡
        ```bash
        nmcli con add con-name ['name of bridge'] type bridge ifname ['name of bridge'] ipv4.address ['ipv4 address of the nic you deleted'] ipv4.gateway ['gateway of the nic you deleted'] ipv4.dns ['ipv4 address of OCP bastion'] ipv4.method manual 
        ```
        > i.e. nmcli con add con-name *br0* type bridge ifname *br0* ipv4.address *172.22.331.100* ipv4.gateway *172.22.331.10* ipv4.dns *172.22.331.100* ipv4.method manual 
      - 新增橋接網卡的 slave
        ```bash
        nmcli con add con-name ['name of slave'] ifname ['name of the removed nic'] master ['name of bridge'] type bridge-slave autoconnect yes 
        ```
        > i.e. nmcli con add con-name *br0-slave* ifname *ens23* master *br0* type bridge-slave autoconnect yes
      - 請執行下方指令，並確認橋接網卡與已移除之網卡的 MAC 地址相同
        ```bash
        ip a 
        ```
   6. 開啟 KVM 介面
      ``` 
      virt-manager 
      ```
   7. 點左上角帶有螢幕的按鈕，並選擇第一個選項後進下一步
      ![啟動 kvm](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-vii-start.png)
   8. 下一步要選擇安裝作業系統用的映像檔，但必須先新增 ISO 所在的路徑作為 pool。請點選 Browse 按鈕，你將會看見 Locate ISO media volume 視窗。點選左下角的加號按鈕，於彈出的視窗中為 pool 命名並選擇 ISO 存放的位置後，即可進入下一步
      ![建立 pool](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool%26iso_1.png)
      ![選擇 ISO](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool%26iso_2.png)
      ![確認位置後進入下一步](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-viii-pool&iso_3.png?raw=true)
   9. 選擇記憶體與核心數。順利完成安裝的最低規格為 8 核心、16384 MB 的記憶體
      ![選擇資源配置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-ix-cpu&core.png?raw=true)
   10. 創建虛擬機儲存空間。最低規格不得低於 80 GB﹔若你有另外創建的存儲空間，請於第二個選項設定與配置
       ![選擇儲存配置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-x-disk-storage.png?raw=true)
   11. 最後，請檢視您的虛擬機設定，並將網路選項設定為橋接裝置，並輸入其名稱。按下完成按鈕進入安裝程序
       ![設定橋接裝置](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xi-config_check&nic.png?raw=true)
   12. 啟動剛剛建立的虛擬機，然後點擊左上角的燈泡圖示。選擇「開機選項」，並調整開機設備順序。請點擊 SATA CDROM1 方框，並將其設為優先順序
       ![啟動虛擬機](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xii-boot_order.png?raw=true)
   13. 啟動虛擬機後，您可以按照一般流程安裝 RHEL
       ![安裝 RHEL](https://github.com/CCChou/OpenShift-Automation/blob/main/images/kvm-xiii-rhel_installation.png?raw=true)

2. 解開所有準備好的 tar 包
   ```bash
   tar zxvf ansible-navigator-rpm-9.4-min.tar -C ['解 tar 之路徑']
   ```

3. 安裝所有 rpm 包
   ```bash
   yum localinstall ansible-navigator-rpm-9.4/* --allowerasing 
   ```

4. 於 bastion 產生 ssh-key，並設定免密登入
   ```bash
   ssh-keygen
   ```
   ```bash
   ssh-copy-id root@['bastion ip'] 
   ```
5. 從 tar 檔中載入容器映像檔到 Podman 的本地鏡像庫
   ```bash
   podman load -i ['包起來的 ee tar 檔名稱'].tar
   ```
   > 參考事前準備工作第 5 步 'podman save -o ['包起來的 tar 檔名稱'].tar ['你的 ee 映像檔名稱']' tar 檔名稱

6. 創建 Ansible Inventory
  #TODO 從範本調整
   ```bash
   vim inventory
   
   ['bastion fqdn']=['bastion ip']
   ```
   Example: ( role > inventory )
   ```
   bastion.ocp.ansible.lab ansible_host=172.20.11.120
   ```

7. 創建 install.yml playbook
  #TODO 從範本調整
   Example: ( role > install.yml )
   ```yaml
   - hosts: all
     remote_user: root
     roles:
     - ocp_bastion_installer
   ```

8. 使用 ansible 運行自動化設定配置腳本 (roles > ocp_bastion_installer > tasks > main.yml)
   ```bash
   ansible-navigator run --eei ['ee image name'] -i inventory -mstdout install.yml
   ```
   1. 設定 bastion 機
   2. 設定 DNS 服務
      - 提供主機名稱解析服務
   3. 將 HAproxy 設定為負載平衡器
      - 分流 API 與應用程式流量
   4. 安裝 mirror registry
      - 安裝連線鏡像倉儲服務
   5. 設定 OpenShift 安裝檔
      1. 建立 httpd 服務器和 net-tool 工具
         -  架設網頁服務與網路排錯工具
      2. 檢查並解開 openshift-install 指令和 oc 指令
         - 準備核心指令工具使用
      3. 建立安裝目錄並設定 install config 配置內容
         - 建立安裝目錄與設定檔
           - install config 包含內容:
             - [x] pull secret: mirro
             - [x] ssh key: id_rsa.pub </root/.ssh/id_rsa.pub>
             - [x] CA: rootCA.pem </['the path installed registry'/quay-rootCA/rootCA.pem]>
      4. 產生 ignition 檔案
         - 產出節點啟動引導設定
      5. 將產生的 ignition 檔案匯入 httpd 服務器給予對應權限
         - 匯入設定檔，並更動其存取權限為 644
      6. 把 operator 檔案上傳到 registry
         - 上傳 Operators 至私人倉儲
      7. 節點的網路配置設定
         - 設定節點網路，讓節點被解析成功

9. 透過 curl 的方式呼叫 coreos-installer 執行 coreos install 指令
   ```bash
   # The command below will be automatically executed after executing curl 以下指令在 curl 執行後會自行執行
   # coreos-installer install /dev/sda -I http://['bastion ip']:8080/['bootstrap/master/worker'].ign --insecure-ignition -n
   curl http://['bastion ip']:8080/['bootstrap/master/worker'].sh|bash

   # 完成後重啟主機
   init 0 or poweroff
   ```
   > 若節點為虛擬機，請記得於開機前退出映像檔

10. 匯出 kubeconfig 進行連線
    ```bash
    export KUBECONFIG=/root/ocp4/auth/kubeconfig 
    ```
    > 請注意，kubeconfig 檔案的位置可能會因您建立 ocp4 目錄的位置而有所不同。
    > 請留意此動作需於 bastion 機上執行!

11. 檢查節點健康狀況，並根據安裝架構決定是否要通過 csr
   - 標準架構: 需要 csr approve
     ```bash
     oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
     ```
   - 三節點架構: 不需要 csr approve，因為 worker 會被加入 master

### 安裝後配置流程

1. 設定身分認證並刪除 kubeadmin 用戶
   ```bash
   # 執行 script 設置 OpenShift authentication
   sh script/authentication/authentication.sh
   ```

2. 關閉預設 catalog source
   ```bash
   sh script/disable-marketplace.sh
   ```     

3. 設定對應的 CSI 儲存介面
   - nfs csi as example (以 nfs csi 為例):
     - 外接存儲會依照需求有所不同與額外設定，請參照[此處](<https://github.com/kubernetes-csi/csi-driver-nfs/tree/master?tab=readme-ov-file>)

4. 根據安裝架構設定 infra 節點配置
   - standard architecture (標準架構): 需要上 taint，有可能日誌監控等重要服務必須上在這邊
     ```bash
     # 執行 script 設置 infra node 及 monitoring components
     # sh script/infra/infra.sh <clusterName>.<baseDomain> standard
     sh script/infra/infra.sh ocp.ansible.lab standard
     ```
   - Compact Nodes architecture (三節點架構):
     ```bash
     # 執行 script 設置 monitoring components
     # sh script/infra/infra.sh <clusterName>.<baseDomain> compact
     sh script/infra/infra.sh ocp.ansible.lab compact
     ```
    
5. Install gitea as a GitOps source repository (安裝 gitea 做為 GitOps 來源庫)
   ```bash
   sh gitea.sh
   ```

6. Import the EaaS git repo and run the corresponding Operator environment installation (匯入 EaaS git repo 並執行對應的 Operator 環境安裝)
