# custom-ubuntu-2204-cloud-img

> Custom Ubuntu 22.04 image as sample for Packer usage

## About

This repo is an example of building a custom qcow based VM image by customizing
an [upstream Ubuntu 22.04 cloud image](https://cloud-images.ubuntu.com/releases/22.04/).

Image build and publication happens automatically on PR merge via GitHub actions
for free.

Resulting image is published as a GitHub release asset after the merge commit.

See the [releases page](https://github.com/codeplox-dev/custom-ubuntu-2204-cloud-img/releases)
for the latest info.

---

### Local development

Reqs:

- Machine w/ Qemu/KVM (tested on Ubuntu 22.04 IBM Cloud VM).

Install required deps and build image:

```bash
./install_packer_and_build.sh
```

After, e.g. to boot:

```bash
sudo qemu-img convert -O qcow2 output/custom-ubuntu-22.04-x86_64 /var/lib/libvirt/images/ubuntu-image.qcow2

sudo qemu-img resize -f qcow2 /var/lib/libvirt/images/ubuntu-image.qcow2 32G

sudo virt-install \
    --connect qemu:///system \
    --name ubuntu-image \
    --memory 2048 \
    --vcpus 2 \
    --os-variant ubuntu22.04 \
    --disk path=/var/lib/libvirt/images/ubuntu-image.qcow2,bus=virtio \
    --import \
    --noautoconsole \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial
```

To connect:

```bash
sudo virsh domifaddr ubuntu-image

ssh -i <priv_key_path> ssh-user@<addr>
```

To stop:

```bash
sudo virsh destroy ubuntu-image
sudo virsh undefine ubuntu-image
```

#### Misc

Keep [external-deps-and-pkgs.json](./external-deps-and-pkgs.json) sorted with:

```bash
jq -S 'walk(if type == "array" then sort else . end)' external-deps-and-pkgs.json > temp.json && mv temp.json external-deps-and-pkgs.json
```
