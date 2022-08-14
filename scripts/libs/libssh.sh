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

    local key_file_path=$1

    local key_type=$2
    local key_size=$3
    local username=$4
    local server=$5

    key_dir_path=$(dirname $key_file_path)

    if [ ! -d "$key_dir_path" ]; then
        warn "$key_dir_path not found"
        debug "Create and set permissions to SSH key directory: $key_dir_path"
        
        mkdir -p $key_dir_path && chmod 700 $key_dir_path
    fi

    public_key_path="${key_file_path%.*}.pub"

    if [ ! -f "$key_file_path" ]; then 
        warn "SSH key file $key_file_path not found"

        debug "Generating SSH key: $key_file_path"
        debug "SSH key type: $key_type"
        debug "SSH key size: $key_size"
        debug "SSH username: $username"
        debug "SSH server: $server"

        generate_ssh_key "$key_type" $key_size "$key_file_path" "$username" "$server"

        debug "Extracting public key for SSH key: $key_file_path"        
        
        touch $public_key_path && chmod 644 $public_key_path

        warn "$key_file_path"
        warn "$public_key_path"

        public_key=$(extract_public_key "$key_file_path")

        debug "Extracted public key: $public_key_path"
        echo $public_key > $public_key_path
    fi

    if [ ! -f "$public_key_path" ]; then
        error "SSH public key $public_key_path not found"
        exit 1
    fi

    cat "$public_key_path"
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
function generate_ssh_key() {

    local key_type=$1
    local key_size=$2
    local output_path=$3
    local username=$4
    local server=$5

    puttygen -t "$key_type" -b $key_size -o "$output_path" -C "$username@$server" -q
    chmod 600 $output_path
}

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
function extract_public_key() {

    local key_file_path=$1

    puttygen -L "$key_file_path"
}