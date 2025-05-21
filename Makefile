#  _____ _
# |_   _| |_  _ _ ___ ___ _ __  __ _
#   | | | ' \| '_/ -_) -_) '  \/ _` |_
#   |_| |_||_|_| \___\___|_|_|_\__,_(_)
#
# Threema iOS Client
# Copyright (c) 2025 Threema GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

#-- General commands --#

.PHONY: all
all: dependencies

.PHONY: clean
clean: dependencies-clean

#- Setup -#

.PHONY: setup
setup:
	brew install --quiet protobuf
	brew upgrade --quiet rustup

.PHONY: setup-rust
setup-rust:
	brew install --quiet rustup
	rustup-init

#- Dependencies -#

.PHONY: dependencies
dependencies: update-submodules WebRTC SaltyRTC libthreema-all

.PHONY: dependencies-clean
dependencies-clean: WebRTC-clean SaltyRTC-clean libthreema-clean

#- Submodules -#

.PHONY: update-submodules
update-submodules:
	-git submodule update --init --recursive

#- Format -#

.PHONY: format
format:
	./scripts/format.sh .

#-- WebRTC --#

.PHONY: WebRTC
WebRTC:
	@./scripts/build.sh --dependencies .

.PHONY: WebRTC-clean
WebRTC-clean:
	-@rm -r WebRTC.xcframework

#-- Rust --#

# We only support Apple Silicon Macs
# Darwin target is needed to run tests on macOS
rust_targets = aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim

#- libthreema -#

libthreema_path = libthreema
libthreema_swift_path = libthreemaSwift
libthreema_xcframework_file = $(libthreema_swift_path)/libthreema.xcframework
libthreema_generated_swift_file = $(libthreema_swift_path)/Sources/libthreemaSwift/Generated/libthreema.swift

# If you are offline this might not work. Use `libthreema` instead.
.PHONY: libthreema-all
libthreema-all: libthreema-rust libthreema

# Notes:
# - If we would set a build folder inside a Swift Package used in Xcode it will reload multiple times during a build
# - The UniFFI generator formats the Swift file by default. Our scripts disables this because we also change the APIs 
#   with our formattter (e.g. Id -> ID) and this might break our bindings in the future. If official support is added 
#   to fix Swift capitalization conventions in the future we should consider to enable them 
#   (https://github.com/mozilla/uniffi-rs/issues/2276)
.PHONY: libthreema
libthreema:
	@# Add xcrun such that it can also be called from a build script phase
	@xcrun --sdk macosx ./scripts/BuildRustLibrary/Sources/BuildRustLibraryScript/main.swift \
		libthreema \
		--library-path $(libthreema_path) \
		--framework-out-file-path $(libthreema_xcframework_file) \
		--swift-out-file-path $(libthreema_generated_swift_file) \
		--targets $(rust_targets)

.PHONY: libthreema-rust
libthreema-rust:
	@# This picks up the `libthreema/rust-toolchain.toml` file to install the correct toolchain version
	@cd $(libthreema_path); rustup toolchain install
	@cd $(libthreema_path); rustup target add $(rust_targets)

.PHONY: libthreema-clean
libthreema-clean:
	cd $(libthreema_path); cargo clean
	-@rm -r $(libthreema_path)/build
	-@rm -r $(libthreema_xcframework_file)
	-@rm $(libthreema_generated_swift_file)

#- SaltyRTC -#

# This is a basic port to the Makefile to remove the build step that added around 0.7s to each build

saltyRTC_path = saltyrtc-task-relayed-data-rs/ffi/
saltyRTC_ffi_target = saltyrtc-task-relayed-data-ffi

.PHONY: SaltyRTC
SaltyRTC: 
	@/bin/bash scripts/build-rust.sh $(saltyRTC_path) $(saltyRTC_ffi_target)

.PHONY: SaltyRTC-clean
SaltyRTC-clean:
	cd $(saltyRTC_path); cargo clean
