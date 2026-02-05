//
//  BoringScreenSaverApp.swift
//  Boring Screen Saver
//
//  Created by Chris on 2025-12-02.
//  Copyright © 2026 CrownedStudios. All rights reserved.
//

import SwiftUI
import TipKit

@main
struct BoringScreenSaverApp: App {
	@State private var userDataManager = UserDataManager()
	
    var body: some Scene {
		#if os(macOS)
		Window("Boring Screen Saver", id: "boringscreensaver_main") {
			ContentView()
				.environment(userDataManager)
				.onOpenURL { url in
					Task { @MainActor in
						userDataManager.handleExternalImport([url])
					}
				}
				.task {
					do {
						try Tips.configure()
					}
					catch {
						print("Failed to configure Tips: \(error.localizedDescription)")
					}
				}
		}
		.handlesExternalEvents(matching: Set(["*"]))
		#else
			WindowGroup {
				ContentView()
					.environment(userDataManager)
					.onOpenURL { url in
						Task { @MainActor in
							userDataManager.handleExternalImport([url])
						}
					}
					.task {
						do {
							try Tips.configure()
						}
						catch {
							print("Failed to configure Tips: \(error.localizedDescription)")
						}
					}
			}
			.handlesExternalEvents(matching: Set(["*"]))
		#endif
        }
    }
