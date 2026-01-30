//
//  ContentView.swift
//  Boring Screen Saver
//
//  Created by Chris on 2025-12-02.
//

// TODO: Add notifications at a glance (Stack and # of notifications)
// TODO: Add widgets??

import SwiftUI
import PhotosUI
import AVFoundation

import Observation
import Combine

import CoreLocation
import MapKit

#if canImport(UIKit)
	import UIKit
#endif
#if canImport(AppKit)
	import AppKit
#endif

// [ ENUMS ]

enum WallpaperType {
	case video, image, none
}

// [ PERSISTENCE KEYS ]

private let WallpaperFileNameKey = "SavedWallpaperFileName"
private let WallpaperBlurKey = "SavedWallpaperBlur"
private let WallpaperOpacityKey = "SavedWallpaperOpacity"
private let CustomTextKey = "SavedCustomText"
private let DimmingKey = "DimingSelectionTag"

// [ OBSERVABLE CLASSES ]

@Observable
class UserDataManager {
	// Variables
	
	var wallpaperURL: URL? {
		didSet { save(wallpaperURL?.lastPathComponent, key: WallpaperFileNameKey) }
	}
	var wallpaperBlur: Double = 20.0 {
		didSet { save(wallpaperBlur, key: WallpaperBlurKey) }
	}
	var wallpaperOpacity: Double = 0.4 {
		didSet { save(wallpaperOpacity, key: WallpaperOpacityKey) }
	}
	
	var customText: String = "Boring Screen Saver" {
		didSet { save(customText, key: CustomTextKey) }
	}
	var showDate: Bool = true {
		didSet { save(showDate, key: "ShowDate") }
	}
	var showBattery: Bool = true {
		didSet { save(showBattery, key: "ShowBattery") }
	}
	var is24HourTime: Bool = false {
		didSet { save(is24HourTime, key: "Is24HourTime") }
	}
	
	var dimmingSelectionTag: Int = 1 {
		didSet { save(dimmingSelectionTag, key: DimmingKey) }
	}
	
	var fetchCityAuto: Bool = false {
		didSet { save(fetchCityAuto, key: "FetchCityAuto") }
	}
	var cityName: String = "Toronto" {
		didSet { save(cityName, key: "SavedCityName") }
	}
	var lastLat: Double = 43.6548 {
		didSet { save(lastLat, key: "SavedLat") }
	}
	var lastLon: Double = 79.3884 {
		didSet { save(lastLon, key: "SavedLon") }
	}
	
	// Types
	
	var wallpaperType: WallpaperType {
		guard let url = wallpaperURL else { return .none }
		let videoExtensions = ["mov", "mp4", "avi", "wmv", "m4v"]
		return videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .image
	}
	
	var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = is24HourTime ? "HH:mm" : "h:mm a"
		return formatter
	}
	
	// Init
	
	init() {
		let defaults = UserDefaults.standard
		
		if let fileName = defaults.string(forKey: WallpaperFileNameKey) {
			let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
			if FileManager.default.fileExists(atPath: fileURL.path) { self.wallpaperURL = fileURL }
		}
		
		self.customText = defaults.string(forKey: CustomTextKey) ?? "Boring Screen Saver"
		self.cityName = defaults.string(forKey: "SavedCityName") ?? "Toronto"
		
		self.dimmingSelectionTag = defaults.integer(forKey: DimmingKey) == 0 ? 1 : defaults.integer(forKey: DimmingKey)
		
		self.lastLat = defaults.double(forKey: "SavedLat") == 0 ? 43.6548 : defaults.double(forKey: "SavedLat")
		self.lastLon = defaults.double(forKey: "SavedLon") == 0 ? 79.3884 : defaults.double(forKey: "SavedLon")
		self.wallpaperBlur = defaults.double(forKey: WallpaperBlurKey) == 0 ? 20.0 : defaults.double(forKey: WallpaperBlurKey)
		self.wallpaperOpacity = defaults.double(forKey: WallpaperOpacityKey) == 0 ? 0.4 : defaults.double(forKey: WallpaperOpacityKey)
		
		self.showDate = defaults.object(forKey: "ShowDate") as? Bool ?? true
		self.showBattery = defaults.object(forKey: "ShowBattery") as? Bool ?? true
		self.fetchCityAuto = defaults.object(forKey: "FetchCityAuto") as? Bool ?? false
		self.is24HourTime = defaults.object(forKey: "Is24HourTime") as? Bool ?? false
	}
	
	private func save(_ value: Any?, key: String) {
		UserDefaults.standard.set(value, forKey: key)
	}
}

