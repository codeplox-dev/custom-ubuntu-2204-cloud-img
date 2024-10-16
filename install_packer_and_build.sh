#!/usr/bin/env bash

# shellcheck disable=all

set -euo pipefail

export OUT_DIR="output"
export IMG="custom-ubuntu-22.04-x86_64"
export QCOW_IMG="customjammy"
export OUTPUT_PATH="/var/lib/libvirt/images"
export OUTPUT_QCOW="${OUTPUT_PATH}/${QCOW_IMG}.qcow2"
export OUTPUT_QCOW_COMPRESSED="${OUTPUT_PATH}/${QCOW_IMG}_compressed.qcow2"
export DEBIAN_FRONTEND=noninteractive
declare RELEASENOTES

if [[ "$(whoami)" != "root" ]]; then
    export SUDO="sudo -E "
else
    export SUDO=""
fi

RELEASENOTES=$(cat <<-END
To install:
1. Download

    * **${QCOW_IMG}_compressed.qcow2**
    * **${QCOW_IMG}_compressed.qcow2.sha256sum**

    Can check the package validity before continuing on like so:

    \`\`\`bash
    # Make sure you are in the same directory as the ${QCOW_IMG}_compressed.qcow2
    sha256sum -c ${QCOW_IMG}_compressed.qcow2.sha256sum
    \`\`\`

2. Run:


    \`\`\`bash
    sudo mv ${QCOW_IMG}_compressed.qcow2 /var/lib/libvirt/images/customjammy.qcow2

    sudo virt-install \\

      --connect qemu:///system \\

      --name customjammy \\

      --memory 2048 \\

      --vcpus 2 \\

      --os-variant ubuntu22.04 \\

      --disk path=/var/lib/libvirt/images/customjammy.qcow2,bus=virtio \\

      --import \\

      --noautoconsole \\

      --network network=default,model=virtio \\

      --graphics none \\

      --console pty,target_type=serial
    \`\`\`

3. Connect:

    \`\`\`bash
    sudo virsh domifaddr customjammy

    ssh -i <priv_key_path> ssh-user@<addr>
    \`\`\`
END
)


check_user_vars(){
    local unset=0
    if [[ "${GITHUB_TOKEN-}" == "" ]]; then
        echo "ERR - must set GITHUB_TOKEN to GH token"
        unset=1
    fi
    if [[ "${unset}" != "0" ]]; then
        exit 1
    fi
}

install_gh_cli(){
    local gh_vers=2.36.0

    wget https://github.com/cli/cli/releases/download/v${gh_vers}/gh_${gh_vers}_linux_amd64.tar.gz
    tar xvzf gh_${gh_vers}_linux_amd64.tar.gz
    ${SUDO}mv gh_${gh_vers}_linux_amd64/bin/gh /usr/local/bin/
    rm -rf gh_${gh_vers}_linux_amd64*
}

check_pub_tools(){
    command -v gh &>/dev/null && { return 0; } || {
        echo "Did not detect gh cli, installing now (CTR-C in next 10 seconds to quit..."
        sleep 10
        install_gh_cli
    }

    command -v jf &>/dev/null && { return 0; } || {
        echo "Did not detect jf cli, installing now (CTR-C in next 10 seconds to quit..."
        sleep 10
        curl -fL https://install-cli.jfrog.io | sudo sh
    }
}

install_packer(){
    command -v packer &>/dev/null && { return 0; } || true

    curl -fsSL https://apt.releases.hashicorp.com/gpg | ${SUDO}apt-key add -
    ${SUDO}apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    ${SUDO}apt-get update && ${SUDO}apt-get install packer
    command -v packer &>/dev/null || { echo "ERR - packer not installed fulled"; exit 1; }
}

install_qemu_kvm(){
    local lib=""
    local libnbd="libnbd-bin"

    command -v virt-install &>/dev/null && { return 0; } || true

    if [[ "$(grep VERSION_ID /etc/os-release | grep '22\.04')" == ""  ]]; then
        lib="lib"
        libnbd="libnbd-dev"
    fi

    ${SUDO}apt-get install -y ${lib}guestfs-tools qemu cpu-checker qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virtinst libvirt-daemon cloud-image-utils qemu-utils ${libnbd} nbdkit fuse2fs
    ${SUDO}systemctl enable --now libvirtd

    if [[ "${CI-}" != "" ]]; then
        ${SUDO}usermod -a -G kvm,libvirt,libvirt-qemu "$USER"
    fi
}

publish(){ local img="${1}"
    # Publish to GH release
    local img_sum="${img}.sha256sum"
    local sum img_name

    img_name=$(basename "${img}" .qcow2)

    sha256sum "${img}" | ${SUDO}tee "${img_sum}"
    sum=$(${SUDO}awk '{print $1}' "${img_sum}")

    echo "${RELEASENOTES}" > "notes.md"
    #gh auth login --hostname github.com --with-token <<< "${GITHUB_TOKEN}"
    gh release create -t "Custom Ubu 22.04 cloud img v$(cat VERSION)" -F notes.md "$(cat VERSION)" "${img}" "${img_sum}"
    rm notes.md
    # Upload $img to artifactory, COS, etc
}

main(){
    ${SUDO}apt-get update

    if [[ "${PUBLISH_IMG-}" == "1" ]]; then
        check_user_vars
        check_pub_tools
        sudo mkdir -p ~/.config/gh
        sudo chown -R bob:bob ~/.config/gh
    fi

    install_packer
    install_qemu_kvm

    ${SUDO}packer init .
    PACKER_LOG=1 ${SUDO}packer build ubu2204_jammy.pkr.hcl

    ${SUDO}qemu-img convert -O qcow2 ${OUT_DIR}/${IMG} ${OUTPUT_QCOW}
    ${SUDO}qemu-img resize -f qcow2 ${OUTPUT_QCOW} 32G
    ${SUDO}virt-sparsify --compress ${OUTPUT_QCOW} ${OUTPUT_QCOW_COMPRESSED}
    echo -e "\n\n==> FINISHED!! Output image: ${OUTPUT_QCOW_COMPRESSED}"

    if [[ "${PUBLISH_IMG-}" == "1" && "${BRANCH_NAME:-}" == "master" ]]; then
        publish "${OUTPUT_QCOW_COMPRESSED}"
    fi
}

main
