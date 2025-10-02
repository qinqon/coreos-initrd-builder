os := "fcos"

auth_file:= "~/.secrets/pull-secrets.json"

scos_toolbox_img:= "registry.redhat.io/rhel9/support-tools:9.6"
fcos_toolbox_img:= "registry.redhat.io/rhel9/support-tools:9.6"

scos_base_img:= `oc adm release info --image-for=rhel-coreos quay.io/openshift-release-dev/ocp-release:4.20.0-ec.6-x86_64`
fcos_base_img:= "quay.io/fedora/fedora-coreos:42.20250705.3.0"

scos_img:= "quay.io/ellorent/scos"
fcos_img:= "quay.io/ellorent/fcos"

scos_kubevirt_img:= "quay.io/ellorent/scos-kubevirt"
#scos_kubevirt_img:= "quay.io/ellorent/scos-kubevirt"
#scos_kubevirt_img:= "default-route-openshift-image-registry.apps.hypershift.qinqon.corp/hypershift/scos-kubevirt"
fcos_kubevirt_img:= "quay.io/ellorent/fcos-kubevirt"

fcos_os:= "fedora-coreos"
scos_os:= "rhcos"

fcos_label:= "fedora-coreos"
scos_label:= "centos-stream-coreos"

afterburn_commit:= `git ls-remote https://github.com/qinqon/afterburn.git refs/heads/kubevirt-support-cloud-init-network-data | cut -f1`
ignition_commit:= `git ls-remote https://github.com/qinqon/ignition.git refs/heads/kubevirt-nocloud | cut -f1`

toolbox := if os == "scos" { scos_toolbox_img } else { fcos_toolbox_img }
base := if os == "scos" { scos_base_img } else { fcos_base_img }
image := if os == "scos" { scos_img } else { fcos_img }
kubevirt_image := if os == "scos" { scos_kubevirt_img } else { fcos_kubevirt_img }
os_name := if os == "scos" { scos_os } else { fcos_os }
label := if os == "scos" { scos_label } else { fcos_label }
archive := os + ".ociarchive"

all: build oci-archive osbuild-kubevirt push-kubevirt

build:
    sudo podman build --authfile {{auth_file}} --network=host --build-arg TOOLBOX={{toolbox}} --build-arg BASE={{base}} --build-arg LABEL={{label}} --build-arg AFTERBURN_COMMIT={{afterburn_commit}} --build-arg IGNITION_COMMIT={{ignition_commit}} -t {{image}} .

oci-archive:
    sudo skopeo copy containers-storage:{{image}} oci-archive:{{archive}}

osbuild-kubevirt:
    #!/bin/bash
    set -xeuo pipefail

    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/coreos/custom-coreos-disk-images ${TMPDIR}
    sudo setenforce 0
    sudo -E ${TMPDIR}/custom-coreos-disk-images.sh --platform kubevirt \
        --ociarchive {{archive}} \
        --osname {{os_name}}
    rm -rf "$TMPDIR"

push-kubevirt:
    sudo skopeo --tls-verify=false copy oci-archive:{{os}}-kubevirt.x86_64.ociarchive docker://{{kubevirt_image}}
    echo {{kubevirt_image}}@$(skopeo --tls-verify=false inspect docker://{{kubevirt_image}} |jq -r .Digest)
