#!/bin/bash

set -e

echo "Creating temporary directory..."
temp_dir=$(mktemp -d)
mkdir -p $temp_dir/{man,completions}
echo "Temporary directory path: $temp_dir"

echo "Building Docker image..."
docker build .

echo "Getting image ID..."
image_id=$(docker images -q | awk '{print $1}' | awk 'NR==1')
echo "Image id: $image_id"

echo "Creating temporary container..."
container_name=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 10)
docker create --name $container_name $image_id

# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
echo "Copying binary and assets from container..."
docker cp $container_name:/alacritty/target/release/alacritty $temp_dir/
docker cp $container_name:/alacritty/extra/logo/alacritty-term.svg $temp_dir/Alacritty.svg
docker cp $container_name:/alacritty/extra/linux/Alacritty.desktop $temp_dir/
docker cp $container_name:/alacritty/extra/alacritty.info $temp_dir/
docker cp $container_name:/alacritty/extra/man $temp_dir/man
docker cp $container_name:/alacritty/extra/completions $temp_dir/completions

echo "Cleaning up Docker assets..."
docker rm -f $container_name
docker rmi $image_id

# Disable set -e temporarily
set +e
echo "Checking if Alacritty exists..."
infocmp alacritty >/dev/null
set -e

exit_code=$?
if [ $exit_code -ne 0 ]; then
    # https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
    echo "Adding Alacritty terminfo"
    sudo -S tic -xe alacritty,alacritty-direct $temp_dir/alacritty.info
fi

read -s -p "Enter Password for sudo: " password

echo "Copying binary to /usr/local/bin..."
echo "$password" | sudo cp $temp_dir/alacritty /usr/local/bin

echo "Copying Logo SVG to /usr/share/pixmaps/Alacritty.svg..."
sudo cp $temp_dir/Alacritty.svg /usr/share/pixmaps/Alacritty.svg

echo "Installing desktop file..."
sudo desktop-file-install $temp_dir/Alacritty.desktop

echo "Updating desktop database..."
sudo update-desktop-database

# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#manual-page
if command -v gzip &>/dev/null && command -v scdoc &>/dev/null; then
    echo "Installing manual page entries"

    sudo mkdir -p /usr/local/share/man/man1
    sudo mkdir -p /usr/local/share/man/man5

    scdoc <$temp_dir/man/alacritty.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty.1.gz >/dev/null
    scdoc <$temp_dir/man/alacritty-msg.1.scd | gzip -c | sudo tee /usr/local/share/man/man1/alacritty-msg.1.gz >/dev/null
    scdoc <$temp_dir/man/alacritty.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty.5.gz >/dev/null
    scdoc <$temp_dir/man/alacritty-bindings.5.scd | gzip -c | sudo tee /usr/local/share/man/man5/alacritty-bindings.5.gz >/dev/null
else
    echo "WARNING: Both gzip and scdoc are required for installing manual page entries; skipping"
fi

echo "Removing temporary directory..."
rm -rf $temp_dir
