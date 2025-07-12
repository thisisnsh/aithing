//
//  AppContext.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import Foundation

class AppContext: ObservableObject {
    @Published var appName: String = ""
    @Published var visibleText: String = ""
}
