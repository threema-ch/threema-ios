# TODOs

- Add metadata about platform and version?

# Data Backup Protocol

The Data Backup Protocol allows to create and restore encrypted, streamable,
incremental and validated backups across all platforms.

## Terminology

- `BRK`: The Backup Root Key
- `BPW`: The Backup Password
- `BLK`: The Backup Layout Key
- `BPK`: The Backup Page Key

## General Information

**Endianness:** All integers use little-endian encoding.

**Encryption cipher:** XChaCha-Poly1305

## Key derivation

<!-- TODO(LIB-48): Agree on password -->

All data backup keys are derived from the backup password `BP`. The `BP`
consists of 64 randomly sampled characters in `[0-9A-Z]` that must be safely
stored by the user.

<!--
TODO(LIB-48): Should we really include the `threema-id`?

I personally would not:

Pro:
- Bind threema-id to backup

Con:
- User has to know the threema-id.

Note:
- We should not rely on a threema-id as part of a filename as users expect them to be renamable.
 -->

    BRK = Blake2b(key=BPW, salt='r', personal='3ma-bup', input=<threema-id> || <salt>)
    BLK = Blake2b(key=BRK, salt='l', personal='3ma-bup')
    BPK = Blake2b(key=BRK, salt='p', personal='3ma-bup')

## Backup Storage Layer

### Local File

The following steps are defined as the _Storage Layer Allocation Steps_ for
destination _local file_:

1. Create a new `file` with name '<timestamp>-threema.backup'.
1. Create a new `data-backup.header` and write it to the beginning of the file.
1. Allocate space for `data-backup.layout-v1-encrypted` struct.

The following steps are defined as the _Storage Layer Data Appending Steps_ for
destination _local file_.

1. Let `encrypted-page` be the `data-backup.encrypted-page` that should be
   appended.
1. Append `encrypted-page` to `file`.

### Remote Backup Server

TODO(PRD-32)

## Protocol Flows

### Backup Creation

#### Page Allocation Steps

The following steps are defined as the _Page Allocation Steps_:

1. Let `category` be one of the data categories for which a page should be
   allocated.
1. Let `encrypted-page-size` be the encrypted page size for the given category:
   <!-- TODO(LIB-48): These numbers should be adapted after a carefully testing with existing data -->
   - past messages: 1 KiB,
   - essential data, hashed csp nonces, hashed d2m nonces: 2 KiB
   - blobs: 100 KiB
1. Set `next-page` to the current allocation offset advance the current
   allocation offset by `encrypted-page-size`.
1. Return `next-page`.

#### Page Writing Steps

The following steps are defined as the _Page Writing Steps_:

1. Let `data` be a list of encoded messages of the same category.
1. Let `reserved-page` be the page reserved for the type of `data`.¹
1. Join `data` to a single byte string, partition it to chunks each fitting into
   a single page and let `chunks` be the result.
1. For each `chunk` in `chunks`:
   1. If `chunk` is not the last chunk, run the _Page Allocation Steps_ and let
      `next-page` be the result.
   1. Create a `page` message with `chunk` and `next-page`, encrypt it and let
      `encrypted-page` be the result.
   1. If not all pages prior to `reserved-page` are marked as written: Add
      `encrypted-page` to the pending pages.
   1. If all pages prior to `reserved-page` are marked as written:
      1. Run the _Storage Layer Appending Steps_ with `encrypted-page`.
      1. Run the _Storage Layer Appending Steps_ for all pending pages directly
         following `reserved-page`.
   1. Set `reserved-page` to `next-page`.
1. Return `reserved-page`.

¹: These steps have been carefully crafted to handle interleaved page writes for
data of different types.

#### Essential Data Backup Steps

1. Run the _Page Allocation Steps_ and let `reserved-page` be the result.
1. Let `data` be the list of all referenced blobs encoded as
   `EssentialDataContainer.blob_data`.
1. Create the `EssentialDataContainer.essential_data` message and append it to
   `data`.
1. Run the _Page Writing Steps_.
1. Return `reserved-page`.

#### Common Nonce Backup Steps

1. Run the _Page Allocation Steps_ and let `reserved-page` be the result.
1. Let `data` be the list of all hashed nonces encoded as
   `hashed-nonce-container`.
1. Run the _Page Writing Steps_.
1. Return `reserved-page`.

#### Message Backup Steps

1. Let `past-messages` be the list of all past messages that should be included
   in the backup.
1. Let `blobs` and `past-message-containers` be empty lists.
1. For each `past-message` in `past-messages`:
   1. If `past-message` includes a blob:
      1. Let `blob-id` be a randomly sampled blob ID.
      1. Let `blob` be the `common.BlobData` with a random `blob-id` and omitted
         nonce and key.
      1. Add `blob` to `blobs`.
      1. Replace the blob in `past-message` with `blob-id` as reference.
1. Encode `past-message` as `variable-length-container` and add it to
   `past-message-containers`.
1. Run the _Page Allocation Steps_ and let `blob-position` be the result.
1. Run the _Page Writing Steps_ with `reserved-page` set to `blob-position` and
   `data` set to `blobs`.
1. Run the _Page Allocation Steps_ and let `past-messages-position` be the
   result.
1. Run the _Page Writing Steps_ with `reserved-page` set to
   `past-messages-position` and `data` set to `past-message-containers`.
1. Return `blob-position` and `past-messages-position`.

#### Backup Creation Abortion Steps

1. Let `error` be the cause of the abortion.
1. Delete all previously written data.
1. Log `error` and inform the user that the backup creation has failed.
1. Leave the _read-only_ mode.

