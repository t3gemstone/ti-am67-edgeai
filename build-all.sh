#!/usr/bin/env bash

# If you get segmentation faults, try running this script with `ulimit -c unlimited` first.
# To run recursively to build all components again and again run this code `while true; do ./build-all.sh; sleep 10; done`

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
    local count_file="./build/$1.count"
    local count=0

    if [ -f "$count_file" ]; then
        count=$(cat "$count_file" 2>/dev/null || echo 0)
        count=${count:-0}
    fi

    if [ "$count" -ge 10 ] && [ "$1" != "install:all" ]; then
        echo "==============================="
        echo "Skipping build for $1: already failed $count times"
        echo "==============================="
        echo ""
        return
    fi

    if [ ! -f "$output" ] || [ "$1" = "install:all" ]; then
        echo "==============================="
        echo "Starting build for $1"
        echo "==============================="
        echo ""

        while :
        do
            if task "$1"; then
                touch "$output"
                rm -f "$count_file"
                break
            fi

            count=$((count + 1))
            echo "$count" > "$count_file"
            if [ "$count" -ge 10 ] && [ "$1" != "install:all" ]; then
                echo "==============================="
                echo "Skipping build for $1 after $count failed attempts"
                echo "==============================="
                echo ""
                break
            fi

            fail "$1"
        done
    fi
}

clean_counters() {
    rm -f ./build/*.count
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

clean_counters
