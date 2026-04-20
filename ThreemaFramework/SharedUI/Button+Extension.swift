import Foundation
import SwiftUI
import ThreemaMacros

public struct XMarkCancelButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) {
                action()
            }
        }
        else {
            Button(role: .cancel) {
                action()
            } label: {
                Label(#localize("Done"), systemImage: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.secondary)
            }
        }
    }
}

public struct DoneButton: View {
    private let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) {
                action()
            }
        }
        else {
            Button(#localize("Done")) {
                action()
            }
            .bold()
        }
    }
}

public struct CancelButton: View {
    private let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel) {
                action()
            }
        }
        else {
            Button(#localize("cancel")) {
                action()
            }
        }
    }
}

public struct CloseButton: View {
    private let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel) {
                action()
            }
        }
        else {
            Button(#localize("close")) {
                action()
            }
        }
    }
}

public struct SendButton: View {
    private let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(#localize("send"), systemImage: "arrow.up") {
                action()
            }
            .labelStyle(.iconOnly)
        }
        else {
            Button(#localize("send")) {
                action()
            }
        }
    }
}

public struct ConfirmationButton: View {
    private let title: String
    private let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .confirm) {
                action()
            }
        }
        else {
            Button(title) {
                action()
            }
        }
    }
}
