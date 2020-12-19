# Build WebRTC

### 1. Prerequisites

- A clone of [depot tools](https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up)

  ```sh
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
  ```
  
- At least 30 GB of free disk space

- Matching macOS and Xcode version (see _Versions_)

### 2a. Setup Fresh Build

1. Set path to depot tools (if not in your default path)

   ```sh
   export PATH=/path/to/depot_tools:$PATH
   ```

2. Choose and set WebRTC and patch commit to use (see _Versions_ below)

   ```sh
   export COMMIT=commit_id
   export PATCH_COMMIT=patch_commit_id
   
   # e.g.
   # export COMMIT=963cc1ef1336b52ca27742beb28bfbc211ed54d0
   # export PATCH_COMMIT=a57784d2f12b566cd79cd771d65b49a078841cca
   ```

3. Create a new folder and go into it

   ```sh
   mkdir WebRTC-build
   cd WebRTC-build
   ```

4. Fetch a regular WebRTC checkout with the iOS-specific parts added. (This might take a while...)

   ```sh
   fetch --nohooks webrtc_ios
   ```

5. Get patches

   ```sh
   git clone https://github.com/threema-ch/webrtc-build-docker.git
   cd webrtc-build-docker
   ```
   (The patches are part of our [WebRTC PeerConnection Build Script](https://github.com/threema-ch/webrtc-build-docker).)

### 2b. Setup Rebuild

1. Set path to depot tools (if not in your default path)

   ```sh
   export PATH=/path/to/depot_tools:$PATH
   ```

2. Choose and set WebRTC and patch commit to use (see _Versions_ below)

   ```sh
   export COMMIT=commit_id
   export PATCH_COMMIT=patch_commit_id
   ```

3. Reset applied patches
   
   ```sh
   cd WebRTC-build/src
   git reset --hard
   ```
   
4. Update patches

   ```sh
   cd ../webrtc-build-docker
   git checkout master && git pull origin master
   ```

### 3. Checkout and Apply Patches

1. Check out patch commit

   ```sh
   git checkout $PATCH_COMMIT
   ```
   
2. Go into src folder and checkout WebRTC. (This might take a while...)

   ```sh
   cd ../src
   git checkout master && git pull && git checkout $COMMIT && gclient sync
   ```

3. Apply patches

   ```sh
   for i in ../webrtc-build-docker/build/patches/*.patch; do patch -p1 < $i; done
   ```


### 4. Build

You can either build for release or debug. Debug is needed for the simulator.

#### Build for release

1. Build

   ```sh
   tools_webrtc/ios/build_ios_libs.py --bitcode --arch arm64 arm --output-dir ../out
   ```
2. Remove existing framework and move to correct location

   ```sh
   rm -r ../../WebRTC-release
   mkdir ../../WebRTC-release
   mv ../out/WebRTC.framework ../../WebRTC-release
   ```

#### Build for debug

1. Build

   ```sh
   tools_webrtc/ios/build_ios_libs.py --bitcode --arch arm64 arm x64 x86 --output-dir ../out
   ```
2. Remove existing framework and move to correct location

   ```sh
   rm -r ../../WebRTC-debug
   mkdir ../../WebRTC-debug
   mv ../out/WebRTC.framework ../../WebRTC-debug
   ```

### 5. Include in App Build

To ensure this version will be used in the app build, remove the existing chosen WebRTC build.

```sh
rm -r ../../WebRTC
```

## Versions

| iOS App Version | WebRTC Commit                                                | Patch Commit                                                 | macOS Version    | Xcode Version  | WebRTC Binary Version |
| --------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ---------------- | -------------- | --------------------- |
| 4.6.3 (2587)    | [963cc1ef1336b52ca27742beb28bfbc211ed54d0](https://chromium.googlesource.com/external/webrtc/+/963cc1ef1336b52ca27742beb28bfbc211ed54d0) (m84) | [a57784d2f12b566cd79cd771d65b49a078841cca](https://github.com/threema-ch/webrtc-build-docker/commit/a57784d2f12b566cd79cd771d65b49a078841cca) | 10.15.5 (19F101) | 11.5 (11E608c) | 84.1.1 |

