#!/usr/bin/env bash

if [ "$#" -lt 2 ]
then
    echo "Usage:"
    echo "Args: $*"
    echo "path/to/build-scripts/build-rust.sh <CARGO_DIR> <FFI_TARGET>"
    exit 1
fi

# cargo dir
CARGO_DIR=$1
# what to pass to cargo build -p, e.g. saltyrtc-task-relayed-data-ffi
FFI_TARGET=$2

TOOLCHAIN_VERSION=1.63

set -euvx

# Install toochlain & targets

$HOME/.cargo/bin/rustup install $TOOLCHAIN_VERSION
$HOME/.cargo/bin/rustup target add --toolchain $TOOLCHAIN_VERSION aarch64-apple-ios aarch64-apple-ios-sim

# Build

cd "$CARGO_DIR"

$HOME/.cargo/bin/cargo +$TOOLCHAIN_VERSION build --locked -p $FFI_TARGET --lib --release --target aarch64-apple-ios
$HOME/.cargo/bin/cargo +$TOOLCHAIN_VERSION build --locked -p $FFI_TARGET --lib --release --target aarch64-apple-ios-sim