@Observable
class LocationDataManager: NSObject, CLLocationManagerDelegate {
	private let locationManager = CLLocationManager()
	var location: CLLocation?
	
	override init() {
		super.init()
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
	}
	
	func requestLocation() {
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		location = locations.first
		locationManager.stopUpdatingLocation()
	}
}

@Observable
class WeatherManager {
	private var updateTimer: Timer?
	
	var temperature: String = "--°"
	var condition: String = "Loading..."
	var symbol: String = "cloud.sun.fill"
	
	private func mapWeatherCode(_ code: Int) -> (text: String, symbol: String) {
		switch code {
		case 0: return ("Clear", "sun.max.fill")
		case 1...3: return ("Partly Cloudy", "cloud.sun.fill")
		case 45, 48: return ("Foggy", "cloud.fog.fill")
		case 51...67: return ("Rainy", "cloud.rain.fill")
		case 71...77: return ("Snowy", "snowflake")
		case 80...82: return ("Showers", "cloud.heavyrain.fill")
		case 95...99: return ("Thunderstorm", "cloud.bolt.fill")
		default: return ("Cloudy", "cloud.fill")
		}
	}
	
	func fetchWeather(lat: Double? = nil, lon: Double? = nil) async {
		// Fallbacks to New York
		let latitude = lat ?? 40.71
		let longitude = lon ?? -74.00
		let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code"
		
		guard let url = URL(string: urlString) else { return }
		
		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
			
			await MainActor.run {
				self.temperature = "\(Int(decoded.current.temperature_2m))°F"
				self.condition = mapWeatherCode(decoded.current.weather_code).text
				self.symbol = mapWeatherCode(decoded.current.weather_code).symbol
			}
		} catch {
			print("Weather error: \(error)")
		}
	}
	
	func startAutoUpdate(lat: Double, lon: Double) {
		updateTimer?.invalidate()
		
		Task { await fetchWeather(lat: lat, lon: lon) }
		
		updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
			Task { await self.fetchWeather(lat: lat, lon: lon) }
		}
	}
}

struct WeatherResponse: Codable {
	let current: CurrentWeather
	struct CurrentWeather: Codable {
		let temperature_2m: Double
		let weather_code: Int
	}
}

// [ FUNCTIONS ]

