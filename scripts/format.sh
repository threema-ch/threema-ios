set -euo pipefail

package_path="$1/scripts/format"

# https://github.com/nicklockwood/SwiftFormat#2-add-a-build-phases-to-your-app-target
SDKROOT=(xcrun --sdk macosx --show-sdk-path)
swift run -c release --package-path "$package_path" swiftformat "$@"
