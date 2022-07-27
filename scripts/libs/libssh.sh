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
generate_ssh_key() {
    debug "Generating key..."
    debug "~/.ssh/$3"

    type=$1
    size=$2
    output=$3
    username=$4
    server=$5

    puttygen -t $type -b $size -o $output -C "$username@$server" -q
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
extract_public_key() {
    private_key_file=$1

    echo $(puttygen -L $private_key_file)
}