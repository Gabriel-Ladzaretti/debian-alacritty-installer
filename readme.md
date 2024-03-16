# Alacritty Docker Builder

The ./build.sh script builds Alacritty from source within a Docker container. It clones the Alacritty repository and checks out the latest released version (v0.13.1), then builds Alacritty from source with the Wayland feature enabled, copies the binary to %PATH, and adds a desktop entry.

## Usecase

Provide an easy way to build the latest release from source for Linux distributions that provide an outdated binary through their package manager (e.g., Debian).

## Build

1. Run the build script:

    ```bash
    ./build.sh
    ```
