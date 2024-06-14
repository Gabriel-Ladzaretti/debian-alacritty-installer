# Build Alacritty

The `./build_alacritty.sh` script builds Alacritty from source within a Docker container. It clones the Alacritty repository and checks out the latest released version. Then, it builds Alacritty from source with the Wayland feature enabled, copies the binary to `/usr/local/bin`, adds a desktop entry, and installs its manual pages.

## Requirements

1. Bash
1. Docker

## Usage

1. Run the build script:

    ```bash
    ./build_alacritty.sh
    ```
