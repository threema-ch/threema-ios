#!/usr/bin/env bash
#  _____ _
# |_   _| |_  _ _ ___ ___ _ __  __ _
#   | | | ' \| '_/ -_) -_) '  \/ _` |_
#   |_| |_||_|_| \___\___|_|_|_\__,_(_)
#
# Threema iOS Client
# Copyright (c) 2020 Threema GmbH
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

set -euo pipefail

if [[ $# = 0 ]]; then
  echo "Usage: ./build.sh [--dependencies | --dependencies-force | --generate-protobuf | [--build & --work]] [<relative project path>]"
  echo ""
  echo "Options to build the app and its dependencies:
  --dependencies                Download WebRTC if not cached.
                                
  --dependencies-force          Always download the most recent available version of WebRTC.
                                
  --generate-protobuf           Parse Protobuf files and generate Swift source code.
                                (https://github.com/apple/swift-protobuf/#alternatively-install-via-homebrew)

  --build                       Build debug version of target 'Threema'.
  --build --work                Build debug version of target 'Threema Work'.
  
  Example: ./build.sh --dependencies --build .."
  exit 0
fi

# Initialize project directory
if [[ $# -gt 0 ]] && [[ ${!#} != '--dependencies' ]] && [[ ${!#} != '--dependencies-force' ]] && [[ ${!#} != '--generate-protobuf' ]] && [[ ${!#} != '--build' ]] && [[ ${!#} != '--work' ]]; then
  project_dir="$PWD/${!#}"
else
  project_dir="$PWD"
fi
 
if [[ -d "$project_dir/Threema.xcodeproj/project.xcworkspace" ]]; then
  echo "Project $project_dir/Threema.xcodeproj/project.xcworkspace"
else
  echo "Project $project_dir/Threema.xcodeproj/project.xcworkspace not found"
  exit 1
fi

# Initialize script arguments
dependencies_arg=0
dependencies_force_arg=0
generate_protobuf_arg=0
build_arg=0
work_arg=0

for arg in "$@"; do
  if [[ "$arg" = '--dependencies' ]]; then
    dependencies_arg=1
  elif [[ "$arg" = '--dependencies-force' ]]; then
    dependencies_force_arg=1
  elif [[ "$arg" = '--generate-protobuf' ]]; then
    generate_protobuf_arg=1
  elif [[ "$arg" = '--build' ]]; then
    build_arg=1
  elif [[ "$arg" = '--work' ]]; then
    work_arg=1
  fi
done

if [[ "$dependencies_arg" = 1 ]] || [[ "$dependencies_force_arg" = 1 ]]; then
  # Delete or reset download directories
  # $1: Local directory
  reset() {
    if [[ -d "$project_dir/$1" ]]; then
      if  [[ "$dependencies_force_arg" = 1 ]]; then
        rm -R "$project_dir/$1"
      fi
    fi
  }

  download() {
    download_dir="$project_dir/$1"
    download_url="https://oss.threema.ch/ios/$2/$3/$1.zip"

    echo "$download_url -> $download_dir"

    mkdir "$download_dir"
    curl "$download_url" -o "$download_dir/$1.zip"
    unzip -q "$download_dir/$1.zip" -d "$download_dir"
    rm "$download_dir/$1.zip"
    touch "$download_dir"
  }

  # $1: Local directory
  # $2: Dependency name on oss
  # $3: Dependency version on oss
  check() {
    if [[ -d "$project_dir/$1" ]]; then
      if [[ "$dependencies_force_arg" = 1 ]]; then
        rm -R "$project_dir/$1"
        echo "Forcing dependency refresh, removing cache for $1"
      fi
    fi

    if [[ -d "$project_dir/$1" ]]; then
      echo "Cache found for $1"
    else
      download $1 $2 $3
    fi
  }
  
  reset "WebRTC.xcframework"
  check "WebRTC.xcframework" "webrtc" "114.0.0"

fi

if [[ "$generate_protobuf_arg" = 1 ]]; then
  protobuf_submodule_path="./protobuf"
  protobuf_source_path="./ThreemaFramework/Protobuf"
  
  protoc --version
  
  if [[ -d "$project_dir/$protobuf_submodule_path" ]]; then
    if [[ -d "$project_dir/$protobuf_source_path" ]]; then
      echo "Protobuf source path $project_dir/$protobuf_source_path"
    else
      mkdir "$project_dir/$protobuf_source_path"
    fi

    for file in "$project_dir/$protobuf_submodule_path"/*.proto
    do
      protoc  --swift_out="$protobuf_source_path" --proto_path="$protobuf_submodule_path" "$(basename -- "$file")"
    done
  fi
fi

if [[ "$build_arg" = 1 ]]; then
  if [[ "$work_arg" = 1 ]]; then
    scheme="Threema Work"
  else
    scheme="Threema"
  fi

  echo "Build $scheme"
  xcodebuild build -workspace "$project_dir/Threema.xcodeproj/project.xcworkspace" -scheme "$scheme" -configuration Debug -destination "generic/platform=iOS"
fi
