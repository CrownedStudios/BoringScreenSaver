//
//  ContentView.swift
//  Screen Saver
//
//  Created by Chris on 2025-12-02.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
	@State private var wallpaperImageData: Data? = nil
	
	@State private var customText: String = "Boring Text Here"
	
	@State private var isSettingsPresented = false
	
	let customDateFormat: Date.FormatStyle = .dateTime
		.weekday(.abbreviated)
		.month(.abbreviated)
		.day(.defaultDigits)
		.locale(Locale.current) // Ensures localization is handled correctly
	
    var body: some View {
		ZStack {
			Group {
				if let data = wallpaperImageData, let uiImage = UIImage(data: data) {
					Image(uiImage: uiImage)
						.resizable()
						.scaledToFill()
						.ignoresSafeArea(.all)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.blur(radius: 20)
				} else {
					Image("WallpaperFallback")
						.resizable()
						.scaledToFill()
						.ignoresSafeArea(.all)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.blur(radius: 20)
				}
			}
			VStack {
				HStack {
					Spacer()
					
					Button(action: {
						isSettingsPresented = true
					}) {
						Image(systemName: "gearshape.fill")
							.font(.title2)
							.padding(15)
							.foregroundColor(.white)
							.background(
								ZStack {
									Circle().fill(.ultraThinMaterial)
									Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
								}
							)
							.shadow(radius: 6)
					}
					.padding(.trailing, 50)
				}
				.padding(.top, 70)
				
				VStack {
					Text(Date.now.formatted(customDateFormat))
						.font(.system(size: 25, weight: .semibold))
						.foregroundColor(.white.opacity(0.7))
					
					Text(Date(), style: .time)
						.bold(true)
						.padding(1)
						.font(.system(size: 64, weight: .heavy))
						.shadow(radius: 10)
					
					HStack {
						Spacer()
						Text(customText)
							.padding(5)
							.font(.caption)
							.opacity(0.7)
						Spacer()
					}
				}
				.foregroundColor(.white)
				.padding()
				
				Spacer()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(.black)
		.ignoresSafeArea(.all)
		
		.onLongPressGesture {
			isSettingsPresented = true
		}
		.sheet(isPresented: $isSettingsPresented) {
			SettingsView(wallpaperImageData: $wallpaperImageData, customText: $customText, isPresented: $isSettingsPresented)
		}
    }
}

struct SettingsView: View {
	@Binding var wallpaperImageData: Data?
	
	@Binding var customText: String
	
	@Binding var isPresented: Bool
	
	var body: some View {
		NavigationStack {
			VStack(alignment: .leading) {
				List {
					Section(header: Text("Appearance").font(.headline)) {
						NavigationLink(destination: WallpaperSelector(wallpaperImageData: $wallpaperImageData, isPresented: $isPresented)) {
							HStack {
								Text("Wallpaper")
								Spacer()
							}
						}
						HStack {
							Text("Custom Text")
							Spacer()
							TextField("Custom Text", text: $customText)
								.multilineTextAlignment(.trailing)
								.textInputAutocapitalization(.never)
								.disableAutocorrection(true)
						}
					}
					
					Section(header: Text("Behavior").font(.headline)) {
						Picker(selection: .constant(6), label: Text("Dim Text after...")) {
							Text("5 Seconds").tag(1)
							Text("30 Seconds").tag(2)
							Text("5 Minutes").tag(3)
							Text("10 Minutes").tag(4)
							Text("30 Minutes").tag(5)
							Text("Never").tag(6)
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
	
//	init(wallpaperImage: Binding<Image?>, isPresented: Binding<Bool>) {
//		self._isPresented = isPresented
//		self._wallpaperImageData = wallpaperImageData
//		pickerConfiguration.filter = photoFilter
//		pickerConfiguration.preferredAssetRepresentationMode = .current
//		pickerConfiguration.selection = .default
//	}
	
	var body: some View {
		VStack {
			Text("Select Your Wallpaper Source")
				.font(.title2)
				.padding(.bottom, 20)
			
			if let image = selectedImage {
				image
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 200)
					.cornerRadius(10)
					.padding(.bottom, 16)
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
			
			Button("Use Solid Color") {
					// Future implementation: Color picker logic
			}
			.padding()
			.buttonStyle(.bordered)
			
			Spacer()
		}
		.padding(.top, 40)
		.navigationTitle("Wallpaper")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
    ContentView()
}
