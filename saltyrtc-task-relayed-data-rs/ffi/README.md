## Building

To build the crate, simply run `cargo build` or `cargo build --release`.

If you want to skip the generation of the C headers, set the env variable
`SKIP_CBINDGEN=1` before building.

### iOS

To build for iOS, install `cargo-lipo`:

    $ cargo install -f cargo-lipo
    $ # 64 bit targets (real device & simulator):
    $ rustup target add aarch64-apple-ios x86_64-apple-ios
    $ # 32 bit targets
    $ rustup target add armv7-apple-ios i386-apple-ios

Then run

    $ cargo lipo --release


## C Example

To see a C usage example, please take a look at `tests/integration.c`.


## Testing

### Rust tests

Simply run `cargo test`.

Note: The integration tests currently require a `saltyrtc.der` test CA
certificate in the root directory of the repository.

### C tests

The C tests are built using meson / ninja. They are run automatically when
calling `cargo test`.

Dependencies:

- meson
- ninja
- valgrind

If you want to build the tests manually, in the root directory, type:

    $ CC=clang meson build
    $ cd build
    $ ln -s path/to/saltyrtc.der
    $ ninja

(Note: You can also build the tests with gcc, but then you'll get less diagnostics.)
