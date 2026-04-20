import Combine

@propertyWrapper
public final class NotificationPublishedState<Value> {
    
    private var cancellables = Set<AnyCancellable>()
    private var subject = CurrentValueSubject<Value?, Never>(nil)

    public var wrappedValue: AnyNotificationPublisher<Value> {
        subject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public init(_ name: Notification.Name, on scheduler: some Scheduler = RunLoop.main)
        where Value == NotificationCenter.Publisher.Output {
        NotificationCenter.default.publisher(for: name)
            .receive(on: scheduler)
            .sink { [weak self] in
                self?.subject.send($0)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}
