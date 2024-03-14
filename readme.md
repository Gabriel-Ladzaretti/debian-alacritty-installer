# Alacritty Docker Builder

The `./build.sh` script builds Alacritty from source within a Docker container.

## Info

The build script clones the Alacritty repository and checks out the latest released version (`v0.13.1`).
It then builds Alacritty from source with the Wayland feature enabled, copies the binary to `%PATH`, and adds a desktop entry.

## Usage

1. Run the build script:

```bash
./build.sh
```