func getDocumentsDirectory() -> URL {
	FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

func searchCity(query: String, completion: @escaping (CLLocationCoordinate2D?, String?) -> Void) {
	let request = MKLocalSearch.Request()
	request.naturalLanguageQuery = query
	
	let search = MKLocalSearch(request: request)
	search.start { response, error in
		DispatchQueue.main.async {
			guard let item = response?.mapItems.first else {
				completion(nil, nil)
				return
			}
			completion(item.placemark.coordinate, item.name)
		}
	}
}

// [ MAIN CONTENT VIEW ]

// Video Background View
struct VideoBackgroundView: View {
	let url: URL
	@State private var player = AVQueuePlayer()
	@State private var looper: AVPlayerLooper?
	@State private var opacity: Double = 0
	
	var body: some View {
		VideoPlayerContainer(player: player)
			.opacity(opacity)
			.onAppear { setupPlayer() }
			.onChange(of: url) { setupPlayer() }
			.ignoresSafeArea()
	}
	
	private func setupPlayer() {
		player.pause()
		player.removeAllItems()
		
		let item = AVPlayerItem(url: url)
		looper = AVPlayerLooper(player: player, templateItem: item)
		
		player.isMuted = true
		player.play()
		
		withAnimation(.easeIn(duration: 1.0)) {
			self.opacity = 1.0
		}
	}
}

#if os(macOS)
struct VideoPlayerContainer: NSViewRepresentable {
	let player: AVPlayer
	
	func makeNSView(context: Context) -> NSView {
		let view = NSView()
		let layer = AVPlayerLayer(player: player)
		layer.videoGravity = .resizeAspectFill
		view.layer = layer
		view.wantsLayer = true
		return view
	}
	
	func updateNSView(_ nsView: NSView, context: Context) {
		nsView.layer?.frame = nsView.bounds
	}
}
#else
struct VideoPlayerContainer: UIViewRepresentable {
	let player: AVPlayer
	
	func makeUIView(context: Context) -> UIView {
		let view = UIView()
		let layer = AVPlayerLayer(player: player)
		layer.videoGravity = .resizeAspectFill
		view.layer.addSublayer(layer)
		return view
	}
	
	func updateUIView(_ uiView: UIView, context: Context) {
		uiView.layer.sublayers?.first?.frame = uiView.bounds
	}
}
#endif

// Image Background View
struct ImageBackgroundView: View {
	let url: URL
	
	var body: some View {
		AsyncImage(url: url) { phase in
			if let image = phase.image {
				image.resizable().aspectRatio(contentMode: .fill)
			} else {
				Color.black
			}
		}
	}
}

// Crossfade Helper
struct CrossfadeBackgroundContent: View {
	@Environment(UserDataManager.self) private var userDataManager
	
	var body: some View {
		ZStack {
			if let url = userDataManager.wallpaperURL {
				Group {
					if userDataManager.wallpaperType == .video {
						VideoBackgroundView(url: url)
					} else {
						ImageBackgroundView(url: url)
					}
				}
				.id(url)
				.transition(.opacity.animation(.easeInOut(duration: 1.5)))
			} else {
				Color.black
			}
		}
		.ignoresSafeArea()
	}
}

// Weather Widget
struct WeatherWidget: View {
	@State private var userDataManager = UserDataManager()
	@State private var weather = WeatherManager()
	@State private var locationManager = LocationDataManager()
	
	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: weather.symbol)
				.resizable()
				.scaledToFit()
				#if os(tvOS)
					.frame(width: 50, height: 50)
				#else
					.frame(width: 25, height: 25)
				#endif
				.symbolRenderingMode(.multicolor)
			
			Text("\(weather.temperature) | \(weather.condition)")
				#if os(tvOS)
					.font(.title2)
				#else
					.font(.headline)
				#endif
		}
		.foregroundColor(.white)
		.padding(10)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 15))
		.shadow(radius: 5)
		.task {
			if userDataManager.fetchCityAuto {
				locationManager.requestLocation()
				
				try? await Task.sleep(for: .seconds(1))
				weather.startAutoUpdate(
					lat: locationManager.location?.coordinate.latitude ?? 40.71,
					lon: locationManager.location?.coordinate.longitude ?? -74.00
				)
			} else {
				weather.startAutoUpdate(
					lat: userDataManager.lastLat != 0 ? userDataManager.lastLat : 40.71,
					lon: userDataManager.lastLon != 0 ? userDataManager.lastLon : -74.00
				)
			}
		}
	}
}

// Battery Widget

struct BatteryWidgetView: View {
	@State private var batteryLevel: Int = 100
	
	var body: some View {
		HStack(spacing: 4) {
			Image(systemName: batteryLevel < 20 ? "battery.0" : "battery.100")
			Text("\(batteryLevel)%")
		}
		.font(.caption.bold())
		.foregroundColor(.white.opacity(0.8))
		.onAppear {
		#if os(iOS)
			UIDevice.current.isBatteryMonitoringEnabled = true
			batteryLevel = Int(UIDevice.current.batteryLevel * 100)
		#else
			batteryLevel = 100
		#endif
		}
	}
}

// Main Content
struct ContentView: View {
	@State private var userDataManager = UserDataManager()
	@State private var weather = WeatherManager()
	@State private var locationManager = LocationDataManager()
	
	@State private var isDimmed: Bool = false
	@State private var dimmingTask: Task<Void, Never>? = nil
	
