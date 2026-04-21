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
# ImmortalWRT refuses to compile as root. We create `builder` (uid 1000) and
# grant passwordless sudo for the rare step that still needs root (e.g.
# timedatectl on the host runner — no-op in container).
RUN userdel --remove --force ubuntu 2>/dev/null || true \
    && groupadd --system --gid 1000 builder \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash builder \
    && printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder \
    && chmod 440 /etc/sudoers.d/builder

# Working directory with permissive write bits so any container UID mapped
# in via --user can still operate here.
RUN mkdir -p /build/workspace/cache/ccache \
    && chown -R builder:builder /build \
    && chmod -R a+rwX /build

# ─── Dynamic UID/GID remap entrypoint ───────────────────────────────────────
# GitHub-hosted runners (ubuntu-latest) run the runner as UID 1001 and bind-
# mount /__w into this container owned by that UID. Self-hosted runners use
# varying UIDs. ImmortalWRT refuses to build as root, so we keep `builder`
# as the non-root user but rewrite its UID/GID at container start to match
# whatever owns /__w (falling back to the baked-in 1000:1000). Root is only
# used for the sub-second remap; the payload always runs as `builder` via
# gosu, so `id -u` inside compile.sh is never 0.
# Refs:
#   https://github.com/actions/runner/issues/2411
#   https://github.com/actions/checkout/issues/956
#   https://github.com/actions/runner-images/issues/10936
COPY --chmod=0755 <<'EOF' /usr/local/bin/docker-entrypoint.sh
#!/bin/bash
set -euo pipefail

TARGET_UID=1000
TARGET_GID=1000

for probe in /__w /__w/_temp /github/workflow /github/home; do
    if [ -e "$probe" ]; then
        TARGET_UID=$(stat -c '%u' "$probe")
        TARGET_GID=$(stat -c '%g' "$probe")
        break
    fi
done

CURRENT_UID=$(id -u builder)
CURRENT_GID=$(id -g builder)

if [ "$TARGET_UID" != "0" ] && \
   { [ "$TARGET_UID" != "$CURRENT_UID" ] || [ "$TARGET_GID" != "$CURRENT_GID" ]; }; then
    getent passwd "$TARGET_UID" >/dev/null \
        && userdel -f "$(getent passwd "$TARGET_UID" | cut -d: -f1)" || true
    getent group "$TARGET_GID" >/dev/null \
        && groupdel "$(getent group "$TARGET_GID" | cut -d: -f1)" 2>/dev/null || true

    groupmod -g "$TARGET_GID" builder
    usermod  -u "$TARGET_UID" -g "$TARGET_GID" builder

    chown -R "$TARGET_UID:$TARGET_GID" /home/builder /build
fi

if [ "$#" -eq 0 ]; then
    exec gosu builder /bin/bash -lc "/build/compile.sh --help"
fi

exec gosu builder "$@"
EOF

# Entrypoint runs as root so usermod/chown can remap; it drops to `builder`
# via gosu for every step. Image still documents builder as the effective
# user for any tooling that inspects metadata.
USER root
WORKDIR /build

HEALTHCHECK --interval=30s --timeout=10s --retries=2 \
    CMD test -x /build/compile.sh && gosu builder /build/compile.sh --help >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash", "-lc", "/build/compile.sh --help"]
