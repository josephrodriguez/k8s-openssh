#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Key type
#   Number of bits for the key
#   Filename: The output path for the SSH key
# Returns:
#   None
# ==============================================================================
function get_ssh_public_key() {

    SSH_DIR=$(dirname $SSH_KEY_PATH)

    if [ ! -d "$SSH_DIR" ]; then
        warn "$SSH_DIR not found"
        debug "Create and set permissions to SSH key directory: $SSH_DIR"
        mkdir -p $SSH_DIR && chmod 700 $SSH_DIR
    fi

    SSH_PUBLIC_KEY_PATH="${SSH_KEY_PATH%.*}.pub"

    if [ ! -f "$SSH_KEY_PATH" ]; then 
        warn "SSH key file $SSH_KEY_PATH not found"

        debug "Generating SSH key: $SSH_KEY_PATH"
        debug "SSH key type: $SSH_KEY_TYPE"
        debug "SSH key size: $SSH_KEY_SIZE"
        debug "SSH username: $SSH_USERNAME"
        debug "SSH server: $SSH_SERVER_NAME"

        generate_ssh_key $SSH_KEY_TYPE $SSH_KEY_SIZE $SSH_KEY_PATH $SSH_USERNAME $SSH_SERVER_NAME

        debug "Extracting public key for SSH key: $SSH_KEY_PATH"        
        
        touch $SSH_PUBLIC_KEY_PATH && chmod 700 $SSH_PUBLIC_KEY_PATH
        $(extract_public_key $SSH_KEY_PATH) > $SSH_PUBLIC_KEY_PATH
    fi

    if [ ! -f "$SSH_PUBLIC_KEY_PATH" ]; then
        error "$SSH public key $SSH_PUBLIC_KEY_PATH not found"
        exit 1
    fi

    cat "$SSH_PUBLIC_KEY_PATH"
}

# ==============================================================================
# Method description
# Arguments:
#   Key type
#   Number of bits for the key
#   Filename: The output path for the SSH key
# Returns:
#   None
# ==============================================================================
function deploy_k8s_openssh_server() {

    info "Creating K8S deployment resources..."

    SSH_PUBLIC_KEY=$(get_ssh_public_key)

    debug $(k8s_create_namespace_if_not_exist "$K8S_NAMESPACE_NAME" "$K8S_DRY_RUN")
    debug $(k8s_create_secret "$K8S_SECRET_ENV_NAME" "$K8S_NAMESPACE_NAME" "$SSH_PUBLIC_KEY" "$K8S_DRY_RUN")

    ENV_PROPERTIES_FILE_PATH=$(create_properties_file $PGID $PUID $SUDO_ACCESS $TZ)

    debug $(k8s_create_configmap_env "$K8S_CONFIGMAP_ENV_NAME" "$K8S_NAMESPACE_NAME" "$ENV_PROPERTIES_FILE_PATH" "$K8S_DRY_RUN")
    debug $(k8s_create_configmap_volume "$K8S_CONFIGMAP_VOLUME_NAME" "$K8S_NAMESPACE_NAME" "$SSH_CUSTOM_INIT_PATH" "$K8S_DRY_RUN")
    debug $(k8s_create_service "$K8S_SERVICE_NAME" $SSH_SERVER_PORT "$K8S_NAMESPACE_NAME" "$K8S_DRY_RUN")
    debug $(k8s_create_persistent_volume "$K8S_PERSISTENT_VOLUME_NAME" "$K8S_PERSISTENT_VOLUME_STORAGE_CLASSNAME" "$K8S_PERSISTENT_VOLUME_ACCESS_MODE" "$K8S_PERSISTENT_VOLUME_STORAGE" "$K8S_PERSISTENT_VOLUME_PATH" "$K8S_DRY_RUN")
    debug $(k8s_create_persistent_volume_claim "$K8S_PERSISTENT_VOLUMECLAIM_NAME" "$K8S_NAMESPACE_NAME" "$K8S_PERSISTENT_VOLUME_STORAGE_CLASSNAME" "$K8S_PERSISTENT_VOLUME_ACCESS_MODE" "$K8S_PERSISTENT_VOLUME_STORAGE" "$K8S_DRY_RUN")
    debug $(k8s_create_deployment "$K8S_DEPLOYMENT_NAME" "$K8S_DEPLOYMENT_IMAGE" "$K8S_NAMESPACE_NAME" $SSH_SERVER_PORT "$K8S_SECRET_ENV_NAME" "$K8S_CONFIGMAP_ENV_NAME" "$K8S_CONFIGMAP_VOLUME_NAME" "$K8S_PERSISTENT_VOLUMECLAIM_NAME" "$K8S_DRY_RUN")

    rm $ENV_PROPERTIES_FILE_PATH
}

set -o pipefail

# Load libraries
. ./libs/libenv.sh
. ./libs/liblog.sh
. ./libs/libk8s.sh
. ./libs/libpkg.sh
. ./libs/libssh.sh

# Import configuration
. config

info "Start configure prerequisites"

# Install required packages
install_required_packages "${PACKAGES[@]}"

k8s_current_context=$(get_current_context)
info "Using the Kubernetes context: $k8s_current_context"

k8s_cluster_server=$(get_cluster_server)    
info "The Kubernetes cluster server: $k8s_cluster_server"

info "Fetching cluster status..."
k8s_cluster_status=$(get_cluster_status "$k8s_cluster_server")

if [ "$k8s_cluster_status" == "200" ]; then
    info "Kubernetes cluster status: OK"
else
    error "Kubernetes cluster status: Failed"
    exit 1
fi

info "Getting nodes information..."
k8s_cluster_nodes_response=$(get_cluster_nodes)
k8s_cluster_nodes_format=$(echo "$k8s_cluster_nodes_response" | tr "{}" " " | column -t -s ",")

IFS=$'\r\n' read -rd '' -a nodes <<< "$k8s_cluster_nodes_format"
for node in "${nodes[@]}"
    do
        info "$node"
    done

info "Verifying cluster readiness..."
k8s_cluster_readiness=$(get_cluster_readiness "$k8s_cluster_server")

if [ "$k8s_cluster_readiness" == "200" ]; then
    info "Kubernetes cluster is ready"
else
    error "Kubernetes cluster is not ready"
    exit 1
fi

printf 'Do you want to continue with the installation? [Y/n] '
read choice

if [ "$choice" != "${choice#[nN]}" ] ;then
    echo Abort
    exit 1
fi

setup_default_environment
deploy_k8s_openssh_server