	@State private var clockOffset = CGSize.zero
	@State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
	
	@State private var isSettingsPresented = false
	
	// Defines the custom date format style: "Tue, Dec, 2"
	let customDateFormat: Date.FormatStyle = .dateTime
		.weekday(.abbreviated)
		.month(.abbreviated)
		.day(.defaultDigits)
		.locale(Locale.current) // Ensures localization is handled correctly DO NOT REMOVE IT PLEASE
	
	private var dimTimeoutSeconds: Double {
		switch userDataManager.dimmingSelectionTag {
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
		if isSettingsPresented { return }
		
		dimmingTask?.cancel()
		
		withAnimation(.easeInOut(duration: 0.6)) {
			isDimmed = false
		}
		
		if userDataManager.dimmingSelectionTag != 6 && !isSettingsPresented {
			_ = dimTimeoutSeconds
			dimmingTask = Task {
				try? await Task.sleep(for: .seconds(dimTimeoutSeconds))
				if !Task.isCancelled {
					withAnimation(.easeInOut(duration: 1.5)) { self.isDimmed = true }
				}
			}
		}
	}
	
	private func handleUserInteraction() {
		if isSettingsPresented { return }
		
		if isDimmed {
			setupDimmingTimer()
		} else {
			isSettingsPresented = true
		}
	}
	
	// Time and Date Layer
	@ViewBuilder
	private func timeDateLayer() -> some View {
		TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
			let dateString = timeline.date.formatted(customDateFormat)
			let customTextValue = userDataManager.customText

			let dateView = Text(dateString)
				.font(.system(size: osFontSize(base: 25), weight: .semibold))
				.foregroundColor(.white.opacity(0.7))
			let timeView = Text(userDataManager.timeFormatter.string(from: timeline.date))
				.bold()
				.padding(1)
				.font(.system(size: osFontSize(base: 64), weight: .heavy))
				.shadow(radius: 10)
			
			let customTextView = Text(customTextValue)
				.padding(5)
				.font(osFont(base: .caption))

			VStack {
				if userDataManager.showDate { dateView }
				
				timeView
				
				HStack(spacing: 15) {
					if userDataManager.showBattery {
						BatteryWidgetView()
					}
					customTextView
				}
			}
			.foregroundColor(.white)
		}
	}
	
