# AudioSessionManager

One owner for the process-wide audio session.

iOS gives a process a single `AVAudioSession`. This package makes exactly one type responsible for it.
Clients never configure a session — they **acquire a claim** describing what they need, and the manager
resolves competing claims by priority and applies the winner once.

```swift
let claim = try await audioSessionManager.acquire(.playback)
// … play …
await audioSessionManager.release(claim)
```

Two consequences worth knowing before you write anything:

- **A lower-priority claim is granted but subordinate.** Playing a voice message during a call still plays; it
  simply does not reconfigure the session. You do not need to check whether a call is active.
- **With no claims the manager is passive.** It asserts nothing.

---

## Getting the manager

In the app, take it from the injector. Never build your own — one process, one owner.

```swift
final class MyPlayer {
    private let audioSessionManager: any AudioSessionManagerProtocol

    init(audioSessionManager: any AudioSessionManagerProtocol = BusinessInjector.ui.audioSessionManager) {
        self.audioSessionManager = audioSessionManager
    }
}
```

Depend on `AudioSessionManagerProtocol`, not on the concrete type — that is what lets a test hand you a
double. `AudioSessionManagerFactory.make()` in `AudioSessionManagerRTC` is the only way to construct one, and
`BusinessInjector` has already called it.

Packages that cannot see `BusinessInjector` take the manager as an init parameter instead (`GroupCalls` does
this through its `Dependencies`).

---

## Client kinds

`acquire` takes a kind, never a configuration. The kind decides the category, mode and options — that table
lives in exactly one place, so a mismatched pair is unrepresentable.

| Kind | For | Session |
|---|---|---|
| `.ambient` | shutter mute, anything that must never interrupt | `.ambient` |
| `.playback` | voice messages (follows the proximity sensor) | `.playback` / `.spokenAudio` |
| `.mediaPlayback` | video | `.playback` / `.moviePlayback` |
| `.speech` | text to speech | `.playback` / `.voicePrompt` |
| `.recording` | voice message recording | `.playAndRecord` / `.spokenAudio` |
| `.call` | 1:1 calls (CallKit activates) | `.playAndRecord` / `.voiceChat` |
| `.groupCall` | group calls (the driver activates) | `.playAndRecord` / `.voiceChat` |

Priority is `.ambient` < the three playback kinds < `.recording` < the two call kinds. The playback kinds share
a rank: they differ in *mode*, not in who should win, so between them the most recent claim wins.

**If no kind fits what you need, add one** — do not configure at the call site. A new kind is a reviewable
change in one file; a call site that configures is how the previous design rotted.

---

## Acquiring, updating, releasing

### Name the route when you know it

```swift
let claim = try await audioSessionManager.acquire(.call, output: speakerActive ? .speaker : .system)
```

`AudioSessionOutput` is `.system` (whatever iOS selects), `.speaker`, or `.receiver` (the earpiece, for a
client following the proximity sensor). Passing it to `acquire` costs one apply; acquiring and then calling
`update` costs two, and at the start of a call the second is audible.

`acquire(_:)` without an output is shorthand for `.system`.

### Change the route later

```swift
await audioSessionManager.update(claim, output: .receiver)
```

A no-op while your claim is subordinate — it records what you want, and takes effect if you become the winner.

### Give it back

```swift
await audioSessionManager.release(claim)
```

**Release is yours to order.** A claim is a value with no `deinit`; nothing releases it for you. Acquire and
release in the same type, at symmetric points in its lifecycle, and add a `deinit` backstop for teardown paths
that can be skipped:

```swift
deinit {
    // Copied into locals: the Task outlives this object, so it must not capture `self`.
    guard let claim = audioSessionClaim else { return }
    let manager = audioSessionManager

    Task { await manager.release(claim) }
}
```

Releasing an unknown or already-released claim does nothing, so teardown paths that may run twice need no
bookkeeping of their own.

### The one refusal

```swift
do {
    claim = try await audioSessionManager.acquire(.recording)
}
catch AudioSessionError.busyWithCall {
    // A call owns the microphone. This is the authoritative check — the manager knows about claims you cannot see.
}
```

`.recording` is the only kind that can be refused, and only while a call holds a claim. Every other kind is
granted, possibly as a subordinate.

---

