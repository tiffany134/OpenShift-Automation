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
       ``` 
       dnf install libvirt qemu-kvm virt-install virt-manager virt-viewer -y 
       ```
    3. Enable libvirtd service 啟動 libvirtd 服務
       ``` 
       systemctl enable --now libvirt
       ```
    4. Check the status of libvirtd service 檢查 libvirtd 狀態
       ``` 
       systemctl status libvirtd 
       ```
    5. Configure network bridging 配置橋接網路
      - Please execute the command as below, and record the information of the NiC currently used by your OS (i.e. MAC address, ipv4 address, GW...) 請執行下方指令並記錄欲使用之實體網卡之資訊
        ``` 
        ip a 
        ```
      - Delete the NiC 移除網卡
        ``` 
        nmcli con delete ['nic profile name'] 
        ```
      - Add new network bridge 新增橋接網卡
        ``` 
        nmcli con add con-name ['name of bridge'] type bridge ifname ['name of bridge'] ipv4.address ['ipv4 address of the nic you deleted'] ipv4.gateway ['gateway of the nic you deleted'] ipv4.dns ['ipv4 address of OCP bastion'] ipv4.method manual 
        ```
        > i.e. nmcli con add con-name *br0* type bridge ifname *br0* ipv4.address *172.22.331.100* ipv4.gateway *172.22.331.10* ipv4.dns *172.22.331.100* ipv4.method manual 
      - Add slave for bridge 新增橋接網卡的 slave
        ``` 
        nmcli con add con-name ['name of slave'] ifname ['name of the removed nic'] master ['name of bridge'] type bridge-slave autoconnect yes 
        ```
        > i.e. nmcli con add con-name *br0-slave* ifname *ens23* master *br0* type bridge-slave autoconnect yes
      - Ensure MAC address of bridge and removed NiC are identical 請執行下方指令，並確認橋接網卡與已移除之網卡的 MAC 地址相同
        ``` 
        ip a 
        ```
    6. Bring up KVM interface 叫出 KVM 介面
       ``` 
       virt-manager 
       ```
    7. Click the button with monitor icon on the upper-left corner. Pick the first option and forward to next step 點左上角帶有螢幕的按鈕，並選擇第一個選項後進下一步
    8. The following step is to choose the ISO for installing OS, yet the path where the ISO file is located has to be added. Please click the box "Browse" and you may see the "Locate ISO media volume" window. Click the plus icon on the lower-left corner to add a new pool. Name the pool and enter the path where the ISO file is and your are good to move on to the next step. 下一步要選擇安裝作業系統用的映像檔，但必須先新增 ISO 所在的路徑作為 pool。請點選 Browse 按鈕，你將會看見 Locate ISO media volume 視窗。點選左下角的加號按鈕，於彈出的視窗中為 pool 命名並選擇 ISO 存放的位置後，即可進入下一步。
    9. Choose Memory and CPU settings. The minimal requirement for the node should be 16384 MB of Memory, and 8 core of CPUs to properly finish installing OpenShift. 選擇記憶體與核心數。順利完成安裝的最低規格為 8 核心、16384 MB 的記憶體。
    10. Create disk image for VM. The minimal requirements for disk should not be lower than 80 GB; or you had format a disk storage for your VM, you may select the second option to customize. 創建虛擬機存儲空間。最低規格不得低於 80 GB﹔若你有另外創建的存儲空間，請於第二個選項設定與配置。
    11. Finally, you may examine the configuration of your virtual machine, and please set the network selection below as "Bridge device" and enter its name. Click "Finish" button to run the installation process. 最後，請檢視您的虛擬機設定，並將網路選項設定為橋接裝置，並輸入其名稱。按下完成按鈕進入安裝程序。

2. Register your local machine with your Red Hat partner account 註冊目前使用的的機器 
   ```
   subscription-manager register
   ```
   ```
   Username: ['your Red Hat partner account']
   Password: 
   ```

3. Install ansible-builder on your local machine 在本地機器上安裝 ansible-builder 
   ```
   sudo dnf install --enablerepo=ansible-automation-platform-2.5-for-rhel-9-x86_64-rpms ansible-navigator
   ```

