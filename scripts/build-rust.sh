#!/usr/bin/env bash

# This should be invoked from inside xcode, not manually
if [ "$#" -lt 3 ]
then
    echo "Usage (note: only call inside xcode!):"
    echo "Args: $*"
    echo "path/to/build-scripts/build-rust.sh <CARGO_DIR> <FFI_TARGET> <CONFIGURATION>"
    exit 1
fi

# cargo dir
CARGO_DIR=$1
# what to pass to cargo build -p, e.g. saltyrtc-task-relayed-data-ffi
FFI_TARGET=$2
# build configuration
CONFIGURATION=$3

TOOLCHAIN_VERSION=1.63

RELFLAG=
if [[ "$CONFIGURATION" != *"Debug"* ]]; then
    RELFLAG=--release
fi

set -euvx

# Install toochlain & targets

$HOME/.cargo/bin/rustup install $TOOLCHAIN_VERSION
$HOME/.cargo/bin/rustup target add --toolchain $TOOLCHAIN_VERSION aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Build dependency

if [[ -n "${DEVELOPER_SDK_DIR:-}" ]]; then
  # Assume we're in Xcode, which means we're probably cross-compiling.
  # In this case, we need to add an extra library search path for build scripts and proc-macros,
  # which run on the host instead of the target.
  # (macOS Big Sur does not have linkable libraries in /usr/lib/.)
  export LIBRARY_PATH="${DEVELOPER_SDK_DIR}/MacOSX.sdk/usr/lib:${LIBRARY_PATH:-}"
fi

env

IS_SIMULATOR=0
if [ "${LLVM_TARGET_TRIPLE_SUFFIX-}" = "-simulator" ]; then
  IS_SIMULATOR=1
fi

cd "$CARGO_DIR"

for arch in $ARCHS; do
  case "$arch" in
    x86_64)
      if [ $IS_SIMULATOR -eq 0 ]; then
        echo "Building for x86_64, but not a simulator build. What's going on?" >&2
        exit 2
      fi

      # Intel iOS simulator
      export CFLAGS_x86_64_apple_ios="-target x86_64-apple-ios"
      $HOME/.cargo/bin/cargo +$TOOLCHAIN_VERSION-x86_64-apple-darwin build -p $FFI_TARGET --lib $RELFLAG --target x86_64-apple-ios
      ;;

    arm64)
      if [ $IS_SIMULATOR -eq 0 ]; then
        # Hardware iOS targets
        $HOME/.cargo/bin/cargo +$TOOLCHAIN_VERSION build --locked -p $FFI_TARGET --lib $RELFLAG --target aarch64-apple-ios
      else
        # M1 iOS simulator
        $HOME/.cargo/bin/cargo +$TOOLCHAIN_VERSION build --locked -p $FFI_TARGET --lib $RELFLAG --target aarch64-apple-ios-sim
      fi
  esac
done
