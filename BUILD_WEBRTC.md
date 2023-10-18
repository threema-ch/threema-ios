# Build WebRTC

### 1. Prerequisites

- At least 30 GB of free disk space

- Matching macOS and Xcode version (see _Versions_)

### 2a. Setup Fresh Build

1. Change to your iOS-Project folder
   ```sh
   cd /path/to/your/ios-project
   ```
2. Create a new folder and go into it

   ```sh
   mkdir WebRTC-build
   cd WebRTC-build
   ```

3. Clone [depot tools](https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up) and add them to your current [`PATH`](<https://en.wikipedia.org/wiki/PATH_(variable)#Unix_and_Unix-like>)

   ```sh
   git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
   export PATH=$(PWD)/depot_tools:$PATH
   ```

4. Choose and set WebRTC and patch commit to use (see _Versions_ below)

   ```sh
   export COMMIT=commit_id
   export PATCH_COMMIT=patch_commit_id

   # e.g.
   # export COMMIT=b83487f08ff836437715b488f73416215e5570dd
   # export PATCH_COMMIT=e8c6ee36392fb167a96d9c808f6d4638510c3178
   ```

5. Fetch a regular WebRTC checkout with the iOS-specific parts added. (This might take a while...)

   ```sh
   fetch --nohooks webrtc_ios
   ```

6. Get patches

   ```sh
   git clone https://github.com/threema-ch/webrtc-build-docker.git
   cd webrtc-build-docker
   ```

   (The patches are part of our [WebRTC PeerConnection Build Script](https://github.com/threema-ch/webrtc-build-docker).)

### 2b. Setup Rebuild

1. Reset applied patches

   ```sh
   cd WebRTC-build/src
   git reset --hard
   ```

2. Add depot_tools to your current `PATH`

   ```sh
   export PATH=$(PWD)/depot_tools:$PATH
   ```

3. Choose and set WebRTC and patch commit to use (see _Versions_ below)

   ```sh
   export COMMIT=commit_id
   export PATCH_COMMIT=patch_commit_id
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
   for i in ../webrtc-build-docker/patches/*.patch; do patch -p1 < $i; done
   ```

### 4. Build

1. Build

   ```sh
   tools_webrtc/ios/build_ios_libs.py --output-dir ../out/
   ```

2. Remove existing framework and move to correct location

   ```sh
   rm -r ../../WebRTC.xcframework
   mv ../out/WebRTC.xcframework ../../

   ```

### 5. (Optional) Remove temporary build folder WebRTC-build

```sh
cd ../..
rm -r WebRTC-build
```

## Versions

| iOS App Version    | WebRTC Commit                                                                                                                                     | Patch Commit                                                                                                                                   | macOS Version           | Xcode Version   | WebRTC Binary Version |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | --------------- | --------------------- |
| 5.6 | [151be743d4c83671565f9c1eada3f4a0b2e44dea](https://chromium.googlesource.com/external/webrtc/+/151be743d4c83671565f9c1eada3f4a0b2e44dea) (m114) | [07bf304f62e536217dad166ca9a603cad9d61e7e](https://github.com/threema-ch/webrtc-build-docker/commit/07bf304f62e536217dad166ca9a603cad9d61e7e) | 13.5 (22G74) | 14.3.1 (14E300c)    | 1140.0                 |
| Group-Calls-Branch | [218b56e516386cd57c7513197528c3124bcd7ef3](https://chromium.googlesource.com/external/webrtc/+/218b56e516386cd57c7513197528c3124bcd7ef3) (m110) | [d49a6318dbb90665684c9d6cda083416912d5086](https://github.com/threema-ch/webrtc-build-docker/commit/d49a6318dbb90665684c9d6cda083416912d5086) | 13.3.1 (a) (22E772610a) | 14.2 (14C18)    | 110.0                 |
| 4.8.0 (2741)       | [ffd9187dc0d9211ad52173bf0daa5001ca7d45ee](https://chromium.googlesource.com/external/webrtc/+/ffd9187dc0d9211ad52173bf0daa5001ca7d45ee) (m100)   | [92e9bfefac342b2c2547cd860844f9bf7fd36252](https://github.com/threema-ch/webrtc-build-docker/commit/92e9bfefac342b2c2547cd860844f9bf7fd36252)  | 12.4 (21F79)            | 13.2.1 (13C100) | 100.0.0               |
