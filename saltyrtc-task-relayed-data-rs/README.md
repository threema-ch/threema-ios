# SaltyRTC Relayed Data Task

[![CircleCI][circle-ci-badge]][circle-ci]
[![Join our chat on Gitter](https://badges.gitter.im/saltyrtc/Lobby.svg)](https://gitter.im/saltyrtc/Lobby)

> :warning: **Note:** The SaltyRTC client libraries are in maintenance mode.
> They will still receive bugfixes and regular maintenance, but if you want to
> start using these libraries, be prepared that you will need to take over
> maintenance at some point in time. (If you are interested in maintaining the
> libraries, please let us know, our e-mails are in the README, section
> "Security".)


## Testing

### Unit Tests

Prerequisites:

* You need to install `valgrind` and `splint`
* The integration tests currently require a `saltyrtc.der` test CA
  certificate in the root directory of the repository.

To run the testsuite:

    cargo test


## Msgpack Debugging

If you enable the `msgpack-debugging` compile flag, you'll get direct msgpack
analysis URLs for all decoded messages in your `TRACE` level logs.

    cargo build --features 'msgpack-debugging'

You can customize that URL prefix at compile time using the `MSGPACK_DEBUG_URL`
env var. This is the default URL:

    MSGPACK_DEBUG_URL='https://msgpack.dbrgn.ch/#base64='


## Release Signatures

Release commits and tags are signed with the
[Threema signing key](https://keybase.io/threema)
(`E7ADD9914E260E8B35DFB50665FDE935573ACDA6`).


## Security

### Coordinated Disclosure / Reporting Security Issues

Please report security issues directly to one or both of the following contacts:

- Danilo Bargen
    - Email: mail@dbrgn.ch
    - Threema: EBEP4UCA
    - GPG: [EA456E8BAF0109429583EED83578F667F2F3A5FA][keybase-dbrgn]
- Lennart Grahl
    - Email: lennart.grahl@gmail.com
    - Threema: MSFVEW6C
    - GPG: [3FDB14868A2B36D638F3C495F98FBED10482ABA6][keybase-lgrahl]

[keybase-dbrgn]: https://keybase.io/dbrgn
[keybase-lgrahl]: https://keybase.io/lgrahl


## License

Licensed under either of

 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT) at your option.

### Contributing

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.


<!-- Badges -->
[circle-ci]: https://circleci.com/gh/saltyrtc/saltyrtc-task-relayed-data-rs/tree/master
[circle-ci-badge]: https://circleci.com/gh/saltyrtc/saltyrtc-task-relayed-data-rs/tree/master.svg?style=shield
