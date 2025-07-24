import Combine
import Foundation

/// Protocol for domain event handlers
public protocol DomainEventHandler {
    associatedtype Event: DomainEvent

    /// Handle the domain event
    func handle(_ event: Event) async

    /// Priority of this handler (higher values execute first)
    var priority: Int { get }
}

/// Default implementation of priority
public extension DomainEventHandler {
    var priority: Int { 0 }
}

/// Type-erased domain event handler
struct AnyDomainEventHandler: Sendable {
    let eventType: DomainEvent.Type
    let priority: Int
    let handle: @Sendable (DomainEvent) async -> Void

    init<Handler: DomainEventHandler & Sendable>(_ handler: Handler) {
        eventType = Handler.Event.self
        priority = handler.priority
        handle = { event in
            if let typedEvent = event as? Handler.Event {
                await handler.handle(typedEvent)
            }
        }
    }
}

/// Domain event dispatcher responsible for publishing events to handlers
public final class DomainEventDispatcher: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = DomainEventDispatcher()

    // MARK: - Properties

    private var handlers: [ObjectIdentifier: [AnyDomainEventHandler]] = [:]
    private let handlersQueue = DispatchQueue(label: "com.aiko.domain.events.handlers", attributes: .concurrent)

    private let eventSubject = PassthroughSubject<DomainEvent, Never>()
    public var eventPublisher: AnyPublisher<DomainEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Register a domain event handler
    public func register<Handler: DomainEventHandler & Sendable>(_ handler: Handler) {
        let typeId = ObjectIdentifier(Handler.Event.self)
        let anyHandler = AnyDomainEventHandler(handler)

        handlersQueue.async(flags: .barrier) {
            if self.handlers[typeId] != nil {
                self.handlers[typeId]?.append(anyHandler)
                // Sort by priority (descending)
                self.handlers[typeId]?.sort { $0.priority > $1.priority }
            } else {
                self.handlers[typeId] = [anyHandler]
            }
        }
    }

    /// Unregister all handlers for a specific event type
    public func unregisterAll(for eventType: (some DomainEvent).Type) {
        let typeId = ObjectIdentifier(eventType)

        handlersQueue.async(flags: .barrier) {
            self.handlers.removeValue(forKey: typeId)
        }
    }

    /// Clear all registered handlers
    public func clearAllHandlers() {
        handlersQueue.async(flags: .barrier) {
            self.handlers.removeAll()
        }
    }

    // MARK: - Dispatching

    /// Dispatch a domain event to all registered handlers
    public func dispatch(_ event: DomainEvent) async {
        // Publish to Combine subject
        eventSubject.send(event)

        // Get handlers for this event type
        let typeId = ObjectIdentifier(type(of: event))
        let eventHandlers = handlersQueue.sync {
            handlers[typeId] ?? []
        }

        // Execute handlers concurrently
        await withTaskGroup(of: Void.self) { group in
            for handler in eventHandlers {
                group.addTask {
                    await handler.handle(event)
                }
            }
        }
    }

    /// Dispatch multiple events
    public func dispatch(_ events: [DomainEvent]) async {
        for event in events {
            await dispatch(event)
        }
    }

    /// Dispatch events from an aggregate root
    public func dispatchFrom(_ aggregate: AggregateRoot<some Any>) async {
        let events = aggregate.pullDomainEvents()
        await dispatch(events)
    }
}

// MARK: - Convenience Methods

public extension DomainEventDispatcher {
    /// Register a closure-based handler
    func on<Event: DomainEvent>(
        _: Event.Type,
        priority: Int = 0,
        handler: @escaping @Sendable (Event) async -> Void
    ) {
        let closureHandler = ClosureEventHandler(priority: priority, handler: handler)
        register(closureHandler)
    }

    /// Register a synchronous closure-based handler
    func onSync<Event: DomainEvent>(
        _: Event.Type,
        priority: Int = 0,
        handler: @escaping @Sendable (Event) -> Void
    ) {
        let closureHandler = ClosureEventHandler<Event>(priority: priority) { event in
            handler(event)
        }
        register(closureHandler)
    }
}

// MARK: - Closure-based Event Handler

private struct ClosureEventHandler<Event: DomainEvent>: DomainEventHandler, Sendable {
    let priority: Int
    let handler: @Sendable (Event) async -> Void

    func handle(_ event: Event) async {
        await handler(event)
    }
}
