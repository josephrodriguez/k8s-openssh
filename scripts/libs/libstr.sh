#!/bin/bash

# ==============================================================================
# Method description
# Arguments:
#   Void
# Returns:
#   None
# ==============================================================================
str_to_array() {
    #IFS=$'\n' read -rd '' -a arr <<< $1
    echo $1 | tr "," "\n"
}