	var body: some View {
		ZStack {
			// Wallpaper Background Layer
			CrossfadeBackgroundContent()
				.blur(radius: userDataManager.wallpaperBlur)
				.opacity(isDimmed ? userDataManager.wallpaperOpacity : 1)
		
			// Ui Layer
			VStack {
//				HStack {
//					Spacer()
//					
//					if showNotifications && notificationCount > 0 {
//						HStack(spacing: 6) {
//							Image(systemName: "bell.fill")
//							Text("\(notificationCount) Notifications")
//						}
//						.font(.headline)
//						.foregroundColor(.white)
//						.padding(10)
//						.background(.ultraThinMaterial)
//						.clipShape(RoundedRectangle(cornerRadius: 15))
//						.padding(.leading, 20)
//						.opacity(isDimmed ? 0 : 1.0)
//					}
//				}
				
				VStack {
					timeDateLayer()
						.opacity(isDimmed ? 0.7 : 1.0)
					
					WeatherWidget()
						.padding(.bottom, 20)
						.opacity(isDimmed ? 0.7 : 1.0)
				}
				.offset(clockOffset)
				.animation(.easeInOut(duration: 10), value: clockOffset)
				.onReceive(timer) { _ in
					moveClock()
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.environment(userDataManager)
		.onAppear { setupDimmingTimer() }
		.onChange(of: isSettingsPresented) { isDimmed = $1; setupDimmingTimer() }
		
		#if os(tvOS)
			.focusable(true)
			.onMoveCommand { _ in if isDimmed { setupDimmingTimer() } }
			.onLongPressGesture(minimumDuration: 0) { handleUserInteraction() }
		#else
			.onContinuousHover { _ in if isDimmed { setupDimmingTimer() } }
			.onTapGesture { handleUserInteraction() }
		#endif
		
		.sheet(isPresented: $isSettingsPresented) {
			SettingsView( isPresented: $isSettingsPresented )
			.environment(userDataManager)
			.environment(weather)
			.environment(locationManager)
		}
	}
	
	// Helper for clock position
	private func moveClock() {
		#if os(tvOS)
			let range: CGFloat = 100
		#else
			let range: CGFloat = 50
		#endif
		
		let newX = CGFloat.random(in: -range...range)
		let newY = CGFloat.random(in: -range...range)
		
		clockOffset = CGSize(width: newX, height: newY)
	}
	
	// Helpers for dynamic sizing across platforms
	private func osFontSize(base: CGFloat) -> CGFloat {
		#if os(tvOS)
			return base * 2.5 // Apple TV is viewed from far away
		#else
			return base
		#endif
	}
	private func osFont(base: Font) -> Font {
		#if os(tvOS)
			return .title2
		#else
			return base
		#endif
	}
}


// [ SETTINGS VIEW ]

// Settings View
struct SettingsView: View {
	@Environment(UserDataManager.self) private var userDataManager
	@Environment(WeatherManager.self) private var weather
	@Environment(LocationDataManager.self) private var locationManager
	
	@State private var citySearchText: String = ""
	
	var customText: Binding<String> {
		Binding(
			get: { userDataManager.customText },
			set: { userDataManager.customText = $0 }
		)
	}
	
	var dimmingSelectionTag: Binding<Int> {
		Binding(
			get: { userDataManager.dimmingSelectionTag },
			set: { userDataManager.dimmingSelectionTag = $0 }
		)
	}
	
	@Binding var isPresented: Bool
	
	var body: some View {
		NavigationStack {
		#if os(tvOS)
			ScrollView {
				VStack(spacing: 30) {
					
						// APPEARANCE SECTION
					VStack(alignment: .leading, spacing: 15) {
						Text("APPEARANCE").font(.headline).opacity(0.7)
						
						VStack {
								// Custom Text Row
							HStack {
								Image(systemName: "textformat")
								Text("Custom Text")
								Spacer()
								TextField("Boring Screen Saver", text: $customText)
									.textFieldStyle(.plain)
									.frame(maxWidth: 400)
							}
							.padding()
							.background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
						}
					}
					
						// BEHAVIOR SECTION
					VStack(alignment: .leading, spacing: 15) {
						Text("BEHAVIOR").font(.headline).opacity(0.7)
						
						Picker(selection: $dimmingSelectionTag, label: Label("Dim Screen after...", systemImage: "sun.max.fill")) {
							Text("5 Seconds").tag(1)
							Text("30 Seconds").tag(2)
							Text("5 Minutes").tag(3)
							Text("10 Minutes").tag(4)
							Text("30 Minutes").tag(5)
							Text("Never").tag(6)
						}
						.pickerStyle(.navigationLink)
						.padding()
						.background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
					}
					
					Text("Crowned Studios. 2026")
						.font(.caption2).opacity(0.5)
						.padding(.top, 40)
				}
				.padding(60)
			}
			.frame(width: 1000)
			.navigationTitle("Boring Settings")
		#else
			Form {
				Section(header: Text("Appearance").font(.headline)) {
					// Wallpaper Option
					NavigationLink(destination: WallpaperSelector()) {
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
					
					// Custom Text Option
					HStack {
						Image(systemName: "textformat")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
							.foregroundColor(.primary)
						Text("Custom Text")
						Spacer()
						TextField("", text: customText)
							.multilineTextAlignment(.trailing)
							.disableAutocorrection(true)
					}
					
					// Show Date
					HStack {
						Image(systemName: "calendar")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
							.foregroundColor(.primary)
						Text("Show Date")
						Spacer()
						Toggle("", isOn: Binding(get: { userDataManager.showDate }, set: { userDataManager.showDate = $0 }))
					}
					
					// Show Battery
					HStack {
						Image(systemName: "battery.100percent")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
							.foregroundColor(.primary)
						Text("Show Battery")
						Spacer()
						Toggle("", isOn: Binding(get: { userDataManager.showBattery }, set: { userDataManager.showBattery = $0 }))
					}
				}
				
				Section(header: Text("Behavior").font(.headline)) {
					// 24-Hour Time
					HStack {
						Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
							.foregroundColor(.primary)
						Text("24-Hour Time")
						Spacer()
						Toggle("", isOn: Binding(get: { userDataManager.is24HourTime }, set: { userDataManager.is24HourTime = $0 }))
					}
					
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
						Picker(selection: dimmingSelectionTag, label: Text("Dim Screen after...")) {
							Text("5 Seconds").tag(1)
							Text("30 Seconds").tag(2)
							Text("5 Minutes").tag(3)
							Text("10 Minutes").tag(4)
							Text("30 Minutes").tag(5)
							Text("Never").tag(6)
						}
					}
				}
				
				Section(header: Text("Location").font(.headline)) {
					// Fetch City Automatically
					HStack {
						Image(systemName: "location.fill")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
							.foregroundColor(.primary)
						Text("Fetch City Automatically")
						Spacer()
						Toggle("", isOn: Binding(get: { userDataManager.fetchCityAuto }, set: { userDataManager.fetchCityAuto = $0 }))
							.onChange(of: userDataManager.fetchCityAuto) {
								locationManager.requestLocation()
								
								
								weather.startAutoUpdate(
									lat: locationManager.location?.coordinate.latitude ?? 40.71,
									lon: locationManager.location?.coordinate.longitude ?? -74.00
								)
							}
					}
					
					// Search City Option
					HStack {
						TextField("Search City (e.g. London)", text: $citySearchText)
						Button("Update") {
							searchCity(query: citySearchText) { coord, name in
								if let coord = coord, let name = name {
									userDataManager.lastLat = coord.latitude
									userDataManager.lastLon = coord.longitude
									userDataManager.cityName = name
									
									Task { await weather.fetchWeather(lat: coord.latitude, lon: coord.longitude) }
								}
							}
						}
					}
					.disabled(userDataManager.fetchCityAuto)
					Text("Current: \(userDataManager.cityName)")
						.font(.caption2).foregroundStyle(.secondary)
				}
				
				Section {
					VStack(alignment: .center, spacing: 4) {
						Text("Crowned Studios. 2026")
							.font(.caption2)
							.opacity(0.5)
					}
					.frame(maxWidth: .infinity)
				}
				.listRowBackground(Color.clear)
			}
			.navigationTitle("Boring Settings")
			
			#if os(iOS)
			.navigationBarTitleDisplayMode(.large)
			
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") { isPresented = false }
				}
			}
			
			#elseif os(macOS)
			.formStyle(.grouped)
			
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { isPresented = false }
				}
			}
			#endif
		#endif
		}
	}
}

