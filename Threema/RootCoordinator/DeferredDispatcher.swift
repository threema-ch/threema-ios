/// Buffers callbacks for a not-yet-available handler, then replays them in receipt order
/// once a handler is attached.
@MainActor
final class DeferredDispatcher<Handler: AnyObject> {

    private weak var target: Handler?
    private var pending: [(Handler) -> Void] = []

    /// Install the real handler and drain queued calls in receipt order.
    /// Calling twice replaces the target; the queue is drained against the new target.
    func attach(_ handler: Handler) {
        target = handler
        let queued = pending
        pending.removeAll()
        for forward in queued {
            forward(handler)
        }
    }

    func detach() {
        target = nil
    }

    /// Forward immediately if attached, otherwise queue until the next ``attach(_:)``.
    func dispatch(_ forward: @escaping (Handler) -> Void) {
        if let target {
            forward(target)
        }
        else {
            pending.append(forward)
        }
    }
}
