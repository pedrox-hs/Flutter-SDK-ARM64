FROM ubuntu:latest


ENV PATH="${PATH}:/opt/depot_tools:/root/buildroot/output/host/bin"
ENV BUILDS_BASE_DIR="/var/cache/flutter-build"


RUN \
    apt-get update && \
    apt-get install -y \
        curl zip unzip xz-utils python3 pip git jq && \
    apt-get install -y \
        pkg-config g++-x86-64-linux-gnu g++-aarch64-linux-gnu g++-arm-linux-gnueabihf && \
    apt-get install -y \
        g++-multilib gcc-multilib clang wayland-protocols libwayland-bin && \
    rm -rf /var/lib/apt/lists/*

RUN \
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git --depth 1 --single-branch /opt/depot_tools


VOLUME [ "/artifacts" ]

COPY bin/* /usr/bin/