4. Use ansible-builder to create an ansible execution environment image (使用 ansible-builder 建立 execution environment 鏡像)

   - Create a directory for storing documents 創建存放檔案用的資料夾
     ``` 
     mkdir ['preferred directory 自創路徑'] && cd  ['preferred directory 自創路徑']
     ```
   - Download execution-environment.yml file to this directory 將 execution-environment.yml 下載到這個資料夾
     ```
     wget https://raw.githubusercontent.com/CCChou/OpenShift-Automation/refs/heads/main/ansibleexecution-environment.yml
     ```
   - Create ee container image 建構 ee 容器鏡像
     ``` 
     ansible-builder build -v3 -f execution-environment.yml -t ['your ee image name 你的 ee 映像檔名稱']
     ```
5. Use the podman command to convert the ee image created in the previous step into a tar file (使用 podman 指令將前一步驟建立好的 ee 鏡像轉成 tar 檔)
   ```
   podman save -o ['tar file name 包起來的 tar 檔名稱'].tar ['your ee image name 你的 ee 映像檔名稱']
   ```

6. Download the required rpm package (下載所需的 rpm 包)
   ```
   tar xf ansible-navigator-rpm-9.4-min.tar -C ['Create directory to store rpm 請自建存放該 rpm 包的資料夾   ']
   ```
  * rpm checklist RPM 包清單 
    - ansible-builder-3.0.1-1.el9ap.noarch.rpm
    - ansible-navigator-3.4.1-1.el9ap.noarch.rpm
    - ansible-runner-2.3.6-1.el9ap.noarch.rpm
    - git-core-2.43.5-1.el9_4.x86_64.rpm
    - python3-3.9.18-3.el9_4.6.x86_64.rpm
    - python3-ansible-runner-2.3.6-1.el9ap.noarch.rpm
    - python3-attrs-21.4.0-2.el9pc.noarch.rpm
    - python3-bindep-2.10.2-3.el9ap.noarch.rpm
    - python3-cffi-1.15.0-3.el9ap.x86_64.rpm
    - python3-daemon-2.3.0-4.el9ap.noarch.rpm
    - python3-distro-1.6.0-3.el9pc.noarch.rpm
    - python3-docutils-0.16-4.el9ap.noarch.rpm
    - python3-importlib-metadata-6.0.1-1.el9ap.noarch.rpm
    - python3-jinja2-3.1.4-1.el9ap.noarch.rpm
    - python3-jsonschema-4.16.0-1.el9ap.noarch.rpm
    - python3-libs-3.9.18-3.el9_4.6.x86_64.rpm
    - python3-lockfile-0.12.2-1.el9ap.noarch.rpm
    - python3-markupsafe-2.1.0-3.el9ap.x86_64.rpm
    - python3-onigurumacffi-1.1.0-3.el9ap.x86_64.rpm
    - python3-packaging-21.3-2.el9ap.noarch.rpm
    - python3-parsley-1.3-2.el9pc.noarch.rpm
    - python3-pbr-5.8.1-2.el9ap.noarch.rpm
    - python3-pexpect-4.8.0-7.el9.noarch.rpm
    - python3-pip-wheel-21.2.3-8.el9.noarch.rpm
    - python3-ptyprocess-0.6.0-12.el9.noarch.rpm
    - python3-pycparser-2.21-2.el9pc.noarch.rpm
    - python3-pyparsing-3.0.9-1.el9ap.noarch.rpm
    - python3-pyrsistent-0.17.3-8.el9.x86_64.rpm
    - python3-pyyaml-5.4.1-6.el9.x86_64.rpm
    - python3-requirements-parser-0.2.0-4.el9ap.noarch.rpm
    - python3-setuptools-53.0.0-12.el9_4.1.noarch.rpm
    - python3-setuptools-wheel-53.0.0-12.el9_4.1.noarch.rpm
    - python3-six-1.16.0-2.el9pc.noarch.rpm
    - python3-zipp-3.19.2-1.el9ap.noarch.rpm

7. Download the basic command(CLI tools) required (下載所需的基本指令工具(CLI))
   ``` 
   wget ['url of the specific version'] 
   ```
  * CLI checkt list (指令工具清單):
    - openshift-client: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ ***Please choose a version 請選擇版號***
    - openshift-install: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ ***Please choose a verion 請選擇版號***
    - virtctl: Virtualization > Overview in the OpenShift Container Platform web console. Click the Download virtctl link on the upper right corner of the page and download
    > Please note that the download links for openshift-install and openshift-client will be available after selecting the desired version on the provided website. Additionally, make sure that both openshift-install and openshift-client are of the same version, and pay attention to whether the processor architecture matches your system's processor. 請注意，openshift-install 與 openshift-client 的下載連結會在進入上方提供的網址後，點選版本後即可下載。另外，openshift-install 與 openshift-client 需要為相同版號，且需要留意處理器架構是否與您的處理器相同。

