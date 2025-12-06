//
//  ContentView.swift
//  Screen Saver
//
//  Created by Chris on 2025-12-02.
//

// FIXME: Fix settings icon not actually being on-top (check ipad)
// FIXME: Attach the "Current Wallpaper" capsule to the preview window

// TODO: Add notifications at a glance (Stack and # of notifications)
// TODO: Add widgets??

import SwiftUI
import PhotosUI

private let WallpaperKey = "SavedWallpaperData"
private let WallpaperBlurKey = "SavedWallpaperBlur"
private let CustomTextKey = "SavedCustomText"
private let DimmingKey = "DimingSelectionTag"

struct ContentView: View {
	@State private var wallpaperImageData: Data? = UserDefaults.standard.data(forKey: WallpaperKey)
	
	@State private var wallpaperBlur: Double = UserDefaults.standard.double(forKey: WallpaperBlurKey) == 0.0 ? 20.0 : UserDefaults.standard.double(forKey: WallpaperBlurKey)
	
	@State private var customText: String = UserDefaults.standard.string(forKey: CustomTextKey) ?? "Boring Screen Saver"
	
	@State private var dimmingSelectionTag: Int = UserDefaults.standard.integer(forKey: DimmingKey) == 0 ? 1 : UserDefaults.standard.integer(forKey: DimmingKey)
	@State private var isDimmed: Bool = false
	@State private var dimmingTask: Task<Void, Never>? = nil
	
	@State private var isSettingsPresented = false
	
	// Defines the custom date format style: "Tue, Dec, 2"
	let customDateFormat: Date.FormatStyle = .dateTime
		.weekday(.abbreviated)
		.month(.abbreviated)
		.day(.defaultDigits)
		.locale(Locale.current) // Ensures localization is handled correctly
	
	private var dimTimeoutSeconds: Double {
		switch dimmingSelectionTag {
		case 1: return 5.0
		case 2: return 30.0
		case 3: return 5.0 * 60.0 // 5 Minutes
		case 4: return 10.0 * 60.0 // 10 Minutes
		case 5: return 30.0 * 60.0  // 30 Minutes
		case 6: return Double.infinity // Never
		default: return 5.0
		}
	}
	private func setupDimmingTimer() {
		dimmingTask?.cancel()
		
		
		withAnimation(.easeInOut(duration: 0.6)) {
			isDimmed = false
		}
		
		if dimmingSelectionTag != 6 && isSettingsPresented == false {
			let timeout = dimTimeoutSeconds
			dimmingTask = Task {
				do {
					try await Task.sleep(for: .seconds(timeout))
					
					await MainActor.run {
						if !Task.isCancelled {
							withAnimation(.easeInOut(duration: 1.5)) {
								self.isDimmed = true
							}
						}
					}
				} catch {
					print("Dimming timer cancelled.")
				}
			}
		}
	}
	
	private func savePersistence() {
		if let data = wallpaperImageData {
			UserDefaults.standard.set(data, forKey: WallpaperKey)
		} else {
			UserDefaults.standard.removeObject(forKey: WallpaperKey)
		}
		UserDefaults.standard.set(wallpaperBlur, forKey: WallpaperBlurKey)
		UserDefaults.standard.set(customText, forKey: CustomTextKey)
		UserDefaults.standard.set(dimmingSelectionTag, forKey: DimmingKey)
	}
	
    var body: some View {
		ZStack {
			Group {
				if let data = wallpaperImageData, let uiImage = UIImage(data: data) {
					Image(uiImage: uiImage)
						.resizable()
						.scaledToFill()
						.ignoresSafeArea(.all)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.blur(radius: wallpaperBlur)
						.opacity(isDimmed ? 0.6 : 1.0)
				}
			}
			VStack {
				Spacer()
				
				HStack {
					Spacer()
					
					Button(action: {
						if isDimmed {
							setupDimmingTimer()
							return
						}
						isSettingsPresented = true
					}) {
						Image(systemName: "gearshape.fill")
							.font(.title2)
							.padding(14)
							.foregroundColor(.white)
							.background(
								ZStack {
									Circle().fill(.ultraThinMaterial)
									Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
								}
							)
							.shadow(radius: 6)
							.opacity(isDimmed ? 0 : 1.0)
					}
					.padding(.trailing, 20)
				}
				.padding(.top, -30)
				
				TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
					VStack {
						Text(Date.now.formatted(customDateFormat))
							.font(.system(size: 25, weight: .semibold))
							.foregroundColor(.white.opacity(0.7))
							.opacity(isDimmed ? 0.8 : 1.0)
						
						Text(Date(), style: .time)
							.bold(true)
							.padding(1)
							.font(.system(size: 64, weight: .heavy))
							.shadow(radius: 10)
							.opacity(isDimmed ? 0.8 : 1.0)
						
						HStack {
							Spacer()
							Text(customText)
								.padding(5)
								.font(.caption)
								.opacity(isDimmed ? 0.6 : 0.7)
							Spacer()
						}
					}
					.foregroundColor(.white)
					.padding()
				}
				
				Spacer()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(.black)

		.onAppear {
			setupDimmingTimer()
		}
		.onChange(of: dimmingSelectionTag) { _ in
			savePersistence()
			setupDimmingTimer()
		}
		
		
		.onTapGesture {
			setupDimmingTimer()
		}
		.onLongPressGesture {
			isSettingsPresented = true
			setupDimmingTimer()
		}
		.sheet(isPresented: $isSettingsPresented) {
			SettingsView(
				wallpaperImageData: $wallpaperImageData,
				wallpaperBlur: $wallpaperBlur,
				customText: $customText,
				dimmingSelectionTag: $dimmingSelectionTag,
				isPresented: $isSettingsPresented
			)
		}
		
		.onChange(of: isSettingsPresented) { isPresented in
			setupDimmingTimer()
			savePersistence()
		}
    }
}

struct SettingsView: View {
	@Binding var wallpaperImageData: Data?
	@Binding var wallpaperBlur: Double
	@Binding var customText: String
	@Binding var dimmingSelectionTag: Int
	
