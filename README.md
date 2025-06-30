<div align="center">
  <!-- Centered README header hack -->
  <img width="400" src="logo.svg">
  <br><br>
</div>

# Threema for iOS

[This repository](https://github.com/threema-ch/threema-ios) contains the complete source code of [Threema](https://threema.com/) for iOS.

## Table of Contents

- [Bug Reports / Feature Requests / Security Issues](#issues)
- [Source Code Release Policy](#release-policy)
- [License Checks](#license-checks)
- [Schemes](#schemes)
- [Building](#building)
- [Testing](#testing)
- [Reproducible Builds](#reproducible-builds)
- [Code Organization / Architecture](#architecture)
- [Contributions](#contributions)
- [License](#license)


## <a name="issues"></a>Bug Reports / Feature Requests / Security Issues

To report bugs and request new features, please contact the [Threema support team](https://threema.com/support).

If you discover a security issue in Threema, please adhere to the coordinated vulnerability disclosure model. To be eligible for a bug bounty, please [file a report on GObugfree](https://app.gobugfree.com/programs/threema) (where all the details, including the bounty levels, are listed). If you're not interested in the bug bounty program, you can contact us via Threema or by email; for contact details, see [threema.com/contact](https://threema.com/en/contact) (section "Security").


## <a name="release-policy"></a>Source Code Release Policy

This source code repository will be updated for every public non-beta release. There will be one commit per released version.

Commits are signed using PGP. See [SECURITY.md](SECURITY.md) for more information.


## <a name="license-checks"></a>License Checks

While the source code for Threema for iOS is published under an open source license, Threema is still a paid app. To run the app in combination with our official server infrastructure, you must have bought a license on the App Store.

The app uses three different license check types, depending on the target app:

### App Store Licensing

When creating a new Threema ID using the Threema app bought on the [App Store](https://apps.apple.com/gw/app/threema/id578665578), the app sends the digitally signed App Store receipt to the directory server. This allows the server to verify that you have indeed bought the app, without being able to identify you.

This means that a self-compiled app using the `Threema` scheme cannot be used to create a new Threema ID. You can, however, use an app that was purchased in the App Store to create an ID and then export a backup. This backup can then be imported into the self-compiled app.

Note that the ID creation endpoint is monitored for abuse.

### Threema Work

If you build the Threema Work target, credentials from the [Threema Work](https://work.threema.com/) subscription must be provided in order to use the app.

### Threema OnPrem

If you build the Threema OnPrem target, credentials from the [Threema OnPrem](https://threema.com/onprem/) subscription must be provided in order to use the app.

## <a name="schemes"></a>Schemes

- `Threema` builds and tests the consumer app. (recommended for local testing)
- `Threema Work` builds and tests the enterprise version of our app.
- `Threema OnPrem` builds and tests the OnPrem version of our app.
- `Threema Green` is only used for development and testing within Threema.
- `Threema Blue` is only used for development and testing within Threema.

## <a name="building"></a>Building

To get started you need a [Mac](https://www.apple.com/mac/), [Xcode](https://developer.apple.com/xcode/) (16.3+) and a (free) [Apple Developer Account](https://developer.apple.com/programs/).

### 1. Install & Build Dependencies

1. If your Xcode installation is fresh make sure that command line tools are selected

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app
   ```

2. Install the third-party tools needed to build our Rust dependencies

   1. If you don't have Rust, install & set it up using [Rustup](https://rustup.rs)

      ```sh
      make setup-rust
      ```

      (You might want to add `$HOME/.cargo/bin` to your `PATH`.)

   2. Install the other tools needed

      ```sh
      make setup
      ```

   (If you don't have [homebrew](https://brew.sh) see their [official install instructions](https://brew.sh).)

3. Download, install and build all dependencies (you want to rerun this if you update the repository)

   ```sh
   make dependencies
   ```

   Besides building our Rust dependencies, this downloads the `WebRTC.xcframework` if it is missing. (If you want to build WebRTC yourself see [BUILD_WEBRTC.md](BUILD_WEBRTC.md).)

To uninstall the dependencies you can run `make dependencies-clean`.

### 2. Setup Project

You can either build the Threema app (recommended) or Threema Work app.

_Note_: These setups are for running in the simulator.

#### Threema (recommended)

1. Open `Threema.xcproject` in Xcode
2. Repeat these steps for the `Threema` and `Threema ShareExtension` target
   1. Check "Automatically manage signing" and confirm it ("Enable Automatic")
   2. Set "Team" to the team of your developer account
3. Choose `Threema` as scheme and a simulator

#### Threema Work

1. Open `Threema.xcproject` in Xcode
2. Repeat these steps for the `Threema Work` and `Threema Work ShareExtension` target
   1. Check "Automatically manage signing" and confirm it ("Enable Automatic")
   2. Set "Team" to the team of your developer account
3. Choose `Threema Work` as scheme and a simulator

### 3. Build and Run

1. Build and Run
2. To create a Threema ID see "App Store Licensing" above. (You can cancel the "Sign in with Apple ID" dialog and import a Threema ID backup.)


## <a name="testing"></a>Testing

See "Building" for setting up a running environment. Before running the tests check if you can sucessfully build and run the app.

- Choose `Threema` as scheme to run the app tests.
- Choose `ThreemaFramework` as scheme to run the framework tests.
- Choose `Threema Work` as scheme to run Threema Work specific tests.


## <a name="reproducible-builds"></a>Reproducible Builds

Due to restrictions by Apple, it’s no easy task to offer reproducible builds for iOS, but we are currently evaluating possible ways to also support reproducible builds for this platform.


## <a name="architecture"></a>Code Organization / Architecture

Before digging into the codebase, you should read the [Cryptography Whitepaper](https://threema.com/press-files/2_documentation/cryptography_whitepaper.pdf) to understand the design concepts.

These are the most important groups of the Xcode project:

- `ThreemaFramework`: Shared code between the main app and extensions
- `Threema`: Code of both apps (Threema and Threema Work)
- `Threema ShareExtension`: Code of share extension
- `Threema{Framework}Tests`: Test files
- `GroupCalls`: Code of group calls

Our dependencies are managed with Swift Package Manager. Additionally we use WebRTC based on binaries hosted on our servers. If you want to build WebRTC yourself see [BUILD_WEBRTC.md](BUILD_WEBRTC.md).


## <a name="contributions"></a>Contributions

We accept GitHub pull requests. Please refer to <https://threema.com/open-source/contributions> for more information on how to contribute.


## <a name="license"></a>License

Threema for iOS is licensed under the GNU Affero General Public License v3.


    Copyright (c) 2012-2025 Threema GmbH
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License, version 3,
    as published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.

The full license text can be found in [`LICENSE.txt`](LICENSE.txt).

If you have questions about the use of self-compiled apps or the license in general, feel free to [contact us](mailto:opensource@threema.ch). We are publishing the source code in good faith, with transparency being the main goal. By having users pay for the development of the app, we can ensure that our goals sustainably align with the goals of our users: Great privacy and security, no ads, no collection of user data!
