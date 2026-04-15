#!/usr/bin/env bash

# If you get segmentation faults, try running this script with `ulimit -c unlimited` first.

ulimit -c unlimited

while :
do
    task build:all
    sleep 1
done
