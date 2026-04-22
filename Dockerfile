# syntax=docker/dockerfile:1.7
#
# BananaWRT builder image
#   Single source of truth for the apt dependencies required to cross-build
#   ImmortalWRT for mediatek/filogic (Banana Pi R3 Mini). Consumed by
#   `./compile.sh --docker` locally and by the firmware / SDK workflows via
#   `container:`. Built multi-arch (linux/amd64 + linux/arm64) from
#   .github/workflows/docker-image.yml.
#

FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.title="BananaWRT builder"
LABEL org.opencontainers.image.description="Build environment for BananaWRT firmware (ImmortalWRT + additional_pack)"
LABEL org.opencontainers.image.source="https://github.com/SuperKali/BananaWRT"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Europe/Rome

ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    TZ=${TZ} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CCACHE_DIR=/build/workspace/cache/ccache \
    PATH=/usr/lib/ccache:${PATH}

# ─── Base image upgrades + CA certs ─────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        locales \
    && ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && locale-gen C.UTF-8 en_US.UTF-8

# ─── Common build dependencies ──────────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ack \
        antlr3 \
        asciidoc \
        autoconf \
        automake \
        autopoint \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ccache \
        clang \
        cmake \
        cpio \
        curl \
        device-tree-compiler \
        dialog \
        ecj \
        fastjar \
        flex \
        gawk \
        genisoimage \
        gettext \
        gh \
        git \
        gosu \
        gperf \
        haveged \
        help2man \
        intltool \
        jq \
        libbabeltrace-dev \
        libdw-dev \
        libelf-dev \
        libglib2.0-dev \
        libgmp3-dev \
        libgnutls28-dev \
        libltdl-dev \
        libmpc-dev \
        libmpfr-dev \
        libncurses-dev \
        libpython3-dev \
        libreadline-dev \
        libssl-dev \
        libtool \
        libtool-bin \
        libyaml-dev \
        liblzma-dev \
        libpfm4 \
        libpfm4-dev \
        lftp \
        lld \
        llvm \
        lrzsz \
        nano \
        ninja-build \
        p7zip \
        p7zip-full \
        patch \
        pkgconf \
        python3 \
        python3-pip \
        python3-ply \
        python3-docutils \
        python3-pyelftools \
        qemu-utils \
        re2c \
        rsync \
        scons \
        squashfs-tools \
        subversion \
        sudo \
        swig \
        texinfo \
        tree \
        uglifyjs \
        unzip \
        upx-ucl \
        vim \
        wget \
        xmlto \
        xxd \
        zstd \
        zlib1g-dev

# ─── Architecture-specific extras ───────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    case "$(dpkg --print-architecture)" in \
        amd64) \
            apt-get update \
            && apt-get install -y --no-install-recommends \
                gcc-multilib \
                g++-multilib \
                libc6-dev-i386 \
                lib32gcc-s1 ; \
            ;; \
        arm64) \
            # aarch64-specific libraries are already in the common layer \
            # but keep the branch for future additions. \
            true ; \
            ;; \
    esac

# ─── Non-root user for builds ───────────────────────────────────────────────
# Reuse the base image's `ubuntu` (UID 1000). No `USER` directive so the
# container defaults to root — lets actions/checkout write to bind-mounted
# _work/_temp regardless of host runner UID. compile.sh re-execs under
# `ubuntu` via gosu so ImmortalWRT's non-root-build invariant is preserved.
RUN install -d -o ubuntu -g ubuntu /build /build/workspace /build/workspace/cache/ccache \
    && chmod -R a+rwX /build \
    && printf 'ubuntu ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/ubuntu \
    && chmod 440 /etc/sudoers.d/ubuntu

WORKDIR /build

HEALTHCHECK --interval=30s --timeout=10s --retries=2 \
    CMD test -x /build/compile.sh && /build/compile.sh --help >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/bin/bash"]
CMD ["-lc", "/build/compile.sh --help"]