8. Use the oc-mirror command to pull the required image to the local machine (使用 oc-mirror 指令將所需的鏡像拉取到本機)
    1. 放oc-mirror可執行程式至指定目錄
       ``` 
       tar -zxvf oc-mirror.tar.gz -C /usr/local/bin/
       ``` 
    2. Configuring credentials that allow images to be mirrored

       Download pull secret and save the file https://console.redhat.com/openshift/downloads
       ```
       cat /root/pull-secret > ~/.docker/config.json
       ```
    3. Get info of essential operator 取得常用 Operator 之資訊
       - Get operator channel info 取得 operator channel 資訊
         ```
         oc-mirror list operaotrs --catalogs --version=4.XX
         ```
         ```
         oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:4.XX > package.out
         ```
       - Examine and select the operator you wish to download in package.out
          ```
          oc-mirror list operators --catalog=registry.redhat.io/redhat/redhat-operator-index:4.XX --package=['name of the operator']
          ```
       - Look up the operator package version of specific channel 查找指定的 channel 內的 package version
         ```
         oc-mirror list operators 
         ```
       > Red Hat OpenShift Container Platform Operator Update Information Checker
https://access.redhat.com/labs/ocpouic/?upgrade_path=4.16%20to%204.18
    4. Creating the imageset configuration
       ```
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
    5. Mirroring from mirror to disk
    
       Run the oc mirror command to mirror the images from the specified image set configuration to disk:
       ```
       oc-mirror --config=./imageset-config.yaml file://.
       ```
       Verify that an image set .tar file was created:
       ```
       ls
       mirror_seq1_000000.tar
       ```
  * image check list (鏡像清單):
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
         - tempo-operator
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
         - advanecd-cluster-management 
    - [additional images]: 
         - VDDK
         - quay.io/stevewu/net-tools:latest
         - quay.io/containerdisks/fedora:latest
         - quay.io/containerdisks/centos:7-2009
         - quay.io/containerdisks/centos-stream:8
         - quay.io/containerdisks/centos-stream:9
         - docker.io/library/postgres:latest
         - docker.io/gitea/gitea:1.21.7
         - nfs-csi https://github.com/kubernetes-csi/csi-driver-nfs
           - image: registry.k8s.io/sig-storage/csi-resizer:v1.13.1
           - image: registry.k8s.io/sig-storage/csi-provisioner:v5.2.0
           - image: registry.k8s.io/sig-storage/csi-snapshotter:v8.2.0
           - image: registry.k8s.io/sig-storage/livenessprobe:v2.15.0
           - image: registry.k8s.io/sig-storage/nfsplugin:v4.11.0
           - image: registry.k8s.io/sig-storage/snapshot-controller:v8.2.0

9. Use git clone to pull the OpenShift Automation git repo (使用 git clone 將 OpenShift Automation 的 git repo 拉取下來)
   ```
   git clone https://github.com/CCChou/OpenShift-Automation.git
   ```

10. Modify the configuration in OpenShift Automation according to customer environment requirements (依客戶環境需求修改 OpenShift Automation 內的配置)
 (default>main.yml)
    ```
    ---
    # Enable or disable the firewall and SELinux according to your demand 依個人需求啟動或關閉防火牆與     SELinux 等服務與功能
    online: true
    firewalld_disable: true
    selinux_disable: true 
    
    # Enable or disable DNS configuration, name of NiC, DNS upstream server 配置的啟用與否、網卡名稱、DNS 上    游伺服器位址
    dns_configure: true
    interface: ens33
    dns_upstream: 8.8.8.8
    
    # DNS check DNS 檢查與否
    dns_check: true
    dns_ip: 172.20.11.50
    
    # LB 負載平衡配置的啟用與否
    haproxy_configure: true
    
    # Registry Configuration 儲存庫配置
    registry_configure: false
    mirrorRegistryDir: /root/install_source/mirror-registry.tar.gz
    quayRoot: /mirror-registry
    quayStorage: /mirror-registry/storage
    registryPassword: P@ssw0rd
    
    # OCP 
    # define the cluster name for cluster 定義叢集名稱
    clusterName: ocp4
    # define the base domain for cluster 定義叢集基礎域名
    baseDomain: demo.lab
    # define the resource files absolute path 定義資源檔案之絕對路徑: 如公鑰、OCP 所需指令壓縮檔位置等
    sshKeyDir: /root/.ssh/id_rsa.pub
    ocpInstallDir: /root/install_source/openshift-install-rhel9-amd64.tar.gz
    ocpClientDir: /root/install_source/openshift-client-linux-amd64-rhel9-4.16.26.tar.gz
    # for online install 連線安裝所需之 pull-secret 位置
    pullSecretDir: /root/install_source/pull-secret.txt
    
    # Mirroring from disk to mirror 從磁碟到鏡像的同步
    mirror: false
    ocmirrorSource: /root/install_source/oc-mirror.rhel9.tar.gz
    imageSetFile: /root/install_source
    reponame: ocp416
    
    # Nodes 以下為節點的基本設定 (若不需要 infra 節點則可註解)
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

