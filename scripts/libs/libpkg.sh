#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function query_package_version() {
    
    local package=$1

    echo $(dpkg-query --showformat='${Version}' --show  $package 2>/dev/null)
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function install_package() { 

    local package=$1

    sudo apt-get install $package -y
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function install_required_packages() {
    arr=("$@")
    for package in "${arr[@]}";
        do
            version=$(query_package_version $package)
            if [ ! -z "${version}" ]; then
                info "Found installed package ${package} version: ${version}"
            else
                debug "Installing required package ${package}"
                install_package "$package"
                version=$(query_package_version "$package")
                info "Successfully installed ${package} version ${version}"
            fi
        done
}