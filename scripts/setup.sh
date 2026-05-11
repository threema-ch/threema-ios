#!/bin/bash
set -euo pipefail

# Navigate to project root regardless of where script is run from
cd "$(dirname "$0")/.."

# Ensure the active developer dir points to Xcode.app (not the standalone CLT).
# A fresh Xcode install often leaves xcode-select pointed at /Library/Developer/CommandLineTools,
# which is not sufficient for building this project.
XCODE_DEVELOPER_DIR=$(xcode-select -p)
XCODE_APP=$(echo "$XCODE_DEVELOPER_DIR" | sed 's|\(.*\.app\).*|\1|')

if [ ! -d "$XCODE_APP" ]; then
    XCODE_APP="/Applications/Xcode.app"
    if [ ! -d "$XCODE_APP" ]; then
        echo "Error: $XCODE_APP not found. Install Xcode from the App Store before running this script." >&2
        exit 1
    fi
    echo "xcode-select points to $XCODE_DEVELOPER_DIR; switching to $XCODE_APP (sudo required)..."
    sudo xcode-select --switch "$XCODE_APP"
fi

# Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# A fresh Homebrew install is not yet on PATH, so locate it at its known prefix.
 if ! command -v brew &>/dev/null; then
     if [ -x /opt/homebrew/bin/brew ]; then
         eval "$(/opt/homebrew/bin/brew shellenv)"
     else
         echo "Error: Homebrew installed but 'brew' could not be located on PATH." >&2
         exit 1
     fi
 fi

# Install mise if not installed
if ! command -v mise &>/dev/null; then
    echo "Installing mise..."
    brew install mise

    # Ensure mise is on PATH for this session
    if ! command -v mise &>/dev/null; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# Activate mise in current shell
eval "$(mise activate bash)"

# Install tools defined in mise.toml
echo "Installing mise tools..."
mise install

mise run setup-rust
mise run setup
mise run dependencies

echo "Setup complete."
