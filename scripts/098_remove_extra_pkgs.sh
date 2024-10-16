#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

setup_aptitude(){
    apt-get install -yq aptitude
    dpkg --configure -a
}

mark_core_packages_required(){
    local pkgs
    pkgs="$(jq -r '.nopurge | join("~|")' /tmp/external-deps-and-pkgs.json)"
    echo "==> REMOVING ALL BUT: ${pkgs} pkgs"
    aptitude --assume-yes markauto "~i!?name(${pkgs})"
}

purge_nonrequired_pkgs(){
    # dryrun first
    aptitude -s --assume-yes purge '~c'
    aptitude --assume-yes purge '~c'
    aptitude --assume-yes purge curl gnupg2
}

cleanup_aptitude(){
    apt-get --purge -y autoremove aptitude
}


main(){
    setup_aptitude

    mark_core_packages_required

    purge_nonrequired_pkgs

    cleanup_aptitude

    rm /tmp/external-deps-and-pkgs.json
}

main
