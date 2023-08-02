//
//  BasicGroupCallView.swift
//  GroupCallsDemo
//
//  Created by Joel Fischer on 24.03.23.
//

import GroupCalls
import SwiftUI

struct BasicGroupCallView: View {
    @State var isOpenView = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    let items = ["A", "B", "C", "D"]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
//                ForEach(0x1f600...0x1f679, id: \.self) { value in
//                    Text(String(format: "%x", value))
//                    Text(emoji(value))
//                        .font(.largeTitle)
//                }
                ForEach(items, id: \.self) { value in
                    Text("Hello \(value)")
                }
            }
        }
    }
    
    private func emoji(_ value: Int) -> String {
        guard let scalar = UnicodeScalar(value) else {
            return "?"
        }
        return String(Character(scalar))
    }
}

struct BasicGroupCallView_Previews: PreviewProvider {
    static var previews: some View {
        BasicGroupCallView()
    }
}