// [ WALLPAPER SELECTOR VIEW ]

#if !os(tvOS)
// Helper for video loading
struct Movie: Transferable {
	let url: URL
	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) }
		importing: { received in
			let destination = await getDocumentsDirectory().appendingPathComponent(UUID().uuidString + ".mp4")
			try? FileManager.default.copyItem(at: received.file, to: destination)
			return Movie(url: destination)
		}
	}
}

// Wallpaper Selector
struct WallpaperSelector: View {
	@Environment(UserDataManager.self) private var userDataManager
	
	@State private var selectedItem: PhotosPickerItem? = nil
	
	var blurBinding: Binding<Double> {
		Binding(
			get: { userDataManager.wallpaperBlur },
			set: { userDataManager.wallpaperBlur = $0 }
		)
	}
	
	var opacityBinding: Binding<Double> {
		Binding(
			get: { userDataManager.wallpaperOpacity },
			set: { userDataManager.wallpaperOpacity = $0 }
		)
	}
	
	var body: some View {
		Form {
			// Wallpaper Selector Option
			Section() {
				VStack(alignment: .center) {
					Text("CURRENT")
						.font(.system(size: 20, weight: .semibold))
						.padding(.top, 10)
						.padding(.bottom, 10)
						.foregroundStyle(Color.secondary.opacity(0.7))
					
					PhotosPicker(
						selection: $selectedItem,
						matching: .any(of: [.images, .videos]),
					) {
						ZStack {
							if let url = userDataManager.wallpaperURL {
								if userDataManager.wallpaperType == .video {
									VideoBackgroundView(url: url)
										.frame(height: 200).cornerRadius(10)
								} else {
									AsyncImage(url: url) { image in
										image.resizable().scaledToFill()
									} placeholder: {
										Color.black
									}
									.frame(height: 200).cornerRadius(10).clipped()
								}
								
								HStack {
									Image(systemName: "ellipsis")
									Text("Replace Wallpaper")
								}
								.font(.caption.weight(.semibold))
								.foregroundColor(.white)
								.padding(.vertical, 8)
								.padding(.horizontal, 12)
								.background(
									Capsule().fill(.ultraThinMaterial)
								)
								.cornerRadius(10)
								.padding(10)
								
							} else {
								Color.black
									.scaledToFill()
									.frame(height: 180)
									.cornerRadius(8)
									.clipped()
									.shadow(radius: 5)
								
								HStack {
									Image(systemName: "plus")
									Text("Select a Wallpaper")
								}
								.font(.caption.weight(.semibold))
								.foregroundColor(.white)
								.padding(.vertical, 8)
								.padding(.horizontal, 12)
								.background(
									Capsule().fill(.ultraThinMaterial)
								)
								.cornerRadius(10)
								.padding(10)
							}
						}
					}
					
					Button("Reset to Default") { userDataManager.wallpaperURL = nil }
						.buttonStyle(.bordered)
						.padding(.top, 10)
						.disabled(userDataManager.wallpaperURL == nil)
				}
				.buttonStyle(.plain)
				.padding(.vertical, 3)
			}
			
			// Wallpaper Effects Options
			Section(header: Text("Wallpaper Effects").font(.headline)) {
				// Wallpaper Blur Option
				VStack(alignment: .leading) {
					HStack {
						Image(systemName: "lightspectrum.horizontal")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(
								RoundedRectangle(cornerRadius: 10)
									.fill(.ultraThinMaterial)
							)
						Text("Wallpaper Blur Radius")
						Spacer()
					}
					
					Slider(value: blurBinding, in: 0...50, step: 1) {
					} minimumValueLabel: {
						Text("0")
							.padding(.trailing, 10)
					} maximumValueLabel: {
						Text("\(Int(userDataManager.wallpaperBlur))")
							.padding(.leading, 10)
					}
					.padding(.horizontal)
				}
				.disabled(userDataManager.wallpaperURL == nil)
				
				// Wallpaper Opacity Option
				VStack(alignment: .leading) {
					HStack {
						Image(systemName: "circle.lefthalf.striped.horizontal.inverse")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(
								RoundedRectangle(cornerRadius: 10)
									.fill(.ultraThinMaterial)
							)
						Text("Dimmed Wallpaper Opacity")
						Spacer()
					}
					
					Slider(value: opacityBinding, in: 0...1, step: 0.1) {
					} minimumValueLabel: {
						Text("0")
							.padding(.trailing, 10)
					} maximumValueLabel: {
						Text("\(Int(userDataManager.wallpaperOpacity * 100))%")
							.padding(.leading, 10)
					}
					.padding(.horizontal)
				}
				.disabled(userDataManager.wallpaperURL == nil)
			}
		}
		
		#if os(macOS)
			.formStyle(.grouped)
		#else
			.navigationBarTitleDisplayMode(.inline)
		#endif
		
		.navigationTitle("Wallpaper")
		.onChange(of: selectedItem) { _, item in
			Task {
				guard let item = item else { return }
				if let movie = try? await item.loadTransferable(type: Movie.self) {
					await MainActor.run { userDataManager.wallpaperURL = movie.url }
				} else if let data = try? await item.loadTransferable(type: Data.self) {
					let url = getDocumentsDirectory().appendingPathComponent(UUID().uuidString + ".jpg")
					try? data.write(to: url)
					await MainActor.run { userDataManager.wallpaperURL = url }
				}
			}
		}
	}
}
#endif

#Preview { ContentView() }