#### Backup Creation Steps

The following steps define the process to create a data backup:

1. Retrieve `BPW` from the application storage. If it does not exist, randomly
   sample a new `BPW`, display it to the user and store it in the application
   storage.
1. Let `destination` be either _local file_ or _backup server_.
1. Let `salt` be 32 randomly generated bytes.
1. Derive `BRK`, `BLK`, and `BPK`.
1. Enter _read-only_ mode and inform the user that the backup creation is in
   progress.
1. Run the _Storage Layer Allocation Steps_. If this fails, run the _Backup
   Creation Abortion Steps_ and exceptionally abort these steps.
1. Run the _Essential Data Backup Steps_ and let `essential-data-position` be
   the result. If this fails, run the _Backup Creation Abortion Steps_ and
   exceptionally abort these steps.
1. Let `hashed-csp-nonces` be all hashed CSP nonces.
1. Run the _Common Nonce Backup Steps_ with `hashed-csp-nonces`. and let
   `hashed-csp-nonces-position` be the result. If this fails, run the _Backup
   Creation Abortion Steps_ and exceptionally abort these steps.
1. Let `hashed-d2m-nonces` be all hashed D2M nonces.
1. Run the _Common Nonce Backup Steps_ with `hashed-d2m-nonces` and let
   `hashed-d2m-nonces-position` be the result. If this fails, run the _Backup
   Creation Abortion Steps_ and exceptionally abort these steps.
1. Run the _Message Backup Steps_ and let `blob-position` and
   `past-message-position` be the result. If this fails, run the \_Backup
   Creation Abortion Steps and exceptionally abort these steps.
1. Let `delta-position` be the current allocation offset.
1. Create the `data-backup.header` struct and let `header` be the result.
1. Create the `data-backup.layout-v1-encrypted` struct and let `layout` be the
   result.
1. Run the _Storage Layer Metadata Write Steps_ with `header` and `layout`. If
   this fails, run the _Backup Creation Abortion Steps_ and exceptionally abort
   these steps.
1. Leave _read-only_ mode and inform the user that the backup creation
   succeeded.

### Backup Recovery

### Common Page Reading Steps

The following steps are defined as the _Common Page Reading Steps_:

1. Let `current-encrypted-page` be the page indicated to start reading.
1. Let `data` be an empty binary stream.
1. In a loop:
   1. Read and decrypt `current-encrypted-page` and let `current-page` be the
      result.
   1. Append `current-page.chunk` to `data`.
   1. If `current-page.continue-at` is _undefined_, abort the loop.
   1. Let `current-encrypted-page` be the page at position
      `current-page.continue-at`.
1. Let `containers` be the data parsed as containers and return `containers`.

#### Message Recovery Steps

1. Run the _Common Page Reading Steps_ with `current-encrypted-page` set to the
   beginning of blobs as indicated in the layout. Let `blob-containers` be the
   result.
1. Run the _Common Page Reading Steps_ with `current-encrypted-page` set to the
   beginning of past messages as indicated in the layout. Let
   `past-message-containers` be the result.
1. For each `past-message` in `past-message-containers`:
   1. If `past-message` references a blob:
      1. Let `blob-id` be the referenced blob ID.
      1. Let `blob` be the blob in `blob-containers` identified by `blob-id`.
      1. If `blob` is undefined, skip this message and continue with the next
         loop iteration.
      1. Replace the referenced blob with `blob`.
      1. Remove `blob` from `blob-containers`.
   1. Check that the contact/group/conversation corresponding to `past-message`
      exists. Otherwise skip this message and continue with the next loop
      iteration.
   1. If `past-message` is an outgoing group message and `sender` is not in the
      corresponding group, skip this message and continue with the next loop
      iteration.
   1. Add `past-message` to the applications storage.
1. If `blob-containers` is not empty, log a warning with the remaining blob IDs.

### Backup Recovery Steps

The following steps define the process to recover from a data backup.

1. Let `BPW` be the user-provided password.
   <!--TODO(LIB-78): Include threema-id? -->
1. Let `source` be either a local file or a backup server.
1. Read the `data-backup.header`.
1. If `version` is not supported by the application, exceptionally abort these
   steps.
1. Derive `BRK`, `BLK` and `BPK` from `BPW`.
1. Enter _read-only_ mode and inform user that recovery from backup is in
   progress.
1. Read and decrypt the `data-backup.layout-v1-encrypted`. If this fails,
   exceptionally abort these steps.

1. Run the _Common Page Reading Steps_ with `current-encrypted-page` set to the
   beginning of essential data as indicated in the layout. Let `containers` be
   the result.
1. For each `container` **except the last one** in `containers`:
   1. Decode the `container` as `common.BlobData` and store the blob
      temporarily.
1. Let `essential-data` be the last `container` decoded as `EssentialData`.
1. For each referenced profile picture in `essential-data`:
   1. Let `blob` be the temporarily stored blob with the same blob ID as the
      referenced one.
   1. If `blob` is undefined: Exceptionally abort these steps
   1. Replace the referenced profile picture with `blob` and remove `blob` from
      the temporary storage.
1. Add `essential-data` to the application storage.

1. Run the _Common Page Reading Steps_ with `current-encrypted-page` set to the
   beginning of hashed CSP nonces as indicated in the layout. Let `containers`
   be the result.
1. Parse all containers as hashed CSP nonces and add them to the application
   storage.

1. Run the _Message Recovery Steps_.
1. TODO(PRD-320): Recover delta updates.
1. Leave _read-only_ mode and inform the user that the backup recovery
   succeeded.
