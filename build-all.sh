#!/usr/bin/env bash

# If you get segmentation faults, try running this script with `ulimit -c unlimited` first.

mkdir -p ./out &> /dev/null
mkdir -p ./workarea &> /dev/null
mkdir -p ./build &> /dev/null

fail() {
    echo "===============================" >&2
    echo "ERROR: $1" >&2
    echo "===============================" >&2
    echo "" >&2
    sleep 3
}

start_build() {
    local output="./build/$1.ok"

    if [ ! -f $output ]; then
        echo "==============================="
        echo "Starting build for $1"
        echo "==============================="
        echo ""

        while :
        do
            task "$1" && touch $output && break || fail $1
        done
    fi
}

start_build "build:vision_lib"
start_build "build:rpmsg"
start_build "build:onnxrt"
start_build "build:tflite"
start_build "build:dlr"
start_build "install:all"
start_build "build:tidl"
start_build "build:v4l2"
start_build "build:gstreamer"
start_build "install:all"
start_build "build:edgeai_debs"
start_build "build:t3_gem_o1_edgeai_debs"
