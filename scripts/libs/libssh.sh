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
function generate_ssh_key() {
    local KEY_TYPE=$1
    local KEY_SIZE=$2
    local OUTPUT_PATH=$3
    local USERNAME=$4
    local SERVER=$5

    puttygen -t $KEY_TYPE -b $KEY_SIZE -o $OUTPUT_PATH -C "$USERNAME@$SERVER" -q
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function extract_public_key() {
    local PRIVATE_KEY_FILE=$1

    puttygen -L $PRIVATE_KEY_FILE
}