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
function get_k8s_configuration() {

    K8S_CURENT_CONTEXT=$(get_current_context)
    info "Using the Kubernetes context: $K8S_CURENT_CONTEXT"

    K8S_CLUSTER_SERVER=$(get_cluster_server)    
    info "The Kubernetes cluster server: $K8S_CLUSTER_SERVER"
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
function verify_k8s_cluster_status() {

    local K8S_CLUSTER_STATUS=$(get_cluster_status "$K8S_CLUSTER_SERVER")

    debug_section "Fetching cluster status..." "$K8S_CLUSTER_STATUS"
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
function verify_k8s_cluster_readiness() {

    local K8S_CLUSTER_READINESS=$(get_cluster_readiness "$K8S_CLUSTER_SERVER")

    debug_section "Verifying cluster readiness..." "$K8S_CLUSTER_READINESS"
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
function get_k8s_cluster_nodes() {

    local K8S_CLUSTER_NODES=$(get_cluster_nodes)

    cluster_node_message=$(echo "$K8S_CLUSTER_NODES" | tr "{}" " " | column -t -s ",")

    debug_section "Getting cluster nodes information..." "$cluster_node_message"
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
    debug $(k8s_create_persistent_volume_claim "$K8S_PERSISTENT_VOLUMECLAIM_NAME" "$K8S_PERSISTENT_VOLUME_STORAGE_CLASSNAME" "$K8S_PERSISTENT_VOLUME_ACCESS_MODE" "$K8S_PERSISTENT_VOLUME_STORAGE" "$K8S_DRY_RUN")
    debug $(k8s_create_deployment "$K8S_DEPLOYMENT_NAME" "$K8S_DEPLOYMENT_IMAGE" $SSH_SERVER_PORT "$K8S_SECRET_ENV_NAME" "$K8S_CONFIGMAP_ENV_NAME" "$K8S_CONFIGMAP_VOLUME_NAME" "$K8S_PERSISTENT_VOLUMECLAIM_NAME" "$K8S_DRY_RUN")

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

get_k8s_configuration && verify_k8s_cluster_status && verify_k8s_cluster_readiness

get_k8s_cluster_nodes

setup_default_environment
deploy_k8s_openssh_server