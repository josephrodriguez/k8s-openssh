#!/bin/bash

# Load libraries
. ./libs/liblog.sh
. ./libs/libk8s.sh
. ./libs/libpkg.sh
. ./libs/libssh.sh

# Parameters
ssh_key_file="k8s.linuxserver.io.ppk"
ssh_key_type="rsa"
ssh_key_size=2048
ssh_username="linuxserver.io"
ssh_server="openssh-server"

info "Start configure prerequisites"
packages=("helm" "putty-tools" "jq" "curl")

# Install required packages
install_required_packages "${packages[@]}"

# Get current Kubernetes context
k8s_current_context=$(get_current_context)
k8s_cluster_server=$(get_cluster_server)

info "Using the Kubernetes context: $k8s_current_context"
info "The Kubernetes cluster server: $k8s_cluster_server"

# Kubernetes cluster health
cluster_health_response=$(get_cluster_status "$k8s_cluster_server")
debug_section "Fetching cluster status..." "$cluster_health_response"

# Kubernetes cluster readiness
cluster_readiness_response=$(get_cluster_readiness "$k8s_cluster_server")
debug_section "Verifying cluster readiness..." "$cluster_readiness_response"

# Get Kubernetes nodes information
cluster_node_response=$(get_cluster_nodes)
cluster_node_message=$(echo "$cluster_node_response" | tr "{}" " " | column -t -s ",")
debug_section "Getting cluster nodes information..." "$cluster_node_message"

# Generate SSH key
generate_ssh_key "$ssh_key_type" $ssh_key_size "$ssh_key_file" "$ssh_username" "$ssh_server"
ssh_public_key=$(extract_public_key "$ssh_key_file")

# Generate K8S Secret
create_ssh_secret "openssh-server" "$ssh_public_key"