# /bin/bash
if [ "$#" -ne 4 ]; then
    echo "usage: ./get-tool.sh [openshift version] [rhel major version] [cpu architecture] [helm latest version] [mirror registry latest version]"
    exit 1
fi

unset $1
unset $2
unset $3
unset $4
unset $5

export OCP_RELEASE=$1
export RHEL_VERSION=$2
export ARCHITECTURE=$3
export HELM_VERSION=$4
export MIRROR_REGISTRY_VERSION=$5

# 下載 openshift client
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-client-linux-${ARCHITECTURE}-${RHEL_VERSION}-${OCP_RELEASE}.tar.gz

# 下載 openshift install
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/openshift-install-${RHEL_VERSION}-${ARCHITECTURE}.tar.gz

# 下載 oc mirror
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_RELEASE}/oc-mirror.${RHEL_VERSION}.tar.gz

# 下載 butane
wget https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane-${ARCHITECTURE}

# 下載 latest helm
wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/helm/${HELM_VERSION}/helm-linux-${ARCHITECTURE}.tar.gz

# 下載 latest mirror registry
wget https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/mirror-registry/${MIRROR_REGISTRY_VERSION}/mirror-registry.tar.gz