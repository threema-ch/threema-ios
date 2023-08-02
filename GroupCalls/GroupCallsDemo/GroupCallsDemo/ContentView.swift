//
//  ContentView.swift
//  GroupCallsDemo
//
//  Created by Joel Fischer on 07.03.23.
//

import GroupCalls
import SwiftUI

struct ContentView: View {
    @State var isOpenView = false
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button("Start Call") {
                print("hello world")
                isOpenView = true
            }
            
            .sheet(isPresented: $isOpenView) {
                TestControllerView()
            }
        }
        .padding()
    }
}

struct TestControllerView: UIViewControllerRepresentable {

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }

    func makeUIViewController(context: Context) -> some UIViewController {

        let viewController = MyViewController()
    
        return viewController
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