	@Binding var isPresented: Bool
	
	var body: some View {
		NavigationStack {
			VStack(alignment: .leading) {
				List {
					Section(header: Text("Appearance").font(.headline)) {
						
						// Wallpaper Option
						NavigationLink(destination: WallpaperSelector(wallpaperImageData: $wallpaperImageData, isPresented: $isPresented)) {
							HStack {
								Image(systemName: "photo.stack")
									.frame(width: 20, height: 20)
									.padding(5)
									.background(
										RoundedRectangle(cornerRadius: 10)
											.fill(.ultraThinMaterial)
									)
									.foregroundColor(.primary)
								Text("Wallpaper")
								Spacer()
							}
						}
						
						// Wallpaper Blur Option
						Group {
							VStack(alignment: .leading) {
								HStack {
									Image(systemName: "circle.bottomrighthalf.pattern.checkered")
										.frame(width: 20, height: 20)
										.padding(5)
										.background(
											RoundedRectangle(cornerRadius: 10)
												.fill(.ultraThinMaterial)
										)
									Text("Wallpaper Blur")
									Spacer()
								}
								
								Slider(value: $wallpaperBlur, in: 0...50, step: 1) {
									Text("Blur Radius")
								} minimumValueLabel: {
									Text("0")
								} maximumValueLabel: {
									Text("\(Int(wallpaperBlur))")
								}
								.padding(.horizontal)
							}
						}
						
						// Custom Text Option
						HStack {
							Image(systemName: "textformat")
								.frame(width: 20, height: 20)
								.padding(5)
								.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
								.foregroundColor(.primary)
							Text("Custom Text")
							Spacer()
							TextField("Custom Text", text: $customText)
								.multilineTextAlignment(.trailing)
								.textInputAutocapitalization(.never)
								.disableAutocorrection(true)
						}
					}
					
					
					Section(header: Text("Behavior").font(.headline)) {
						
						// Dim Screen Option
						HStack {
							Image(systemName: "sun.max.fill")
								.frame(width: 20, height: 20)
								.padding(5)
								.background(
									RoundedRectangle(cornerRadius: 10)
										.fill(.ultraThinMaterial)
								)
								.foregroundColor(.primary)
							Picker(selection: $dimmingSelectionTag, label: Text("Dim Screen after...")) {
								Text("5 Seconds").tag(1)
								Text("30 Seconds").tag(2)
								Text("5 Minutes").tag(3)
								Text("10 Minutes").tag(4)
								Text("30 Minutes").tag(5)
								Text("Never").tag(6)
							}
						}
					}
				}
				
				Spacer()
				HStack {
					Spacer()
					Text("Crowned Studios. 2025")
						.padding()
						.font(.caption)
						.opacity(0.7)
					Spacer()
				}
				
				.navigationTitle("Boring Settings")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(action: {
							isPresented = false
						}) {
							Image(systemName: "chevron.backward")
						}
					}
				}
			}
		}
	}
}

struct WallpaperSelector: View {
	@Binding var wallpaperImageData: Data?
	
	@Binding var isPresented: Bool
	
	var pickerConfiguration = PHPickerConfiguration(photoLibrary: .shared())
	var photoFilter = PHPickerFilter.any(of: [.livePhotos, .images, .videos])
	
	@State private var selectedItem: PhotosPickerItem? = nil
	@State private var selectedImage: Image? = nil
	
	var body: some View {
		VStack {
			if selectedImage != nil {
				ZStack {
					selectedImage!
						.resizable()
						.scaledToFill()
						.frame(maxWidth: 700)
						.frame(height: 200)
						.cornerRadius(10)
						.clipped()
						.shadow(radius: 5)
					
					Text("Current Wallpaper")
						.font(.caption.weight(.semibold))
						.foregroundColor(.white)
						.padding(.vertical, 8)
						.padding(.horizontal, 12)
						.background(
							Capsule().fill(.ultraThinMaterial)
						)
						.cornerRadius(10)
						.padding(10)
						.position(x: 100, y: 30)
				}
				.padding(.horizontal, 20)
				.padding(.top, -20)
			}
			
			PhotosPicker(
				selection: $selectedItem,
				matching: .images,
			) {
				Text("Use Photos Library")
					.padding()
			}
			.buttonStyle(.borderedProminent)
			.onChange(of: selectedItem) {
				newItem in guard let item = newItem else {
					return
				}
				Task {
					if let data = try? await item.loadTransferable(type: Data.self) {
						wallpaperImageData = data
						
						if let uiImage = UIImage(data: data) {
							selectedImage = Image(uiImage: uiImage)
						}
					}
				}
			}
			
			Button("Reset to default") {
				wallpaperImageData = nil
				selectedImage = nil
			}
			.buttonStyle(.bordered)
			
			Spacer()
		}
		.padding(.top, 40)
		.navigationTitle("Wallpaper")
		.navigationBarTitleDisplayMode(.inline)
		
		.onAppear {
			if let data = wallpaperImageData, let uiImage = UIImage(data: data) {
				selectedImage = Image(uiImage: uiImage)
			}
		}
	}
}

#Preview {
    ContentView()
}