11. Tar all the prepared resources and ready for upload them into the customer's offline environment (將所有準備好的資源都 tar 起來準備放入客戶離線環境)
    * tar checkt list (tar包清單):
      - ansible-navigator
      - ee.tar
      - git
        - role (customized 修改後)
        - script
      - image
        - nfs
        - gitea
      - mirror_seq
      - qcow2
      - ISO
        - RHEL OS
        - rhcos
      - CLI tools
        - OpenShift command-line interface (oc)
      - Developer tools
        - Helm 3
      - OpenShift installation
        - OpenShift for x86_64 Installer
      - OpenShift disconnected installation tools
        - mirror registry for Red Hat OpenShift (mirror-registry)
        - OpenShift Client (oc) mirror plugin (oc-mirror)
      - OpenShift installation customization tools
        - Butane config transpiler CLI

### Disconnect installation process (離線安裝流程)

0. Mount DVD/image 掛光碟到機器上
   ```
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

1. Unpack all prepared tar (解開所有準備好的 tar 包)
   ```  
   tar zxvf ansible-navigator-rpm-9.4-min.tar -C ['Target directory to extract tar file 解 tar 之路徑']
   ```

2. Install all rpm packages (安裝所有 rpm 包)
   ``` 
   yum localinstall ansible-navigator-rpm-9.4/* --allowerasing 
   ```

3. 產生 ssh-key 至欲操作 ansible 之主機，並從 tar 檔中載入容器映像檔到 Podman 的本地應像庫
   ```
   ssh-keygen
   ```
   ```
   ssh-copy-id ['username']@['target machine's ip'] 
   ```
   ```
   podman load -i ['tar file name 包起來的 tar 檔名稱'].tar
   ```

4. Create Inventory
   ```
   vim inventory
   
   ['機器 fqdn']=['機器 ip']
   ```

5. Playbook (install.yml)
   ```
   - hosts: all
     remote_user: root
     vars_files:
     - env.yml
     roles:
     - ocp_bastion_installer
   ```

6. Use ansible to run automated configuration scripts (使用 ansible 運行自動化設定配置腳本)
   ``` 
   ansible-navigator run --eei ['ee image name'] -i inventory -mstdout install.yml-i inventory
   ```
  1. Setting up bastion server (設定 bastion 機)
  2. Setting up DNS server (設定 DNS 服務)
     - Provide hostname resolution service提供主機名稱解析服務
  3. Setting up HAproxy as Load Balancer (將 HAproxy 設定為負載平衡器)
     - Distribute API and app traffic 分流 API 與應用程式流量
  4. Install mirror registry (安裝 mirror registry)
     - Deploy offline image registry 安裝連線鏡像倉儲服務
  5. Setting up the OpenShift installation file (設定 OpenShift 安裝檔)
    1. Setting up httpd server and net-tool tool (建立 httpd 服務器和 net-tool 工具)
       -  Provide web and network tools for troubleshooting 架設網頁服務與網路排錯工具
    2. Check and unpack the openshift-install command and the oc command (檢查並解開 openshift-install 指令和 oc 指令)
       - Prepare install and CLI tools 準備核心指令工具使用
    3. Create an installation directory and configure the install config configuration content (建立安裝目錄並設定 install config 配置內容)
       - Create install dir and config 建立安裝目錄與設定檔
         * Content should be included in install config (install config 包含內容):
           - [pull secret]: please download your own pull secret by logging to [this link](<https://console.redhat.com/openshift/create/local>)
           - [ssh key]: id_rsa.pub </root/.ssh/id_rsa.pub>
           - [CA]: rootCA.pem </['the path installed registry'/quay-rootCA/rootCA.pem]>
    4. Generate ignition file (產生 ignition 檔案)
       - Generate boot config for nodes 產出節點啟動引導設定
    5. Import the generated ignition file into the httpd server and grant corresponding permissions (將產生的 ignition 檔案匯入 httpd 服務器給予對應權限)
       - Import config and allow access 匯入設定檔，並更動其存取權限為 644
    6. Mirror-registry 把 operator 檔案上傳到 registry
       - Push Operators to local registry 上傳 Operators 至私人倉儲

  6. Network Configuration Settings for nodes
     - Set up node network to ensure successful domain name resolution 設定節點網路，讓節點被解析成功
  7. Call coreos-installer via curl to execute the coreos install command (透過 curl 的方式呼叫 coreos-installer 執行 coreos install 指令)
     ```
     curl http://['bastion ip']:['port']/['bootstrap/master/worker'].sh

     # The command below will be automatically executed after executing curl 以下指令在 curl 執行後會自行執行
     coreos-installer install /dev/['disk name 磁碟名稱'] -I http://['bastion ip']:['port']/['bootstrap/master/worker'].ign --insecure-ignition -n

     init 0 or poweroff
     ```
     >> If your nodes are installed on VM, please remeber to eject ISO before power-on 若節點為虛擬機，請記得於開機前退出映像檔
9. Export kubeconfig for connection operation (匯出 kubeconfig 進行連線)
     ```
     export KUBECONFIG=/root/ocp4/auth/kubeconfig 
     ```
     >> Please note that the location of the kubeconfig file may vary depending on where you created the ocp4 directory. 請注意，kubeconfig 檔案的位置可能會因您建立 ocp4 目錄的位置而有所不同。
     >> Please note that this action should be executed on bastion! 請留意此動作需於 bastion 機上執行

10. Check the node health and decide whether to approve csr based on the installation architecture (檢查節點健康狀況，並根據安裝架構決定是否要通過 csr)
    * standard architecture (標準架構):
      #說明動作: 需要 csr approve需要 csr approve
      ```
      oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
      ```
    * Compact Nodes architecture (三節點架構):
      - 不需要 csr approve，因為 worker 會被加入 master
11. Setting up OpenShift authentication and delete the kubeadmin user (設定身分認證並刪除 kubeadmin 用戶)
     ```
     htpasswd -c -B -b ['/path/to/user.htpasswd']['username']['password']

     oc create secret generic htpass-secret --from-file=htpasswd=['path_to_users.htpasswd'] -n openshift-config
     
     # Modify oauth.yaml 
     vim oauth.yaml

     apiVersion: config.openshift.io/v1
     kind: OAuth
     metadata:
       name: cluster
     spec:
       identityProviders:
       - name: my_htpasswd_provider
         mappingMethod: claim 
         type: HTPasswd
         htpasswd:
           fileData:
             name: htpass-secret

     # Apply modified oauth.yaml
     oc apply -f </path/to/CR>

     # Attempt to login
     oc login -u ['username'] -p 
     oc whoami

     # Add user to cluster-admin group
     oc adm policy add-cluster-role-to-user cluster-admin ['USERNAME']

     # Remove default user -- kubeadmin & update secret
     htpasswd -D users.htpasswd ['username']
     oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f -
     ```
12. Set the corresponding CSI storage interface (設定對應的 CSI 儲存介面)
     * nfs csi as example (以 nfs csi 為例):
       - 外接存儲會依照需求有所不同與額外設定，請參照[此處](<https://github.com/kubernetes-csi/csi-driver-nfs/tree/master?tab=readme-ov-file>) 
13. Set the infra node configuration according to the installation architecture (根據安裝架構設定 infra 節點配置)
     * standard architecture (標準架構):
       - Need to apply taint, as important services like logging and monitoring may need to run on this node 需要上 taint，有可能日誌監控等重要服務必須上在這邊
     * Compact Nodes architecture (三節點架構):
       - Not applicable 不適用
14. Install gitea as a GitOps source repository (安裝 gitea 做為 GitOps 來源庫)
     ```
     
     ```
15. Import the EaaS git repo and run the corresponding Operator environment installation (匯入 EaaS git repo 並執行對應的 Operator 環境安裝)
