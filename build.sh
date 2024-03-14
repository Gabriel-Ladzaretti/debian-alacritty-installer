#!/bin/bash

docker build .

IMAGE_ID=$(docker images -q | awk '{print $1}' | awk 'NR==1')

mkdir ./tmp

# Create temporary container without starting it
docker create --name temp $IMAGE_ID

# Copy binary and related files
# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#post-build
docker cp temp:/alacritty/target/release/alacritty ./tmp/
docker cp temp:/alacritty/extra/logo/alacritty-term.svg ./tmp/Alacritty.svg
docker cp temp:/alacritty/extra/linux/Alacritty.desktop ./tmp/
docker cp temp:/alacritty/extra/alacritty.info ./tmp/

# Cleanup Docker assets
docker rm -f temp
docker rmi $IMAGE_ID

infocmp alacritty >/dev/null

read -s -p "Enter Password for sudo: " sudoPW

if [ $? -ne 0 ]; then
    echo $sudoPW | sudo -S tic -xe alacritty,alacritty-direct ./tmp/alacritty.info
fi

sudo cp ./tmp/alacritty /usr/local/bin
sudo cp ./tmp/Alacritty.svg /usr/share/pixmaps/Alacritty.svg
sudo desktop-file-install ./tmp/Alacritty.desktop
sudo update-desktop-database

rm -rf ./tmp
