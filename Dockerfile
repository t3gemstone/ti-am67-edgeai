ARG ARCH=arm64
FROM --platform=linux/${ARCH} ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV WORKDIR=/root
ENV SOC=j722s
ENV LDFLAGS="-L/usr/include/tflite_2.12/farmhash-build \
-L/usr/include/tflite_2.12/pthreadpool-build \
-L/usr/include/tflite_2.12/ruy-build/ruy \
-L/usr/include/tflite_2.12/pthreadpool $LDFLAGS"

ENV LD_LIBRARY_PATH="/usr/include/tflite_2.12/farmhash-build:\
/usr/include/tflite_2.12/pthreadpool-build:\
/usr/include/tflite_2.12/ruy-build/ruy:\
/usr/include/tflite_2.12/pthreadpool:$LD_LIBRARY_PATH"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        automake \
        bash \
        binfmt-support \
        bison \
        build-essential \
        ca-certificates \
        ccache \
        chrpath \
        cpio \
        curl \
        debianutils \
        debootstrap \
        diffstat \
        dosfstools \
        file \
        flex \ 
        gawk \
        gcc \
        git \
        iputils-ping \
        libacl1 \
        libdrm-dev \
        libegl-dev \
        libelf-dev \
        libgbm-dev \
        libgles2-mesa-dev \
        libglm-dev \
        liblz4-tool \
        libncurses-dev \
        libopencv-dev \
        libsdl2-2.0-0 \
        libsdl2-dev \
        libssl-dev \
        libtool \
        libyaml-cpp-dev \
        locales \
        nano \
        ninja-build \
        openssl \
        parted \
        pkg-config \
        pybind11-dev \
        python3 \
        python3-git \
        python3-jinja2 \
        python3-pexpect \
        python3-pip \
        python3-subunit \
        qemu-system-arm \
        qemu-system-x86 \
        qemu-user \
        qemu-user-static \
        sed \
        socat \
        software-properties-common \
        sudo \
        tar \
        texinfo \
        udev \
        unzip \
        vim \
        wget \
        x11-xserver-utils \
        xterm \
        xz-utils \
        zstd \
    && locale-gen en_US.UTF-8

RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
    gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' \
    > /etc/apt/sources.list.d/kitware.list && \
    apt-get update

RUN apt-get install -y \
    cmake=3.29.6-0kitware1ubuntu22.04.1 \
    cmake-data=3.29.6-0kitware1ubuntu22.04.1

RUN git clone git://git.ti.com/rpmsg/ti-rpmsg-char.git \
    --branch 0.6.7 --depth 1 --single-branch && \
    cd ti-rpmsg-char && \
    autoreconf -i && ./configure --host=aarch64-none-linux-gnu --prefix=/usr && \
    make && make install && \
    rm -rf ti-rpmsg-char

# Allow minimum password length of image in Distrobox to be 1 character
RUN sed -i 's/pam_unix\.so obscure/pam_unix.so minlen=1 obscure/' /etc/pam.d/common-password
RUN echo gemstone > /etc/hostname

# Taskfile Installation
RUN curl --location https://taskfile.dev/install.sh | sudo sh -s -- -d -b /usr/local/bin && \
    task --completion bash > /etc/bash_completion.d/task

# VCS Repotool
RUN pip install vcstool --force-reinstall && \
    cp /usr/local/share/vcstool-completion/vcs.bash /etc/bash_completion.d/vcs

# -------------------------------------------------------------------------
# yq
# -------------------------------------------------------------------------
RUN wget https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64 \
    -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

RUN pip3 install meson pybind11 numpy

CMD ["bash"]
