#! /bin/bash
# This script should be run inside the CONTAINER

if [ ! -f /.dockerenv ]; then
    echo "This script should be run inside the osrt-build Docker container"
    exit 1
fi

current_dir=$(pwd)
NPROC=7

cd $WORKDIR/workarea/gstreamer

SECONDS=0

rm -rf builddir
meson setup builddir \
  --prefix=/usr/local \
  --wrap-mode=nofallback \
  -Dexamples=disabled \
  -Dtests=disabled 
  
while true; do
    meson compile -C builddir
    RET=$?

    if [ $RET -eq 0 ]; then
        exit 0
    fi

    sleep 3
done

echo "gstreamer_build.sh: Completed!"
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."

# chmod
chmod -R a+w $WORKDIR/workarea

cd $current_dir

echo "$(basename $0): Completed!"
