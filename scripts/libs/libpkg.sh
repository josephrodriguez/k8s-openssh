#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
query_package_version() {
    echo $(dpkg-query --showformat='${Version}' --show  $1 2>/dev/null)
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
install_package() {      
    sudo apt-get install $1 -y
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
install_required_packages() {
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