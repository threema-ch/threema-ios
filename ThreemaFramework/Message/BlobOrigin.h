#import <Foundation/Foundation.h>

/// Defines endpoint of upload/download blob resource.
///
/// Blob origin logic for file (group) messages (request:origin), if Multi Device activated:
///
/// ```
/// Device Group A                    | |                    Device Group B
/// ----------------------------------| |----------------------------------
/// File message                      | |
///        ┌────────┐ upload:public   | | download:public ┌────────┐
/// Leader │Device 1│––––––––––––––––→| |←–––––––––––––––→│Device 1│ Leader
///        └────────┘                 | | done:public     └────────┘
///                                   | |
///        ┌────────┐ download:local  |B| download:public ┌────────┐
///        │Device 2│←–––––––––––––––→|L|←–––––––––––––––→│Device 2│
///        └────────┘ done:local      |O| done:public     └────────┘
///                                   |B|
/// ----------------------------------| |----------------------------------
/// Group file message                |M|
///        ┌────────┐ upload:public * |I| download:public ┌────────┐
/// Leader │Device 1│––––––––––––––––→|R|←–––––––––––––––→│Device 1│ Leader
///        └────────┘                 |R| done:local      └────────┘
///                                   |O|
///        ┌────────┐ download:local  |R| download:public ┌────────┐
///        │Device 2│←–––––––––––––––→| |←–––––––––––––––→│Device 2│
///        └────────┘ done:local      | | done:local      └────────┘
///                                   | |
/// ```
/// * If group is a note group, we upload with origin local, since we are the only ones that download the blob anyways.
///
/// The origin of deprecated message types, `AudioMessageEntity`, `ImageMessageEntity` and `VideoMessageEntity`
/// are always `public`, because they will never be reflected as outgoing message! In new version this types will
/// send/reflected as `FileMessageEntity`.
typedef NS_ENUM(NSInteger, BlobOrigin) {
    BlobOriginPublic = 0,
    BlobOriginLocal = 1,
};
