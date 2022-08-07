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
    kubectl config view --minify -o json | jq '.clusters[].cluster.server' | tr -d '"'
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_status() {
    info "$1"
    curl -k -s -D - "$1/healthz" 2> /dev/null
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function get_cluster_readiness() {
    curl -k -s -D - "$1/readyz?verbose" 2> /dev/null
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

    local NAMESPACE_NAME=$1
    local DRY_RUN=$2

    RESPONSE=$(kubectl get ns "$NAMESPACE_NAME" -o jsonpath='{.status.phase}')

    if [[ "$RESPONSE" == "Active" ]]; then 
        echo "$RESPONSE"
    else
        NAMESPACE_YAML=$(kubectl create ns "$NAMESPACE_NAME" --dry-run=client -o yaml)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "$NAMESPACE_YAML"
        else
            kubectl apply -f - <<< "$NAMESPACE_YAML"
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
    
    local SECRET_NAME=$1
    local NAMESPACE=$2
    local PUBLIC_KEY=$3
    local DRY_RUN=$4

    SECRET_YAML=$(kubectl create secret generic "$SECRET_NAME" --from-literal=PUBLIC_KEY="$PUBLIC_KEY" --namespace="$NAMESPACE" --dry-run=client -o yaml)

    if [[ "$DRY_RUN" == "true" ]]; then 
        echo "$SECRET_YAML"
    else
        kubectl apply -f - <<< "$SECRET_YAML"
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
    
    local CONFIGMAP_ENV_NAME=$1
    local NAMESPACE=$2
    local CONFIGMAP_ENV_FILEPATH=$3
    local DRY_RUN=$4
    
    CONFIGMAP_YAML=$(kubectl create configmap $CONFIGMAP_ENV_NAME --from-env-file=$CONFIGMAP_ENV_FILEPATH --namespace="$NAMESPACE" --dry-run=client -o yaml)
    
    if [[ "$DRY_RUN" == "true" ]]; then 
        debug "$CONFIGMAP_YAML"
    else
        kubectl apply -f - <<< "$CONFIGMAP_YAML"
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

    local CONFIGMAP_VOLUME_NAME=$1
    local NAMESPACE=$2
    local DIRECTORY_PATH=$3
    local DRY_RUN=$4

    CONFIGMAP_YAML=$(kubectl create configmap $CONFIGMAP_VOLUME_NAME --from-file=$DIRECTORY_PATH --namespace="$NAMESPACE" --dry-run=client -o yaml)

    if [[ "$DRY_RUN" == "true" ]]; then 
        debug "$CONFIGMAP_YAML"
    else
        kubectl apply -f - <<< "$CONFIGMAP_YAML"
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

    local SERVICE_NAME=$1
    local SERVICE_PORT=$2
    local NAMESPACE=$3
    local DRY_RUN=$4

    SERVICE_YAML=$(kubectl create service clusterip "$SERVICE_NAME" --tcp=$SERVICE_PORT:$SERVICE_PORT --namespace="$NAMESPACE" --dry-run=client -o yaml)

    if [[ "$DRY_RUN" == "true" ]]; then 
        debug "$SERVICE_YAML"
    else
        kubectl apply -f - <<< "$SERVICE_YAML"
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

    local DRY_RUN=$6

    PERSISTENT_VOLUME_YAML=$(k8s_get_resource_template "v1" "PersistentVolume" "default" \
    | jq --arg NAME "$1" \
        --arg CLASSNAME "$2" \
        --arg ACCESS_MODE "$3" \
        --arg STORAGE "$4" \
        --arg PATH "$5" \
        '.metadata.name=$NAME | .spec.storageClassName=$CLASSNAME | .spec.accessModes=[$ACCESS_MODE] | .spec.capacity=$STORAGE | .spec.hostPath.path=$PATH')

    if [[ "$DRY_RUN" == "true" ]]; then 
        echo "$PERSISTENT_VOLUME_YAML"
    else 
        kubectl apply -f - <<< "$PERSISTENT_VOLUME_YAML"
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

    local DRY_RUN=$5

    PERSISTENT_VOLUME_CLAIM_JSON=$(k8s_get_resource_template "v1" "PersistentVolumeClaim" "default" \
    | jq --arg NAME "$1" \
        --arg CLASSNAME "$2" \
        --arg ACCESS_MODE "$3" \
        --arg STORAGE "$4" \
        '.metadata.name=$NAME | .spec.storageClassName=$CLASSNAME | .spec.accessModes=[$ACCESS_MODE] | .spec.resources.requests.storage=$STORAGE')

    if [[ "$DRY_RUN" == "true" ]]; then 
        echo "$PERSISTENT_VOLUME_CLAIM_JSON"
    else
        kubectl apply -f - <<< "$PERSISTENT_VOLUME_CLAIM_JSON"
    fi
}

function k8s_create_deployment() {

    local DEPLOYMENT_NAME=$1
    local IMAGE_NAME=$2
    local CONTAINER_PORT=$3
    local DRY_RUN=$8

    DEPLOYMENT_JSON=$(kubectl create deployment $DEPLOYMENT_NAME --image=$IMAGE_NAME --port=$CONTAINER_PORT --dry-run=client -o json \
    | jq --arg CONFIGMAP_ENV_NAME $4 \
        --arg CONFIGMAP_ENV_NAME $5 \
        '.spec.template.spec.containers[0].envFrom+=[{"configMapRef":{"name":$CONFIGMAP_ENV_NAME}},{"secretRef":{"name":$CONFIGMAP_ENV_NAME}}]' \
    | jq --arg CONFIGMAP_VOLUME_NAME $6 '.spec.template.spec.volumes+=[{"name":$CONFIGMAP_VOLUME_NAME, "configMap":{"name":$CONFIGMAP_VOLUME_NAME,"defaultMode":"0755"}}]' \
    | jq --arg PERSISTENT_CLAIM_NAME $7 '.spec.template.spec.volumes+=[{"name":"default-config-volume", "persistentVolumeClaim":{"claimName":$PERSISTENT_CLAIM_NAME}}]' \
    | jq --arg CONFIGMAP_VOLUME_NAME $6 '.spec.template.spec.containers[0].volumeMounts+=[{"name":$CONFIGMAP_VOLUME_NAME,"mountPath":"/config/custom-cont-init.d"}]' \
    | jq '.spec.template.spec.containers[0].volumeMounts+=[{"name":"default-config-volume","mountPath":"/config"}]')

    if [[ "$DRY_RUN" == "true" ]]; then 
        echo "$DEPLOYMENT_JSON"
    else
        kubectl apply -f - <<< "$DEPLOYMENT_JSON"
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

    local API_VERSION=$1
    local KIND=$2
    local NAMESPACE=$3

    echo '{}' \
    | jq --arg API_VERSION $API_VERSION --arg KIND $KIND  --arg NAMESPACE $NAMESPACE '.apiVersion=$API_VERSION | .kind=$KIND | .metadata.namespace=$NAMESPACE'
}