variables {
  temporary_key_pair_name = "packer_build_tempkey"
}

# If you had artifactory:
#
# variable "artif_user" {
#   default = env("ARTIF_USER")
#   sensitive = true
# }
#
# variable "artif_tok" {
#    default = env("ARTIF_TOK")
#    sensitive = true
# }


variable "ssh_pubkeys" {
  type = list(string)
  # include a list of pub ssh keys here, if desired
  default = []
}

data "sshkey" "install" {
  name = var.temporary_key_pair_name
  type = "rsa"
}

variable "efi_boot" {
  type    = bool
  default = false
}

variable "efi_firmware_code" {
  type    = string
  default = null
}

variable "efi_firmware_vars" {
  type    = string
  default = null
}

variable "ssh_username" {
  type    = string
  default = "ssh-user"
}

source "file" "user_data" {
  content = templatefile("http/user-data.tftpl", {
    pub_keys = concat([data.sshkey.install.public_key], var.ssh_pubkeys)
    ssh_pubkey = data.sshkey.install.public_key,
    ssh_privkey = regex_replace(file(data.sshkey.install.private_key_path), "\\n", "\\n")
  })
  target = "user-data"
}

source "file" "meta_data" {
  source = "http/meta-data"
  target  = "meta-data"
}

build {
  sources = ["source.file.user_data", "source.file.meta_data"]

  provisioner "shell-local" {
    inline = ["genisoimage -output cidata.iso -input-charset utf-8 -volid cidata -joliet -r user-data meta-data"]
  }
}

variable "iso_checksum" {
  type    = string
  default = "sha256:1b32d005605699ee0a339b33c35a8682201977ed1037a8c35cded7b54d43db6d"
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/releases/22.04/release-20241002/ubuntu-22.04-server-cloudimg-amd64-disk-kvm.img"
}

variable "vm_name" {
  type    = string
  default = "custom-ubuntu-22.04-x86_64"
}

source "qemu" "ubuntu" {
  disk_compression = true
  disk_image       = true
  disk_size        = "8G"
  iso_checksum     = var.iso_checksum
  iso_url          = var.iso_url
  qemuargs = [
    ["-cdrom", "cidata.iso"],
    ["-display", "none"],
    ["-machine", "type=ubuntu,accel=kvm"],
    ["-cpu", "host"]
  ]
  net_device = "virtio-net"
  output_directory  = "output"
  shutdown_command  = "sudo -S shutdown -P now"
  ssh_timeout       = "120s"
  ssh_username      = var.ssh_username
  vm_name           = var.vm_name
  efi_boot          = var.efi_boot
  efi_firmware_code = var.efi_firmware_code
  efi_firmware_vars = var.efi_firmware_vars
  communicator = "ssh"
  ssh_private_key_file      = data.sshkey.install.private_key_path
  ssh_clear_authorized_keys = true
  temporary_key_pair_name   = var.temporary_key_pair_name
}

build {
  sources = ["source.qemu.ubuntu"]

  # cloud-init may still be running when we start executing scripts
  # To avoid race conditions, make sure cloud-init is done first
  provisioner "shell" {
    inline = [
      "echo '==> Waiting for cloud-init to finish'",
      "/usr/bin/cloud-init status --wait",
      "echo '==> Cloud-init complete'",
    ]
  }

  provisioner "shell" {
    execute_command   = "{{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"
    expect_disconnect = true
    scripts = [
      "./scripts/001_networking.sh",
      "./scripts/002_disable-updates.sh"
    ]
  }

  provisioner "shell" {
    execute_command   = "{{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"
    expect_disconnect = true
    skip_clean = true
    inline = [
      "reboot"
    ]
    pause_after = "30s"
  }

  # If you need to download from artifactory, you'd have these:
  #
  #provisioner "file" {
  #  source =  "./scripts/safe-artifactory-bin-fetcher"
  #  destination = "/tmp/safe-artifactory-bin-fetcher"
  #}

  provisioner "file" {
    source =  "./external-deps-and-pkgs.json"
    destination = "/tmp/external-deps-and-pkgs.json"
  }

  provisioner "file" {
    source =  "./VERSION"
    destination = "/tmp/vm-VERSION"
  }

  provisioner "shell" {
    execute_command   = "sudo -S env {{ .Vars }} bash -eux '{{ .Path }}'"
    expect_disconnect = true
    # If you had artifactory, you'd have these:
    #environment_vars = [
    #  "HEADFUL_SAFE_FETCH=y",
    #  "ARTIF_USER=${var.artif_user}",
    #  "ARTIF_TOK=${var.artif_tok}"
    #]
    scripts = [
      "./scripts/004_install_packages.sh",
      # ... etc
      "./scripts/098_remove_extra_pkgs.sh",
      "./scripts/099_clean_cloudinit.sh",
      "./scripts/999_track_vm_version.sh"
    ]
  }

  provisioner "shell" {
    execute_command   = "{{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"
    inline = [
      "rm -rf /tmp"
    ]
  }
}

packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    sshkey = {
      version = "~> 1.0.1"
      source = "github.com/ivoronin/sshkey"
    }
  }
}
