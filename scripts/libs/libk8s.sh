#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_current_context() {
    kubectl config current-context
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_server() {
    kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_status() {

    local k8s_server=$1

    curl --insecure --silent --max-time 15 -w "%{http_code}\n" --output /dev/null "$k8s_server/healthz" 
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_readiness() {

    local k8s_server=$1
    curl --insecure --silent --max-time 15 -w "%{http_code}\n" --output /dev/null "$k8s_server/readyz?verbose"
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_nodes() {
    kubectl get node -o json | jq -c '.items[] | {nodeName: .metadata.name,  kubeletVersion: .status.nodeInfo.kubeletVersion}'
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_namespace_if_not_exist() {

    local namespace=$1
    local dry_run=$2

    namespace_status=$(kubectl get ns "$namespace" -o jsonpath='{.status.phase}')

    if [[ "$namespace_status" == "Active" ]]; then 
        echo "namespace/$namespace already exist"
    else
        yaml=$(kubectl create ns "$namespace" --dry-run=client -o yaml)

        if [[ "$dry_run" == "true" ]]; then
            echo "namespace/$namespace created"
        else
            kubectl apply -f - <<< "$yaml"
        fi
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_secret() {
    
    local secret_name=$1
    local namespace=$2
    local public_key=$3
    local dry_run=$4

    yaml=$(kubectl create secret generic "$secret_name" --from-literal=PUBLIC_KEY="$public_key" --namespace="$namespace" --dry-run=client -o yaml)

    if [[ "$dry_run" == "true" ]]; then 
        echo "secret/$secret_name configured"
    else
        kubectl apply -f - <<< "$yaml"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_configmap_env() {
    
    local configmap_name=$1
    local namespace=$2
    local configmap_file_path=$3
    local dry_run=$4
    
    configmap_yaml=$(kubectl create configmap $configmap_name --from-env-file=$configmap_file_path --namespace="$namespace" --dry-run=client -o yaml)
    
    if [[ "$dry_run" == "true" ]]; then 
        echo "configmap/$configmap_name configured"
    else
        kubectl apply -f - <<< "$configmap_yaml"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_configmap_volume() {

    local configmap_name=$1
    local namespace=$2
    local directory_path=$3
    local dry_run=$4

    configmap_yaml=$(kubectl create configmap $configmap_name --from-file=$directory_path --namespace="$namespace" --dry-run=client -o yaml)

    if [[ "$dry_run" == "true" ]]; then 
        echo "configmap/$configmap_name configured"
    else
        kubectl apply -f - <<< "$configmap_yaml"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_service() {

    local service_name=$1
    local service_port=$2
    local namespace=$3
    local dry_run=$4

    service_yaml=$(kubectl create service clusterip "$service_name" --tcp=$service_port:$service_port --namespace="$namespace" --dry-run=client -o yaml)

    if [[ "$dry_run" == "true" ]]; then 
        echo "service/$service_name configured"
    else
        kubectl apply -f - <<< "$service_yaml"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_persistent_volume() {

    local persistent_volume_name=$1
    local dry_run=$6

    persistent_volume_json=$(k8s_get_resource_template "v1" "PersistentVolume" "default" \
    | jq --arg NAME "$persistent_volume_name" \
        --arg CLASSNAME "$2" \
        --arg ACCESS_MODE "$3" \
        --arg STORAGE "$4" \
        --arg PATH "$5" \
        '.metadata.name=$NAME | .spec.storageClassName=$CLASSNAME | .spec.accessModes=[$ACCESS_MODE] | .spec.capacity.storage=$STORAGE | .spec.hostPath.path=$PATH')

    if [[ "$dry_run" == "true" ]]; then 
        echo "persistentvolume/$persistent_volume_name configured"
    else 
        kubectl apply -f - <<< "$persistent_volume_json"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_create_persistent_volume_claim() {

    local claim_name=$1
    local namespace=$2
    local dry_run=$6

    claim_json=$(k8s_get_resource_template "v1" "PersistentVolumeClaim" "$namespace" \
    | jq --arg NAME "$claim_name" \
        --arg CLASSNAME "$3" \
        --arg ACCESS_MODE "$4" \
        --arg STORAGE "$5" \
        '.metadata.name=$NAME | .spec.storageClassName=$CLASSNAME | .spec.accessModes=[$ACCESS_MODE] | .spec.resources.requests.storage=$STORAGE')

    if [[ "$dry_run" == "true" ]]; then 
        echo "persistentvolumeclaim/$claim_name configured"
    else
        kubectl apply -f - <<< "$claim_json"
    fi
}

function k8s_create_deployment() {

    local name=$1
    local image_name=$2
    local namespace=$3
    local container_port=$4
    local dry_run=$9

    deployment_json=$(kubectl create deployment "$name" --image=$image_name --port=$container_port --namespace=$namespace --dry-run=client -o json \
    | jq --arg SECRET_ENV_NAME $5 \
        --arg CONFIGMAP_ENV_NAME $6 \
        '.spec.template.spec.containers[0].envFrom+=[{"configMapRef":{"name":$CONFIGMAP_ENV_NAME}},{"secretRef":{"name":$SECRET_ENV_NAME}}]' \
    | jq --arg CONFIGMAP_VOLUME_NAME $7 '.spec.template.spec.volumes+=[{"name":$CONFIGMAP_VOLUME_NAME, "configMap":{"name":$CONFIGMAP_VOLUME_NAME}}]' \
    | jq --arg PERSISTENT_CLAIM_NAME $8 '.spec.template.spec.volumes+=[{"name":"default-config-volume", "persistentVolumeClaim":{"claimName":$PERSISTENT_CLAIM_NAME}}]' \
    | jq --arg CONFIGMAP_VOLUME_NAME $7 '.spec.template.spec.containers[0].volumeMounts+=[{"name":$CONFIGMAP_VOLUME_NAME,"mountPath":"/config/custom-cont-init.d"}]' \
    | jq '.spec.template.spec.containers[0].volumeMounts+=[{"name":"default-config-volume","mountPath":"/config"}]')

    if [[ "$dry_run" == "true" ]]; then 
        echo "deployment.apps/$name configured"
    else
        kubectl apply -f - <<< "$deployment_json"
    fi
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function k8s_get_resource_template() {

    local api_version=$1
    local kind=$2
    local namespace=$3

    echo '{}' \
    | jq --arg API_VERSION $api_version \
        --arg KIND $kind \
        --arg NAMESPACE $namespace \
        '.apiVersion=$API_VERSION | .kind=$KIND | .metadata.namespace=$NAMESPACE'
}