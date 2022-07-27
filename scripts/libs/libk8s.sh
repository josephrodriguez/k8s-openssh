#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
get_current_context() {
    kubectl config current-context
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
get_cluster_server() {
    kubectl config view --minify -o json | jq '.clusters[].cluster.server' | tr -d '"'
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
get_cluster_status() {
    curl -k -s -D - "$1/healthz" 2> /dev/null
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
get_cluster_readiness() {
    curl -k -s -D - "$1/readyz?verbose" 2> /dev/null
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
get_cluster_nodes() {
    kubectl get node -o json | jq -c '.items[] | {nodeName: .metadata.name,  kubeletVersion: .status.nodeInfo.kubeletVersion}'
}

apply_resource() {
    resource=$1

    kubectl apply -f - <<< "$resource"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
create_secret() {
    secret_name=$1
    public_key=$2

    secret_yaml=$(kubectl create secret generic "$secret_name" --from-literal=PUBLIC_KEY="$public_key" --dry-run=client -o yaml)
    apply_resource "$secret_yaml"
}

create_service() {

}

create_env_configmap() {

}

create_persistent_volume() {

}

create_persistent_volume_claim() {

}