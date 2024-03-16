#!/bin/bash

set -e

echo "Building Docker image..."
docker build .

echo "Getting image ID..."
IMAGE_ID=$(docker images -q | awk '{print $1}' | awk 'NR==1')

echo "Creating temporary directory..."
mkdir ./tmp
mkdir ./tmp/man
mkdir ./tmp/completions

# Create temporary container without starting it
echo "Creating temporary container..."
docker create --name temp $IMAGE_ID

# Copy binary and related files
# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
echo "Copying files from container..."
docker cp temp:/alacritty/target/release/alacritty ./tmp/
docker cp temp:/alacritty/extra/logo/alacritty-term.svg ./tmp/Alacritty.svg
docker cp temp:/alacritty/extra/linux/Alacritty.desktop ./tmp/
docker cp temp:/alacritty/extra/alacritty.info ./tmp/
docker cp temp:/alacritty/extra/man ./tmp/man
docker cp temp:/alacritty/extra/completions ./tmp/completions

# Disable set -e temporarily
set +e
echo "Checking if Alacritty exists..."
infocmp alacritty >/dev/null
set -e

exitCode=$?
if [ exitCode -ne 0 ]; then
    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
    echo "Adding Alacritty terminfo"
    sudo -S tic -xe alacritty,alacritty-direct ./tmp/alacritty.info
fi

read -s -p "Enter Password for sudo: " password

echo "Copying binary to /usr/local/bin..."
echo $password | sudo cp ./tmp/alacritty /usr/local/bin

echo "Copying Logo SVG to /usr/share/pixmaps/Alacritty.svg..."
sudo cp ./tmp/Alacritty.svg /usr/share/pixmaps/Alacritty.svg

echo "Installing desktop file..."
sudo desktop-file-install ./tmp/Alacritty.desktop

echo "Updating desktop database..."
sudo update-desktop-database

# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#manual-page
if command -v gzip &>/dev/null && command -v scdoc &>/dev/null; then
    echo "Installing manual page entries"

    sudo mkdir -p /usr/local/share/man/man1
    sudo mkdir -p /usr/local/share/man/man5
    
    scdoc <extra/man/alacritty.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz >/dev/null
    scdoc <extra/man/alacritty-msg.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz >/dev/null
    scdoc <extra/man/alacritty.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz >/dev/null
    scdoc <extra/man/alacritty-bindings.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz >/dev/null
else
    echo "WARNING: Both gzip and scdoc are required for installing manual page entries; skipping"
fi

# Cleanup Docker assets
echo "Cleaning up Docker assets..."
docker rm -f temp
docker rmi $IMAGE_ID

echo "Removing temporary directory..."
rm -rf ./tmp
