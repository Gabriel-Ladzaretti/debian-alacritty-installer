#!/bin/bash

set -e

echo "Building Docker image..."
docker build .

echo "Getting image ID..."
IMAGE_ID=$(docker images -q | awk '{print $1}' | awk 'NR==1')

echo "Creating temporary directory..."
mkdir ./tmp

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

# Disable set -e temporarily
set +e
echo "Checking if Alacritty exists..."
infocmp alacritty >/dev/null
set -e

if [ $? -ne 0 ]; then
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

# Cleanup Docker assets
echo "Cleaning up Docker assets..."
docker rm -f temp
docker rmi $IMAGE_ID

echo "Removing temporary directory..."
rm -rf ./tmp