## Events

Subscribe with the claim you hold. The stream finishes when you release it.

```swift
eventTask = Task { [weak self, manager = audioSessionManager] in
    for await event in await manager.events(for: claim) {
        switch event {
        case .interrupted, .subordinated:
            await self?.stopCapturing()
        case .interruptionEnded, .outputRouteChanged:
            continue
        }
    }
}
```

| Event | Means |
|---|---|
| `.interrupted` | the system took the session — an alarm, a cellular call, Siri |
| `.interruptionEnded(shouldResume:)` | it gave it back. The manager has already restored the winning claim; you only restart your own playback or capture |
| `.subordinated` | **you** lost the session to a higher-priority claim, and still hold yours. Delivered to that one claim only |
| `.outputRouteChanged(reason:route:)` | the route moved. The manager has re-asserted what your claim asked for; answer only if the new device should change what you *want* |

`.subordinated` is the one that is easy to miss and expensive to ignore: losing is silent, because the session
is simply reconfigured for the winner. A recorder that ignores it keeps a running timer over a recording that
stopped.

Capture `self` weakly in that loop. The task is usually stored on `self`, so a `guard let self` above the loop
is a reference cycle — and what it strands is the `deinit` that releases your claim.

---

## Reading the route

```swift
let route = await audioSessionManager.currentRoute()
route.outputs           // [AVAudioSession.Port]
route.hasBluetoothInput // a headset may be available while audio is still on the speaker
```

Use this when you have to *decide* on a route — following the proximity sensor only matters while audio is on
a built-in port. `hasBluetoothInput` is not derivable from `outputs`, which is why it is carried separately.

`diagnostics()` returns a one-line description of the live session for logs, including WebRTC's activation
flags when a call owns it.

---

## The rule

**Never touch `AVAudioSession` or `RTCAudioSession` directly.** Reads included — only a driver may touch a
session, which is what makes route-dependent behaviour testable. A SwiftLint rule enforces this
(`.swiftlint.yml`, run by `mise run lint`); a violation means the thing you want belongs on the manager.

---

## Testing

Two doubles, in `AudioSessionManagerTestHelper`. Pick by what you are testing.

**`AudioSessionManagerTestFactory.make()`** — the **real** manager over a mock driver. Arbitration is real:
subordination, the `busyWithCall` refusal, tie-breaking. Use it whenever the behaviour under test derives its
meaning from arbitration.

```swift
let driver = MockAudioSessionDriver()
let manager = AudioSessionManagerTestFactory.make(defaultDriver: driver)

_ = try await manager.acquire(.call)
await #expect(throws: AudioSessionError.busyWithCall) {
    _ = try await manager.acquire(.recording)
}
```

**`MockAudioSessionManager`** — a recording stub for a client's own logic: that it acquires at the right
moment, releases on every teardown path, follows the proximity sensor.

```swift
let manager = MockAudioSessionManager()
manager.setRoute(outputs: [.builtInReceiver])

let player = MyPlayer(audioSessionManager: manager)
await player.start()

#expect(manager.outstandingKinds == [.playback])
manager.send(.subordinated)   // drive an event
```

It **grants everything**. It does not subordinate and does not refuse, so it will make a test pass wherever
production would have refused — use the real manager for those paths.

Assert at claim level (`outstandingKinds`, `calls`), not on categories or modes. A profile is not your
contract; it belongs to `AudioSessionClientKind` and will move when a kind is added.

Run the package's own tests with no signing step and no device:

```bash
cd AudioSessionManager
xcodebuild test -scheme AudioSessionManager -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Products

| Product | Contains | Link it if |
|---|---|---|
| `AudioSessionManager` | the claim model, the protocol, the value types | you hold a claim |
| `AudioSessionManagerRTC` | `AudioSessionManagerFactory` | you construct the manager (composition root only) |
| `AudioSessionManagerTestHelper` | the two doubles | you are a test target |
| `WebRTC` | the binary target, vended for other packages | you need WebRTC |

`AudioSessionManager` has no WebRTC dependency, which is why its tests run without a codesign step.

Design rationale — why claims rather than configuration, why the driver seam, the CallKit contract, the
interruption handling — is in [`Audio-Session-Package.md`](../Audio-Session-Package.md) at the repository root.
