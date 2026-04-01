#!/bin/bash

export CPLUS_INCLUDE_PATH=/usr/local/lib/python3.10/dist-packages/dlr/include:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/lib/tensorflow:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/lib/tflite_2.12:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/lib/tensorflow/tensorflow/lite/tools/pip_package/gen/tflite_pip/python3/cmake_build/flatbuffers/include:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/lib/onnxruntime/include/onnxruntime:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/lib/onnxruntime/include/onnxruntime/core/session:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/include/libdrm:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/local/include/opencv4:$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/usr/local/include/gstreamer-1.0:$CPLUS_INCLUDE_PATH

export LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/dlr:$LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib/python3.10/dist-packages/dlr:$LD_LIBRARY_PATH

export EDGEAI_GST_APPS_PATH=/opt/edgeai-gst-apps       
export OOB_DEMO_ASSETS_PATH=/opt/oob-demo-assets       
export MODEL_ZOO_PATH=/opt/model_zoo             
export EDGEAI_SDK_VERSION=11_00_00 
export EDGEAI_VERSION=11.0                        
export SOC=j722s      
export DEVICE_NAME=AM67A             
export EDGEAI_DATA_PATH=/opt/edgeai-test-data      

export PYTHONPATH=/opt/edgeai-dl-inferer/dl_inferer_python:$PYTHONPATH
export GST_PLUGIN_PATH=/usr/local/lib/aarch64-linux-gnu/gstreamer-1.0

export LDFLAGS="-L/usr/include/tflite_2.12/farmhash-build -L/usr/include/tflite_2.12/pthreadpool-build $LDFLAGS"
export LD_LIBRARY_PATH="/usr/include/tflite_2.12/farmhash-build:/usr/include/tflite_2.12/pthreadpool-build:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="/usr/include/tflite_2.12/ruy-build/ruy:$LD_LIBRARY_PATH"
export LDFLAGS="-L/usr/include/tflite_2.12/ruy-build/ruy $LDFLAGS"

# Utility functions

# config file path
config_file="$WORKDIR/scripts/config.yaml"

# Function to get a value from the YAML file
get_yaml_value() {
    local repo=$1
    local key=$2

    # Extract the value using yq
    value=$(yq e ".${repo}.${key}" "$config_file")
    echo "$value"
}

# Function to extract repository information from the YAML file
extract_repo_info() {
    local repo=$1

    repo_url=$(yq e ".${repo}.url" "$config_file")
    repo_tag=$(yq e ".${repo}.tag" "$config_file")
    repo_branch=$(yq e ".${repo}.branch" "$config_file")
    repo_commit=$(yq e ".${repo}.commit" "$config_file")

    echo "repo_url: $repo_url"
    echo "repo_tag: $repo_tag"
    echo "repo_branch: $repo_branch"
    echo "repo_commit: $repo_commit"
}

# Function to clone a repository based on the tag value
# Usage: clone_repo "$repo_url" "$tag" "$branch" "$commit" "$repo_name"
clone_repo() {
    local repo_url=$1
    local tag=$2
    local branch=$3
    local commit=$4
    local repo_name=$5

    if [[ "$tag" == "None" || -z "$tag" ]]; then
        # clone the repository with the specified branch and checkout the commit
        git clone --branch "$branch" --single-branch "$repo_url" "$repo_name"
        cd "$repo_name" || exit
        git checkout "$commit"
        cd -
    else
        # clone the repository with the specified tag
        git clone --branch "$tag" --depth 1 --single-branch "$repo_url" "$repo_name"
    fi
}

# Function to copy a file and backup the original if it exists
copy_and_backup() {
    src_file=$1
    dest_file=$2
    if [ -f "$dest_file" ]; then
        mv "$dest_file" "$dest_file.ORG"
    fi
    cp "$src_file" "$dest_file"
}
