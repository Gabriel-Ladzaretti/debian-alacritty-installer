#!/bin/bash

set -e

echo_err() {
    echo "$@" >&2
}

check_required_binaries() {
    local required_binaries=("docker" "desktop-file-install" "update-desktop-database" "tic")

    local missing_binary=false
    for binary in "${required_binaries[@]}"; do
        if ! command -v "$binary" &>/dev/null; then
            echo "Error: Required binary '$binary' not found in PATH. Please install it."
            missing_binary=true
        fi
    done

    if [ "$missing_binary" = true ]; then
        echo_err "Error: Missing required binaries; aborting..."
        exit 1
    fi
}

check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo_err "Error: This script requires sudo permissions. Please run it as root."
        exit 1
    fi
}

create_temp_dir() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    mkdir -p "$temp_dir"/{man,completions}
    echo "$temp_dir"
}

cleanup() {
    local temp_dir=$1
    echo "Removing temporary directory..."
    rm -rf "$temp_dir"
}

docker_build() {
    if ! docker build .; then
        echo_err "Error: Docker build failed, aborting..."
        exit 1
    fi

    image_id=$(docker images -q | awk '{print $1}' | awk 'NR==1')

    if [ -z "$image_id" ]; then
        echo_err "Error: could not retrive docker image id, aborting..."
    fi

    echo "$image_id"
}

create_temp_container() {
    container_name=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 10)
    docker create --name "$container_name" "$image_id"
    echo "$container_name"
}

copy_binary_and_assetts() {
    local container_name=$1

    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
    docker cp "$container_name":/alacritty/target/release/alacritty "$temp_dir"/
    docker cp "$container_name":/alacritty/extra/logo/alacritty-term.svg "$temp_dir"/Alacritty.svg
    docker cp "$container_name":/alacritty/extra/linux/Alacritty.desktop "$temp_dir"/
    docker cp "$container_name":/alacritty/extra/alacritty.info "$temp_dir"/
    docker cp "$container_name":/alacritty/extra/man "$temp_dir"/
    docker cp "$container_name":/alacritty/extra/completions "$temp_dir"/
}

cleanup_docker_assets() {
    local image_id=$1
    local container_name=$2
    docker rmi "$image_id"
    docker rm -f "$container_name"
}

install_to_term_info() {
    # Disable set -e temporarily
    set +e
    echo "Checking if Alacritty exists..."
    infocmp alacritty >/dev/null
    set -e

    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
        echo "Adding Alacritty terminfo"
        sudo tic -xe alacritty,alacritty-direct "$temp_dir"/alacritty.info
    fi
}

install_alacritty_to_desktop() {
    echo "Copying binary to /usr/local/bin..."
    sudo cp "$temp_dir"/alacritty /usr/local/bin

    echo "Copying Logo SVG to /usr/share/pixmaps/Alacritty.svg..."
    sudo cp "$temp_dir"/Alacritty.svg /usr/share/pixmaps/Alacritty.svg

    echo "Installing desktop file..."
    sudo desktop-file-install "$temp_dir"/Alacritty.desktop

    echo "Updating desktop database..."
    sudo update-desktop-database
}

install_alacritty_man_pages() {
    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#manual-page
    echo "Installing manual page entries"

    sudo mkdir -p /usr/local/share/man/man1
    sudo mkdir -p /usr/local/share/man/man5

    scdoc <"$temp_dir"/man/alacritty.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz >/dev/null
    scdoc <"$temp_dir"/man/alacritty-msg.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz >/dev/null
    scdoc <"$temp_dir"/man/alacritty.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz >/dev/null
    scdoc <"$temp_dir"/man/alacritty-bindings.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz >/dev/null
}

# Run script
check_sudo
check_required_binaries

echo "Creating temporary directory..."
temp_dir="$(create_temp_dir)"
echo "Temporary directory created at: $temp_dir"

trap 'cleanup "$temp_dir"' EXIT

echo "Building Docker image..."
image_id="$(docker_build)"

echo "Creating temporary container..."
container_name="$(create_temp_container)"

echo "Copying binary and assets from container..."
copy_binary_and_assetts "$container_name"

echo "Cleaning up Docker assets..."
cleanup_docker_assets "$image_id" "$container_name"

install_to_term_info
install_alacritty_to_desktop
install_alacritty_man_pages
