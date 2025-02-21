FROM rust:1.85.0-slim-bookworm

# renovate: datasource=github-releases depName=alacritty/alacritty
ARG ALACRITTY_VERSION=v0.15.1

RUN apt-get update && \
    apt-get -y install \
    cmake \
    pkg-config \
    libfreetype6-dev \
    libfontconfig1-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    python3 \
    git

RUN git clone -b ${ALACRITTY_VERSION} --depth 1 https://github.com/alacritty/alacritty.git

WORKDIR /alacritty

RUN cargo build --release --no-default-features --features=wayland