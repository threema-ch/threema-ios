# libthreemaSwift

Provides access to `libthreema` implemented in Rust. (`libthreema` provides different functionalities shared between all Threema Chat apps in one library)

- Wraps `libthreema` (Rust) using autogenerated [UniFFI](https://mozilla.github.io/uniffi-rs/) Swift interface
- Might add more wrappers to make autogenerated interface nicer to use (e.g. interfaces with wrong capitalizations (e.g. ID or URL))

## libthreema Development Workflow

### Local Changes

If you want to make any local changes to `libthreema`:

1. Make changes in `libthreema`
2. Run `make libthreema`
3. Adapt calls in Xcode project if needed
4. Build & run in Xcode

### Update

After a `libthreema` update (e.g. after pulling the most recent version):

- Run `make libthreema-all` (this also ensures that the Rust toolchain & targets are correctly updated)