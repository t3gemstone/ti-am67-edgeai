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
        bash \
        binfmt-support \
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
        gawk \
        gcc \
        git \
        iputils-ping \
        libacl1 \
        libelf-dev \
        liblz4-tool \
        libncurses-dev \
        libsdl2-2.0-0 \
        libsdl2-dev \
        libssl-dev \
        libtool \
        libgles2-mesa-dev \
        libegl-dev \
        libgbm-dev \
        libglm-dev \
        libdrm-dev \
        libyaml-cpp-dev \
        libopencv-dev \
        automake \
        locales \
        nano \
        ninja-build \
        pkg-config \
        openssl \
        parted \
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
        flex \ 
        bison \
    && locale-gen en_US.UTF-8
#  Copyright (C) 2024 Texas Instruments Incorporated - http://www.ti.com/
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#    Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#    Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the
#    distribution.
#
#    Neither the name of Texas Instruments Incorporated nor the names of
#    its contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# -------------------------------------------------------------------------
# Distrobox notları:
#   - ENTRYPOINT kaldırıldı: distrobox kendi init sürecini yönetir
#   - Root varsayımları kaldırıldı: distrobox host kullanıcısını kullanır
#   - distrobox entegrasyon paketleri eklendi (sudo, passwd, vb.)
#   - WORKDIR /root yerine /home kullanımına uygun hale getirildi
#   - ARG'lar build sırasında --build-arg ile geçirilmelidir:
#       ARCH, BASE_IMAGE, RPMSG_VER
# -------------------------------------------------------------------------

ARG ARCH=arm64

# -------------------------------------------------------------------------
# Kitware APT deposu ve CMake 3.29.6
# -------------------------------------------------------------------------
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
RUN wget https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_${ARCH} \
    -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

RUN pip3 install meson

CMD ["bash"]
