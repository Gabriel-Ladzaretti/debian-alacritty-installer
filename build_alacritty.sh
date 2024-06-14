#!/bin/bash

set -euo pipefail

export BINARY_DEPENDENCIES=("docker" "desktop-file-install" "update-desktop-database" "tic" "scdoc")
export IMAGE_TAG="alacritty_build:latest"
export CONTAINER_NAME="temp_build_container"

#######################################
# Ensures the script is run with sudo permissions.
# Globals:
#   EUID
# Arguments:
#   None
# Returns:
#   Exits with status 1 if not run as sudo.
#######################################
check_sudo() {
    echo "Checking for sudo permissions..."
    if [ "${EUID}" -ne 0 ]; then
        echo "Error: This script requires sudo permissions. Please run it as sudoer."
        exit 1
    fi
    echo "OK"
}

#######################################
# Checks for the presence of required binary dependencies.
# Globals:
#   BINARY_DEPENDENCIES
# Arguments:
#   None
# Returns:
#   Exits with status 1 if any binary is missing.
#######################################
check_dependencies() {
    echo "Checking for required binary dependencies..."
    local missing_binary=false

    for bin in "${BINARY_DEPENDENCIES[@]}"; do
        if ! command -v "${bin}" &>/dev/null; then
            echo "Error: Required binary '${bin}' not found in \$PATH. Please install it."
            missing_binary=true
        fi
    done

    if [ "${missing_binary}" = true ]; then
        echo "Error: Missing required binaries; aborting..."
        exit 1
    fi

    echo "OK"
}

#######################################
# Creates a temporary directory for storing build artifacts.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes the path of the created temporary directory to stdout.
# Returns:
#   The path to the created temporary directory.
#######################################
create_temp_dir() {
    echo "Creating temporary directory..."
    local temp_dir
    temp_dir="$(mktemp -d)"
    mkdir -p "${temp_dir}/man" "${temp_dir}/completions"
    echo "Temporary directory created at: ${temp_dir}"
}

#######################################
# Builds the Alacritty project from source using Docker.
# Globals:
#   IMAGE_TAG
#   CONTAINER_NAME
# Arguments:
#   None
# Returns:
#   Exits with status 1 if Docker build fails.
#######################################
build_alacritty_from_source() {
    echo "Building Alacritty from source..."

    local tag=${IMAGE_TAG}
    local name=${CONTAINER_NAME}

    if ! docker build -t "${tag}" .; then
        echo "Error: Docker build failed, aborting..."
        exit 1
    fi

    docker create --name "${name}" "${tag}"

    echo "Alacritty build complete."
}

#######################################
# Cleans up the temporary directory and Docker resources.
# Globals:
#   IMAGE_TAG
#   CONTAINER_NAME
# Arguments:
#   temp_dir: The path to the temporary directory to remove.
#######################################
cleanup() {
    echo "Cleaning up..."

    local temp_dir=$1
    local tag=${IMAGE_TAG}
    local name=${CONTAINER_NAME}

    echo "Removing temporary directory: ${temp_dir}"
    rm -rf "${temp_dir}"

    echo "Removing Docker container: ${name}"
    docker rm -f "${name}" && sleep 1

    echo "Removing Docker image: ${tag}"
    docker rmi "${tag}"

    echo "Cleanup complete."
}

#######################################
# Copies the built binary and assets from the Docker container.
# Globals:
#   CONTAINER_NAME
# Arguments:
#   dst_dir: The destination directory to copy the files to.
#######################################
copy_binary_and_assets() {
    echo "Copying binary and assets from container..."

    local dst_dir=$1
    local container_name=${CONTAINER_NAME}

    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
    docker cp "${container_name}:/alacritty/target/release/alacritty" "${dst_dir}/"
    docker cp "${container_name}:/alacritty/extra/logo/alacritty-term.svg" "${dst_dir}/Alacritty.svg"
    docker cp "${container_name}:/alacritty/extra/linux/Alacritty.desktop" "${dst_dir}/"
    docker cp "${container_name}:/alacritty/extra/alacritty.info" "${dst_dir}/"
    docker cp "${container_name}:/alacritty/extra/man" "${dst_dir}/"
    docker cp "${container_name}:/alacritty/extra/completions" "${dst_dir}/"

    echo "Binary and assets copied."
}

#######################################
# Installs Alacritty terminfo if it is not already installed.
# Globals:
#   None
# Arguments:
#   src_dir: The source directory containing the alacritty.info file.
#######################################
install_to_term_info() {
    echo "Installing Alacritty terminfo..."
    local src_dir=$1

    # Disable set -e temporarily
    set +e
    echo "Checking if Alacritty exists..."
    infocmp alacritty >/dev/null
    set -e

    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
        echo "Adding Alacritty terminfo"
        sudo tic -xe alacritty,alacritty-direct "${src_dir}/alacritty.info"
    fi

    echo "Terminfo installation complete."
}

#######################################
# Installs Alacritty to the desktop environment.
# Globals:
#   None
# Arguments:
#   src_dir: The source directory containing the Alacritty files.
#######################################
install_alacritty_to_desktop() {
    echo "Installing Alacritty to desktop environment..."
    local src_dir=$1

    echo "Copying binary to /usr/local/bin..."
    sudo cp "${src_dir}/alacritty" "/usr/local/bin"

    echo "Copying Logo SVG to /usr/share/pixmaps/Alacritty.svg..."
    sudo cp "${src_dir}/Alacritty.svg" /usr/share/pixmaps/Alacritty.svg

    echo "Installing desktop file..."
    sudo desktop-file-install "${src_dir}/Alacritty.desktop"

    echo "Updating desktop database..."
    sudo update-desktop-database

    echo "Desktop installation complete."
}

#######################################
# Installs Alacritty man pages.
# Globals:
#   None
# Arguments:
#   src_dir: The source directory containing the man page files.
#######################################
install_alacritty_man_pages() {
    echo "Installing Alacritty man pages..."
    local src_dir=$1

    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#manual-page

    sudo mkdir -p /usr/local/share/man/man1
    sudo mkdir -p /usr/local/share/man/man5

    scdoc <"${src_dir}/man/alacritty.1.scd" | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz >/dev/null
    scdoc <"${src_dir}/man/alacritty-msg.1.scd" | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz >/dev/null
    scdoc <"${src_dir}/man/alacritty.5.scd" | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz >/dev/null
    scdoc <"${src_dir}/man/alacritty-bindings.5.scd" | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz >/dev/null

    echo "Man pages installation complete."
}

# Main script execution
check_sudo
check_dependencies

echo "Creating temporary directory..."
temp_dir="$(create_temp_dir)"
echo "Temporary directory created at: ${temp_dir}"

trap 'cleanup "$temp_dir"' EXIT

echo "Building Alacritty from source..."
build_alacritty_from_source

echo "Copying binary and assets from container..."
copy_binary_and_assets "${temp_dir}"

install_to_term_info "${temp_dir}"
install_alacritty_to_desktop "${temp_dir}"
install_alacritty_man_pages "${temp_dir}"
