//
//  BoringScreenSaverApp.swift
//  Boring Screen Saver
//
//  Created by Chris on 2025-12-02.
//

import SwiftUI

@main
struct BoringScreenSaverApp: App {
	@State private var userDataManager = UserDataManager().self
	
    var body: some Scene {
        WindowGroup {
            ContentView()
				.environment(userDataManager)
        }
    }
}
