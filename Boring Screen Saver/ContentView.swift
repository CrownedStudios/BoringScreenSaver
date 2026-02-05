//
//  ContentView.swift
//  Boring Screen Saver
//
//  Created by Chris on 2025-12-02.
//  Copyright © 2026 CrownedStudios. All rights reserved.
//

import SwiftUI
import PhotosUI
import AVFoundation

import Observation
import Combine

import CoreLocation
import MapKit

import TipKit

#if canImport(UIKit)
	import UIKit
#endif
#if canImport(AppKit)
	import AppKit
#endif

#if os(macOS)
	import IOKit.ps
#endif

// [ ENUMS ]

enum WallpaperType {
	case video, image, none
}

// [ OBSERVABLE CLASSES ]

@Observable
class UserDataManager {
	// Variables
	
	var onZenMode: Bool = false
	
	var pendingContent: Set<String> = []
	var failedUploads: Set<String> = []
	
	var currentIndex: Int = 0
	var wallpaperURLs: [URL] = [] {
		didSet { savePlaylist() }
	}
	var currentWallpaperURL: URL? {
		guard !wallpaperURLs.isEmpty else { return nil }
		return wallpaperURLs[wallpaperURLs.indices.contains(currentIndex) ? currentIndex : 0]
	}
	
	var randomShuffle: Bool = false {
		didSet { UserDefaults.standard.set(randomShuffle, forKey: "ShuffleRandomly") }
	}
	var playlistSelectionTag: Int = 1 {
		didSet { save(playlistSelectionTag, key: "PlaylistNextSelectionTag") }
	}
	
	var wallpaperBlur: Double = 20.0 {
		didSet { save(wallpaperBlur, key: "SavedWallpaperBlur") }
	}
	var wallpaperOpacity: Double = 0.4 {
		didSet { save(wallpaperOpacity, key: "SavedWallpaperOpacity") }
	}
	
	var customText: String = "Boring Screen Saver" {
		didSet { save(customText, key: "SavedCustomText") }
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
		didSet { save(dimmingSelectionTag, key: "DimingSelectionTag") }
	}
	
	var tempertureSetTag: Int = 1 {
		didSet { save(tempertureSetTag, key: "TempertureSetTag") }
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
		guard let url = currentWallpaperURL else { return .none }
		let videoExtensions = ["mov", "mp4", "avi", "wmv", "m4v"]
		return videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .image
	}
	
	var timeFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateFormat = is24HourTime ? "HH:mm" : "h:mm a"
		return formatter
	}
	
	var storageUsage: String = "0 B"
	
	// Init
	
	init() {
		let defaults = UserDefaults.standard
		
		if let savedPaths = UserDefaults.standard.stringArray(forKey: "SavedWallpaperPlaylist") {
			self.wallpaperURLs = savedPaths.compactMap{ fileName in
				let url = getDocumentsDirectory().appendingPathComponent(fileName)
				return FileManager.default.fileExists(atPath: url.path) ? url : nil
			}
		}
		
		self.customText = defaults.string(forKey: "SavedCustomText") ?? "Boring Screen Saver"
		self.cityName = defaults.string(forKey: "SavedCityName") ?? "Toronto"
		
		self.dimmingSelectionTag = defaults.integer(forKey: "DimingSelectionTag") == 0 ? 1 : defaults.integer(forKey: "DimingSelectionTag")
		self.playlistSelectionTag = defaults.integer(forKey: "PlaylistNextSelectionTag") == 0 ? 2 : defaults.integer(forKey: "PlaylistNextSelectionTag")
		self.tempertureSetTag = defaults.integer(forKey: "TempertureSetTag") == 0 ? 1 : defaults.integer(forKey: "TempertureSetTag")
		
		self.lastLat = defaults.double(forKey: "SavedLat") == 0 ? 43.6548 : defaults.double(forKey: "SavedLat")
		self.lastLon = defaults.double(forKey: "SavedLon") == 0 ? 79.3884 : defaults.double(forKey: "SavedLon")
		self.wallpaperBlur = defaults.double(forKey: "SavedWallpaperBlur") == 0 ? 20.0 : defaults.double(forKey: "SavedWallpaperBlur")
		self.wallpaperOpacity = defaults.double(forKey: "SavedWallpaperOpacity") == 0 ? 0.4 : defaults.double(forKey: "SavedWallpaperOpacity")
		
		self.randomShuffle = defaults.object(forKey: "ShuffleRandomly") as? Bool ?? false
		self.showDate = defaults.object(forKey: "ShowDate") as? Bool ?? true
		self.showBattery = defaults.object(forKey: "ShowBattery") as? Bool ?? true
		self.fetchCityAuto = defaults.object(forKey: "FetchCityAuto") as? Bool ?? false
		self.is24HourTime = defaults.object(forKey: "Is24HourTime") as? Bool ?? false
	}
	
	// Funcitons
	
	private func save(_ value: Any?, key: String) {
		UserDefaults.standard.set(value, forKey: key)
		
		self.updateStorageUsage()
	}
	private func savePlaylist() {
		let pathStrings = wallpaperURLs.map{ $0.lastPathComponent }
		UserDefaults.standard.set(pathStrings, forKey: "SavedWallpaperPlaylist")
		
		self.updateStorageUsage()
	}
	
	func wallpaperSelectType(_ selectURL: URL?) -> WallpaperType {
		guard let selectURL = selectURL else { return .none }
		let videoExtensions = ["mov", "mp4", "avi", "wmv", "m4v"]
		return videoExtensions.contains(selectURL.pathExtension.lowercased()) ? .video : .image
	}
	
	func nextWallpaper() {
		guard wallpaperURLs.count > 1 else { return }
		if randomShuffle {
			let wallpaperIndex = currentIndex
			currentIndex = Int.random(in: 0..<wallpaperURLs.count)
			
			if currentIndex == wallpaperIndex {
				nextWallpaper()
			}
		} else {
			currentIndex = (currentIndex + 1) % wallpaperURLs.count
		}
	}
	
	func updateStorageUsage() {
		let _ = self.wallpaperURLs
		let url = getDocumentsDirectory()
		guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { self.storageUsage = "0 B"; return }
		
		let totalSize = contents.reduce(0) { size, fileURL in
			let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
			return size + (attributes?.fileSize ?? 0)
		}
		
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useTB, .useGB, .useMB, .useKB]
		formatter.countStyle = .file
		self.storageUsage = formatter.string(fromByteCount: Int64(totalSize))
	}
	
	func clearData() {
		self.wallpaperURLs = []
		self.currentIndex = 0
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			let docURL = getDocumentsDirectory()
			let allFiles = try? FileManager.default.contentsOfDirectory(at: docURL, includingPropertiesForKeys: nil)
			for file in allFiles ?? [] {
				try? FileManager.default.removeItem(at: file)
			}
			
			self.updateStorageUsage()
		}
	}
	
	func handleExternalImport(_ urls: [URL]) {
		Task {
			for url in urls {
				guard url.isFileURL else { return }
				
				let canAccess = url.startAccessingSecurityScopedResource()
				
				let processId = UUID().uuidString
				self.pendingContent.insert(processId)
				
				do {
					let fileName = processId + "." + url.pathExtension
					let destination = getDocumentsDirectory().appendingPathComponent(fileName)
					
					try FileManager.default.copyItem(at: url, to: destination)
					
					await MainActor.run {
						withAnimation(.spring()) {
							self.wallpaperURLs.append(destination)
							self.pendingContent.remove(processId)
						}
						
						self.updateStorageUsage()
						self.currentIndex = self.wallpaperURLs.count - 1
						
						#if os(macOS)
							NSApp.activate(ignoringOtherApps: true)
						#endif
					}
				} catch {
					print("Failed to import via Open With: \(error)")
					
					self.failedUploads.insert(processId)
					self.pendingContent.remove(processId)
				}
				
				if canAccess {
					url.stopAccessingSecurityScopedResource()
				}
			}
		}
	}
}

struct WallpaperMetadata {
	let name: String
	let size: String
	let resolution: String
	let type: String
	let date: String
}

extension UserDataManager {
	func metadata(for url: URL) async -> WallpaperMetadata {
		let fileManager = FileManager.default
		let attributes = try? fileManager.attributesOfItem(atPath: url.path)
		let fileSize = attributes?[.size] as? Int64 ?? 0
		let creationDate = attributes?[.creationDate] as? Date ?? Date()
		
		let bcf = ByteCountFormatter()
		bcf.allowedUnits = [.useMB, .useGB]
		bcf.countStyle = .file
		let sizeString = bcf.string(fromByteCount: fileSize)
		
		var resString = "Unknown"
		if wallpaperSelectType(url) == .video {
			do {
				let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
				if let track = tracks.first {
					let size = try await track.load(.naturalSize)
					let transform = try await track.load(.preferredTransform)
					let transformedSize = size.applying(transform)
					resString = "\(Int(abs(transformedSize.width))) x \(Int(abs(transformedSize.height)))"
				}
			} catch {
				resString = "Unknown"
			}
		} else if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
				  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
			let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
			let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
			resString = "\(width) x \(height)"
		}
		
		return WallpaperMetadata(
			// TODO: make a rename thingy bc you cant get the original name
			name: url.deletingPathExtension().lastPathComponent,
			size: sizeString,
			resolution: resString,
			type: url.pathExtension.uppercased(),
			date: creationDate.formatted(date: .abbreviated, time: .omitted)
		)
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
	var lastUpdated: String = ""
	
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
	
	func fetchWeather(lat: Double? = nil, lon: Double? = nil, unitTag: Int? = 1) async {
		// Fallbacks to New York
		let latitude = lat ?? 40.71
		let longitude = lon ?? -74.00

		let unitParam = unitTag == 2 ? "fahrenheit" : "celsius"
		let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code&temperature_unit=\(unitParam)"
		
		guard let url = URL(string: urlString) else { return }
		
		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
			let rawTemp = decoded.current.temperature_2m
			
			await MainActor.run {
				if unitTag == 2 {
					self.temperature = "\(Int(rawTemp))°F"
				} else {
					self.temperature = "\(Int(rawTemp))°C"
				}
				
				let mapping = mapWeatherCode(decoded.current.weather_code)
				self.condition = mapping.text
				self.symbol = mapping.symbol
				
				let formatter = DateFormatter()
				formatter.timeStyle = .short
				self.lastUpdated = formatter.string(from: Date())
			}
		} catch {
			print("Weather error: \(error)")
		}
	}
	
	func startAutoUpdate(lat: Double, lon: Double, unitTag: Int? = 1) {
		updateTimer?.invalidate()
		
		Task { await fetchWeather(lat: lat, lon: lon, unitTag: unitTag) }
		
		updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
			Task { await self?.fetchWeather(lat: lat, lon: lon, unitTag: unitTag) }
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
			completion(item.location.coordinate, item.name)
		}
	}
}

// [ HELPER STRUCTS ]

// ShakeEffect Modifier
struct ShakeEffect: ViewModifier {
	var isEnabled: Bool
	
	@State private var angle: Double = 0
	
	func body(content: Content) -> some View {
		content
			.rotationEffect(.degrees(isEnabled ? angle : 0))
			.onAppear {
				if isEnabled {
					withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
						angle = 1.75
					}
				}
			}
			.onChange(of: isEnabled) { _, newValue in
				if newValue {
					withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
						angle = 1.75
					}
				} else {
					angle = 0
				}
			}
	}
}

extension View {
	func jiggle(when enabled: Bool) -> some View {
		self.modifier(ShakeEffect(isEnabled: enabled))
	}
}

// Video Background View
struct VideoBackgroundView: View {
	let url: URL
	@State private var player = AVQueuePlayer()
	@State private var looper: AVPlayerLooper?
	@State private var opacity: Double = 0
	
	var body: some View {
		GeometryReader { proxy in
			VideoPlayerContainer(player: player)
				.frame(width: proxy.size.width, height: proxy.size.height)
				.clipped()
				.opacity(opacity)
				.onAppear { setupPlayer() }
				.onChange(of: url) { setupPlayer() }
		}
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
		GeometryReader { proxy in
			AsyncImage(url: url) { phase in
				if let image = phase.image {
					image
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: proxy.size.width, height: proxy.size.height)
						.clipped()
				} else {
					Color.black
						.frame(width: proxy.size.width, height: proxy.size.height)
				}
			}
		}
	}
}

// Crossfade Helper
struct CrossfadeBackgroundContent: View {
	@Environment(UserDataManager.self) private var userDataManager
	
	var body: some View {
		ZStack {
			if let url = userDataManager.currentWallpaperURL {
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
	@Environment(UserDataManager.self) private var userDataManager
	
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
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 20))
		.padding(10)
		.foregroundColor(.white)
		.shadow(radius: 5)
		.task {
			initWeatherLogic()
		}
		.onChange(of: userDataManager.fetchCityAuto) { _, _ in
			initWeatherLogic()
		}
		.onChange(of: userDataManager.tempertureSetTag) { _, newTag in
			updateWeatherUnit(newTag)
		}
	}
	
	private func initWeatherLogic() {
		Task {
			if userDataManager.fetchCityAuto {
				locationManager.requestLocation()
				
				try? await Task.sleep(for: .seconds(1))
				weather.startAutoUpdate(
					lat: locationManager.location?.coordinate.latitude ?? 40.71,
					lon: locationManager.location?.coordinate.longitude ?? -74.00,
					unitTag: userDataManager.tempertureSetTag
				)
			} else {
				weather.startAutoUpdate(
					lat: userDataManager.lastLat != 0 ? userDataManager.lastLat : 40.71,
					lon: userDataManager.lastLon != 0 ? userDataManager.lastLon : -74.00,
					unitTag: userDataManager.tempertureSetTag
				)
			}
		}
	}
	private func updateWeatherUnit(_ tag: Int) {
		Task {
			await weather.fetchWeather(
				lat: userDataManager.lastLat != 0 ? userDataManager.lastLat : 40.71,
				lon: userDataManager.lastLon != 0 ? userDataManager.lastLon : -74.00,
				unitTag: tag
			)
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
        #elseif os(macOS)
            batteryLevel = BatteryWidgetView.macOSBatteryLevel()
        #endif
        }
    }
    
    #if os(macOS)
    static func macOSBatteryLevel() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return 100 }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return 100 }
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any],
               let current = info[kIOPSCurrentCapacityKey as String] as? Int,
               let max = info[kIOPSMaxCapacityKey as String] as? Int {
                return Int((Double(current) / Double(max)) * 100)
            }
        }
        return 100
    }
    #endif
}

// Zen Mode Border
struct ZenBorderOverlay: View {
	@State private var pulseOpacity: Double = 0.3
	@State private var glowRadius: CGFloat = 5
	
#if os(macOS)
	let cornerRadius: CGFloat = 20
#elseif os(iOS)
	let cornerRadius: CGFloat = 70
#else
	let cornerRadius: CGFloat = 60
#endif
	
	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color.green.opacity(pulseOpacity), lineWidth: 10)
				.blur(radius: glowRadius)
			
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color.green.opacity(pulseOpacity + 0.2), lineWidth: 2)
		}
		.ignoresSafeArea()
		.onAppear {
			withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
				pulseOpacity = 0.7
				glowRadius = 15
			}
		}
	}
}

// Zen Mode Info
struct ZenInfoOverlay: View {
	let metadata: WallpaperMetadata
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
//			Text(metadata.name)
//				.font(.system(size: 18, weight: .bold, design: .rounded))
			
			HStack(spacing: 12) {
				Label(metadata.type, systemImage: "filemenu.and.selection")
				Label(metadata.resolution, systemImage: "aspectratio")
				Label(metadata.size, systemImage: "sdcard")
			}
			.font(.caption)
			.foregroundStyle(.secondary)
			
			Text("Added on \(metadata.date)")
				.font(.system(size: 10))
				.textCase(.uppercase)
				.foregroundStyle(.tertiary)
		}
		.background(.ultraThinMaterial)
		.padding()
		.cornerRadius(12)
	}
}

// [ TIPS ]

struct ZenModeTip: Tip {
	var title: Text {
		Text("Zen Mode")
	}
	
	var message: Text? {
		Text("Pinch inwards to enable Zen Mode and hide the clock. Pinching outwards will exit Zen Mode.")
	}
	
	var image: Image? {
		Image(systemName: "hand.pinch")
	}
}

// [ MAIN CONTENT VIEW ]

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
	
	@State private var zenWallpaperMetadata: WallpaperMetadata? = nil
	
	let zenModeTip = ZenModeTip()
	
	// Defines the custom date format style: "Tue, Dec, 2"
	let customDateFormat: Date.FormatStyle = .dateTime
		.weekday(.abbreviated)
		.month(.abbreviated)
		.day(.defaultDigits)
		.locale(Locale.current)
	
	private var playlistNextSeconds: Double {
		switch userDataManager.playlistSelectionTag {
		case 1: return 5.0 // 5 Seconds
		case 2: return 60.0 // 60 Seconds
		case 3: return 5.0 * 60.0 // 5 Minutes
		case 4: return 15.0 * 60.0 // 15 Minutes
		case 5: return 30.0 * 60.0  // 30 Minutes
		case 6: return 60.0 * 60.0  // 1 Hour
		case 7: return Double.infinity // Never
		default: return 60.0
		}
	}
	
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
		}
	}
	
	// Time and Date Layer
	@ViewBuilder
	private func timeDateView() -> some View {
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
	
	@ViewBuilder
	private func topBarView() -> some View {
		#if !os(visionOS)
			HStack {
				Spacer()
				
				Menu {
					Button {
						withAnimation { userDataManager.onZenMode = true }
					} label: {
						Image(systemName: "apple.meditate")
						Text("Zen Mode")
					}
					.help("Hides the clock and focuses on the wallpaper")
					
					Button {
						withAnimation { userDataManager.randomShuffle.toggle() }
					} label: {
						Image(systemName: userDataManager.randomShuffle ? "repeat" : "shuffle")
						Text(userDataManager.randomShuffle ? "Repeat" : "Shuffle")
					}
					.help(userDataManager.randomShuffle ? "Loop through wallpappers in order" : "Shuffle through wallpapers")
					
					Button {
						isSettingsPresented = true
					} label: {
						Image(systemName: "gearshape.fill")
						Text("Settings")
					}
					.help("Open Settings")
				} label: {
					Image(systemName: "list.bullet")
						.font(.system(size: osFontSize(base: 20), weight: .semibold))
						.foregroundColor(.primary.opacity(0.8))
						.padding(12)
						.glassEffect(.regular.interactive())
				}
				.id("menu-button")
			}
			.padding(.horizontal, 40)
			.padding(.top, 20)
			.opacity(isDimmed || userDataManager.onZenMode ? 0 : 1)
			.allowsHitTesting(!isDimmed && !userDataManager.onZenMode)
			.animation(.easeInOut(duration: 0.5), value: isDimmed)
		#endif
	}
	
	var body: some View {
		ZStack {
			// Wallpaper Background Layer
			CrossfadeBackgroundContent()
				.blur(radius: !userDataManager.onZenMode ? userDataManager.wallpaperBlur : 0)
				.opacity(isDimmed && !userDataManager.onZenMode ? userDataManager.wallpaperOpacity : 1)
			
			// Ui Layer
			VStack {
				#if !os(visionOS)
					// Topbar
					topBarView()
				#endif
				
				Spacer()
				
				// Clock and Weather Widgets
				VStack {
					timeDateView()
						.opacity(isDimmed ? 0.7 : 1.0)
					
					WeatherWidget()
						.padding(.bottom, 20)
						.opacity(isDimmed ? 0.7 : 1.0)
				}
				.popoverTip(zenModeTip)
				.offset(clockOffset)
				.animation(.easeInOut(duration: 10), value: clockOffset)
				.onReceive(timer) { _ in
					moveClock()
				}
				
				Spacer()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.opacity(userDataManager.onZenMode ? 0 : 1)
			.scaleEffect(userDataManager.onZenMode ? 0.8 : 1)
			.blur(radius: userDataManager.onZenMode ? 10 : 0)
			
			
			if userDataManager.onZenMode {
				ZenBorderOverlay()
					.opacity(isDimmed ? 0 : 1)
					.transition(.opacity.combined(with: .scale(scale: 1.02)))
					.zIndex(99)
				
				VStack {
					Spacer()
					Image(systemName: "hand.pinch")
						.font(.system(size:24))
						.foregroundStyle(.primary.opacity(0.8))
						.padding(.bottom, 40)
						.opacity(isDimmed ? 0 : 1)
						.transition(.opacity)
				}
			}
			if userDataManager.onZenMode, let metadata = zenWallpaperMetadata {
				ZenInfoOverlay(metadata: metadata)
					.transition(.move(edge: .bottom).combined(with: .opacity))
					.popoverTip(zenModeTip)
			}
		}
		#if os(visionOS)
			.ornament(
				visibility: .visible,
				attachmentAnchor: .scene(.top)
			) {
				HStack {
					Button {
						withAnimation { userDataManager.onZenMode = true }
					} label: {
						Image(systemName: "apple.meditate")
					}
					.help("Hides the clock and focuses on the wallpaper")
					
					Button {
						withAnimation { userDataManager.randomShuffle.toggle() }
					} label: {
						Image(systemName: userDataManager.randomShuffle ? "repeat" : "shuffle")
					}
					.help(userDataManager.randomShuffle ? "Loop through wallpappers in order" : "Shuffle through wallpapers")
					
					Divider().frame(height: 20)
					
					Button {
						isSettingsPresented = true
					} label: {
						Image(systemName: "gearshape.fill")
					}
					.help("Open Settings")
				}
				.padding()
				.opacity(isDimmed || userDataManager.onZenMode ? 0 : 1)
				.allowsHitTesting(!isDimmed && !userDataManager.onZenMode)
				.animation(.easeInOut(duration: 0.5), value: isDimmed)
				.id(isDimmed)
			}
		#endif
		.environment(userDataManager)
		.onAppear { setupDimmingTimer() }
		.onChange(of: isSettingsPresented) { isDimmed = $1; setupDimmingTimer() }
		.task(id: userDataManager.onZenMode ? userDataManager.currentWallpaperURL : nil) {
			if userDataManager.onZenMode, let url = userDataManager.currentWallpaperURL {
				zenWallpaperMetadata = nil
				Task {
					let meta = await userDataManager.metadata(for: url)
					await MainActor.run { zenWallpaperMetadata = meta }
				}
			} else {
				zenWallpaperMetadata = nil
			}
		}
		
		.focusable()
		#if os(tvOS)
			.onMoveCommand { _ in if isDimmed { setupDimmingTimer() } }
			.onLongPressGesture(minimumDuration: 0) { handleUserInteraction() }
			.onPlayPauseCommand { withAnimation { userDataManager.onZenMode.toggle(); setupDimmingTimer() } }
		#else
			.focusEffectDisabled()
			.onKeyPress("z") {
				withAnimation { userDataManager.onZenMode.toggle(); setupDimmingTimer() }
				return .handled
			}
			.gesture(
				MagnifyGesture()
					.onChanged { value in
						if value.magnification < 0.8 && !userDataManager.onZenMode {
							withAnimation(.spring()) {
								userDataManager.onZenMode = true
								setupDimmingTimer()
								zenModeTip.invalidate(reason: .actionPerformed)
							}
						} else if value.magnification > 1.2 && userDataManager.onZenMode {
							withAnimation(.spring()) { userDataManager.onZenMode = false; setupDimmingTimer() }
						}
					}
			)
			.onTapGesture { handleUserInteraction() }
		#endif
		
			.onReceive(Timer.publish(every: playlistNextSeconds, on: .main, in: .common).autoconnect()) { _ in
				withAnimation {
					userDataManager.nextWallpaper()
				}
			}
		
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

// Helper to reveal directory in finder
func revealInFinder() {
	#if os(macOS)
		let url = getDocumentsDirectory()
		NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
	#endif
}

// Settings View
struct SettingsView: View {
	@Environment(UserDataManager.self) private var userDataManager
	@Environment(WeatherManager.self) private var weather
	@Environment(LocationDataManager.self) private var locationManager
	
	@State private var showWipeConfirmation = false
	
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
	
	var tempertureSet: Binding<Int> {
		Binding(
			get: { userDataManager.tempertureSetTag },
			set: { userDataManager.tempertureSetTag = $0 }
		)
	}
	
	var citySearchText: Binding<String> {
		Binding(
			get: { userDataManager.cityName },
			set: { userDataManager.cityName = $0 }
		)
	}
	
	@Binding var isPresented: Bool
	
	var body: some View {
		NavigationStack {
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
							Text("Wallpapers")
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
							.help("Enter a custom text to view on your boring wallpaper")
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
							.help("Show the current date on top of the clock")
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
							.help("Show the current battery percentage next to your custom text")
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
							.help("Display time in 24 hours instead of 12")
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
						.help("Put more focus on the clock after a while")
					}
					
					// Temperture Option
					HStack {
						Image(systemName: "thermometer.variable")
							.frame(width: 20, height: 20)
							.padding(5)
							.background(
								RoundedRectangle(cornerRadius: 10)
									.fill(.ultraThinMaterial)
							)
							.foregroundColor(.primary)
						Picker(selection: tempertureSet, label: Text("Set Temperture to...")) {
							Text("Celsius (ºC)").tag(1)
							Text("Fahrenheit (ºF)").tag(2)
						}
						.help("Display temperture in either Celsius or Fahrenheit")
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
							.help("Use your device's location to fetch the city automatically")
					}
					
					// Search City Option
					HStack {
						#if os(iOS) || os(visionOS)
							Text("Enter City Manually")
							Spacer()
						#endif
						TextField("Search (e.g. London)", text: citySearchText)
						Button("Update") {
							searchCity(query: citySearchText.wrappedValue) { coord, name in
								if let coord = coord, let name = name {
									userDataManager.lastLat = coord.latitude
									userDataManager.lastLon = coord.longitude
									userDataManager.cityName = name
									
									Task { await weather.fetchWeather(lat: coord.latitude, lon: coord.longitude, unitTag: userDataManager.tempertureSetTag) }
								}
							}
						}
						.help("Fetch the correct location and update the weather immediately")
					}
					.disabled(userDataManager.fetchCityAuto)
					HStack {
						Text("Provided by Open-Meteo")
							.font(.caption)
							.foregroundStyle(.secondary)
						if !weather.lastUpdated.isEmpty {
							Text("(Last Updated at \(weather.lastUpdated))")
								.font(Font.caption.italic())
								.foregroundStyle(.secondary)
						}
					}
				}
				
				Section(header: Text("Storage")) {
					HStack {
						Label("Boring Wallpapers", systemImage: "internaldrive")
						Spacer()
						Text(userDataManager.storageUsage)
							.foregroundColor(.secondary)
					}
					
#if os(macOS)
					Button {
						revealInFinder()
					} label: {
						Label("Reveal in Finder", systemImage: "folder")
					}
					.buttonStyle(.bordered)
					.help("Reveal saved wallpapers in Finder")
#endif
					
					Button() {
						showWipeConfirmation = true
					} label: {
						Label("Clear Boring Data", systemImage: "trash")
					}
					.help("Permanently delete all imported media from the app's storage")
					.disabled(userDataManager.wallpaperURLs.isEmpty && userDataManager.storageUsage == "0 B")
					.alert("Clear Boring Data?", isPresented: $showWipeConfirmation) {
						Button("Cancel", role: .cancel) { }
						Button("Delete Everything", role: .destructive) {
							withAnimation {
								userDataManager.clearData()
							}
						}
					} message: {
						Text("This will permanently delete all imported media from the app's storage. Your original photos will not be touched.")
					}
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
			
			#if os(iOS) || os(visionOS)
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
			.navigationTitle("Boring Settings")
		}
	}
}

// [ WALLPAPER SELECTOR VIEW ]

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

struct WallpaperCell: View {
	@Bindable var userDataManager: UserDataManager
	
	let url: URL
	let isEditing: Bool
	let isDragging: Bool
	
	var removeAction: (URL) -> Void
	
	@Binding var onAction: Bool
	
	@State private var isDraggingOver: Bool = false
	
	var body: some View {
		ZStack(alignment: .center) {
			wallpaperPreview(for: url, isEditing: isEditing)
				.onTapGesture {
					guard !onAction else { return }
					onAction = true
					
					if isEditing {
						removeAction(url)
					} else if let index = userDataManager.wallpaperURLs.firstIndex(of: url) {
						userDataManager.currentIndex = index
					}
					
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
						onAction = false
					}
				}
		}
		.contentShape(Rectangle())
		.blur(radius: isDraggingOver ? 10 : 0)
		.allowsHitTesting(!isEditing || isDragging)
#if os(macOS)
		.draggable(url) {
			RoundedRectangle(cornerRadius: 15)
				.fill(.gray)
				.frame(width: 150, height: 90)
				.overlay(Text("Moving...").font(.caption))
		}
		.dropDestination(for: URL.self) { items, _ in
			guard !isEditing, let draggedURL = items.first else { return false }
			
			if draggedURL != url {
				moveWallpaperDirect(draggedURL, to: url)
				return true
			}
			
			return false
		} isTargeted: { targeted in
			withAnimation { isDraggingOver = targeted }
		}
		.overlay {
			if isDraggingOver {
				ZStack {
					Color.clear
						.opacity(0.7)
						.cornerRadius(15)
					RoundedRectangle(cornerRadius: 15)
						.strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
						.padding()
					
					Text("Drop to Order Wallpapers")
						.font(.headline)
						.foregroundStyle(Color.primary)
				}
				.allowsHitTesting(false)
			}
		}
#endif
		.jiggle(when: isEditing)
		.transition(.scale.combined(with: .opacity))
	}
	
	private func moveWallpaper(at index: Int, direction: Int) {
		guard !onAction else { return }
		onAction = true
		
		let newIndex = index + direction
		guard newIndex >= 0 && newIndex < userDataManager.wallpaperURLs.count else { return }
		
		withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
			let item = userDataManager.wallpaperURLs.remove(at: index)
			userDataManager.wallpaperURLs.insert(item, at: newIndex)
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			onAction = false
		}
	}
	private func moveWallpaperDirect(_ source: URL, to destination: URL) {
		guard let fromIndex = userDataManager.wallpaperURLs.firstIndex(of: source),
			  let toIndex = userDataManager.wallpaperURLs.firstIndex(of: destination)
		else { return }
		
		withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
			userDataManager.wallpaperURLs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
		}
	}
	
	@ViewBuilder
	private func wallpaperPreview(for url: URL, isEditing: Bool) -> some View {
		let index = userDataManager.wallpaperURLs.firstIndex(of: url) ?? 0
		
		ZStack(alignment: .center) {
			if userDataManager.wallpaperSelectType(url) == .video {
				VideoBackgroundView(url: url)
					.aspectRatio(16/9, contentMode: .fill)
			} else {
				AsyncImage(url: url) { image in
					image
						.resizable()
						.scaledToFill()
				} placeholder: {
					Color.black
				}
			}
			
			Color.black.opacity(isEditing ? 0.3 : 0)
			HStack(spacing: 20) {
#if os(iOS)
				Button { moveWallpaper(at: index, direction: -1) } label: {
					Image(systemName: "arrow.left.circle.fill")
						.background(
							Capsule().fill(.ultraThinMaterial)
						)
						.font(.system(size: 30))
						.opacity(isEditing ? 1 : 0)
				}
				.disabled(isEditing && index == 0)
#endif
				
				ZStack {
					HStack {
						Image(systemName: "minus")
						Text("Remove Wallpaper")
					}
					.font(.caption.weight(.semibold))
					.foregroundColor(.primary)
					.padding(.vertical, 8)
					.padding(.horizontal, 12)
					.background(
						Capsule().fill(.red)
					)
					.cornerRadius(10)
					.padding(10)
					.opacity(isEditing ? 1 : 0)
					
					Text("Currently Active")
						.font(.caption.weight(.semibold))
						.foregroundColor(.secondary)
						.padding(.vertical, 8)
						.padding(.horizontal, 12)
						.background(
							Capsule().fill(.ultraThinMaterial)
						)
						.cornerRadius(10)
						.padding(10)
						.opacity((url == userDataManager.currentWallpaperURL && !isEditing) ? 1 : 0)
				}
				
#if os(iOS)
				Button { moveWallpaper(at: index, direction: 1) } label: {
					Image(systemName: "arrow.right.circle.fill")
						.background(
							Capsule().fill(.ultraThinMaterial)
						)
						.font(.system(size: 30))
						.opacity(isEditing ? 1 : 0)
				}
				.disabled(isEditing && index == userDataManager.wallpaperURLs.count - 1)
#endif
			}
			.buttonStyle(.plain)
			.foregroundStyle(.white)
		}
		.frame(width: 300, height: 180)
		.cornerRadius(15)
		.clipped()
		.overlay(
			RoundedRectangle(cornerRadius: 15)
				.stroke((url == userDataManager.currentWallpaperURL && !isEditing) ? Color.blue : Color.clear, lineWidth: 4)
		)
		.shadow(radius: (url == userDataManager.currentWallpaperURL && !isEditing) ? 10 : 2)
	}
}

// Helper for Wallpaper Carousel
struct WallpaperCarousel: View {
	@Bindable var userDataManager: UserDataManager
	var isEditing: Bool
	var removeAction: (URL) -> Void
	var isDragging: Bool = false
	
	@State private var onAction = false
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 15) {
				ForEach(Array(userDataManager.pendingContent), id: \.self) { _ in
					ZStack {
						pendingContentView()
					}
				}
				ForEach(userDataManager.wallpaperURLs, id: \.self) { url in
					WallpaperCell(
						userDataManager: userDataManager,
						url: url,
						isEditing: isEditing,
						isDragging: isDragging,
						removeAction: removeAction,
						onAction: $onAction
					)
				}
				ForEach(Array(userDataManager.failedUploads), id: \.self) { id in
					ZStack {
						failedUploadView()
					}
					.onTapGesture {
						guard !onAction else { return }
						onAction = true
						
						userDataManager.failedUploads.remove(id)
						
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
							onAction = false
						}
					}
				}
			}
			.padding(3)
			.scrollTargetLayout()
		}
		.scrollTargetBehavior(.viewAligned)
		.frame(height: 220)
	}
	
	@ViewBuilder
	private func pendingContentView() -> some View {
		RoundedRectangle(cornerRadius: 15)
			.fill(.ultraThinMaterial)
			.frame(width: 300, height: 180)
		
		VStack(spacing: 10) {
			ProgressView()
			Text("Processing Content...")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
	
	@ViewBuilder
	private func failedUploadView() -> some View {
		RoundedRectangle(cornerRadius: 15)
			.fill(.ultraThinMaterial)
			.frame(width: 300, height: 180)
		
		VStack(spacing: 10) {
			Image(systemName: "exclamationmark.circle")
				.font(.largeTitle)
				.foregroundStyle(.red)
			
			Text("Failed to process!")
				.font(.caption.bold())
				.foregroundStyle(.red)
		}
	}
}

// Helper for Wallpaper Playlist
struct PlaylistEditorView: View {
	@Environment(UserDataManager.self) private var userDataManager
	@State private var selectedItems: [PhotosPickerItem] = []
	
	@State private var isEditing: Bool = false
	@State private var isImportingFile: Bool = false
	@State private var isDraggingOver: Bool = false
	@State private var showImportOptions: Bool = false
	@State private var showPhotoPicker = false
	
	var playlistSelectionTag: Binding<Int> {
		Binding(
			get: { userDataManager.playlistSelectionTag },
			set: { userDataManager.playlistSelectionTag = $0 }
		)
	}
	
	var body: some View {
		Form {
			VStack {
				Text("WALLPAPERS")
					.font(.system(size: 20, weight: .semibold))
					.foregroundStyle(Color.secondary.opacity(0.7))
				
				Spacer()
				
				if userDataManager.wallpaperURLs.isEmpty && userDataManager.pendingContent.isEmpty && userDataManager.failedUploads.isEmpty {
					emptyStateView
				} else {
					WallpaperCarousel(
						userDataManager: userDataManager,
						isEditing: isEditing,
						removeAction: removeWallpaper,
						isDragging: !isDraggingOver
					)
				}
				
				Spacer()
				
				footerButtonsView
			}
			.contentShape(Rectangle())
			.blur(radius: isDraggingOver ? 10 : 0)
			.dropDestination(for: URL.self) { items, isTargeted in
				userDataManager.handleExternalImport(items)
				
				userDataManager.currentIndex = userDataManager.wallpaperURLs.count - 1
				#if os(macOS)
					NSApp.activate(ignoringOtherApps: true)
				#endif
				
				return true
			} isTargeted: { isTargeted in
				withAnimation { isDraggingOver = isTargeted }
			}
			.overlay {
				if isDraggingOver {
					ZStack {
						Color.clear
							.opacity(0.7)
							.cornerRadius(15)
						RoundedRectangle(cornerRadius: 15)
							.strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
							.padding()
						
						Label("Drop to Add Wallpapers", systemImage: "plus.square.dashed")
							.font(.headline)
							.foregroundStyle(Color.primary)
					}
					.allowsHitTesting(false)
				}
			}
			
			Section(header: Text("Shuffle Options").font(.headline)) {
				// Shuffle Randomly
				Toggle("Shuffle Randomly", isOn: Binding(get: { userDataManager.randomShuffle }, set: { userDataManager.randomShuffle = $0 }))
				.disabled(userDataManager.wallpaperURLs.isEmpty)
				
				// Shuffle Every
				Picker(selection: playlistSelectionTag, label: Text("Shuffle every...")) {
					Text("5 Seconds").tag(1)
					Text("60 Seconds").tag(2)
					Text("5 Minutes").tag(3)
					Text("15 Minutes").tag(4)
					Text("30 Minutes").tag(5)
					Text("Hour").tag(6)
					Text("Never").tag(7)
				}
				.disabled(userDataManager.wallpaperURLs.isEmpty)
			}
		}
#if os(macOS)
		.formStyle(.grouped)
#else
		.navigationBarTitleDisplayMode(.inline)
#endif
		
		.navigationTitle("Wallpaper Order")
	}
	
	private var emptyStateView: some View {
		ZStack {
			Color.black
				.frame(height: 200)
				.cornerRadius(10)
			
			Text("No wallpapers added yet")
				.font(.caption.weight(.semibold))
				.foregroundColor(.secondary)
				.padding(.vertical, 8)
				.padding(.horizontal, 12)
				.background(
					Capsule().fill(.ultraThinMaterial)
				)
				.cornerRadius(10)
				.padding(10)
		}
	}
	private var footerButtonsView: some View {
		HStack {
			Button {
				showImportOptions = true
			} label: {
				Label("Add New Wallpaper", systemImage: "plus")
//				.font(.caption.weight(.semibold))
//				.foregroundColor(.primary)
//				.padding(.vertical, 8)
//				.padding(.horizontal, 12)
//				.background(
//					Capsule().fill(.bar)
//				)
//				.cornerRadius(10)
			}
			.buttonStyle(.bordered)
			.confirmationDialog("Add Wallpaper", isPresented: $showImportOptions) {
				Button {
					showPhotoPicker = true
				} label: {
					Label("Import from Photo Library", systemImage: "plus")
				}
				
				Button {
					isImportingFile = true
				} label: {
					Label("Import from Files", systemImage: "folder")
				}
			}
			.buttonStyle(.plain)
			.fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.movie, .image], allowsMultipleSelection: true) { result in
				handleFileSelection(result)
			}
			.photosPicker(
				isPresented: $showPhotoPicker,
				selection: $selectedItems,
				matching: .any(of: [.images, .videos])
			)

			Button(isEditing ? "Done" : "Edit") {
				withAnimation { isEditing.toggle() }
			}
			.buttonStyle(.bordered)
			.disabled(userDataManager.wallpaperURLs.isEmpty)
		}
		.onChange(of: selectedItems) { _, newItems in
			handlePickerSelection(newItems)
		}
	}
	
	private func removeWallpaper(_ url: URL) {
		withAnimation {
			userDataManager.wallpaperURLs.removeAll(where: { $0 == url })
			if userDataManager.wallpaperURLs.isEmpty { isEditing = false }
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			try? FileManager.default.removeItem(at: url)
			
			userDataManager.updateStorageUsage()
		}
	}
	private func handlePickerSelection(_ items: [PhotosPickerItem]) {
		guard !items.isEmpty else { return }
		
		for item in items {
			let processId = UUID().uuidString
			userDataManager.pendingContent.insert(processId)
			
			Task(priority: .userInitiated) {
				do {
					if let movie = try await item.loadTransferable(type: Movie.self) {
						let permanentURL = try saveToDocuments(from: movie.url)
						
						await MainActor.run {
							userDataManager.wallpaperURLs.append(permanentURL)
							userDataManager.pendingContent.remove(processId)
						}
					} else if let data = try await item.loadTransferable(type: Data.self) {
						let url = getDocumentsDirectory().appendingPathComponent(UUID().uuidString + ".jpg")
						try data.write(to: url)
						
						await MainActor.run {
							userDataManager.wallpaperURLs.append(url)
							userDataManager.pendingContent.remove(processId)
						}
					}
				} catch {
					print("Error loading file: \(error)")
					_ = await MainActor.run {
						userDataManager.failedUploads.insert(processId)
						userDataManager.pendingContent.remove(processId)
					}
				}
			}
		}
		userDataManager.updateStorageUsage()
		
		selectedItems = []
	}
	private func handleFileSelection(_ result: Result<[URL], Error>) {
		switch result {
		case .success(let urls):
			for url in urls {
				guard url.startAccessingSecurityScopedResource() else { continue }
				
				let processId = UUID().uuidString
				userDataManager.pendingContent.insert(processId)
				
				do {
					let permanentURL = try saveToDocuments(from: url)
					url.stopAccessingSecurityScopedResource()
					
					withAnimation {
						userDataManager.wallpaperURLs.append(permanentURL)
						userDataManager.pendingContent.remove(processId)
					}
				} catch {
					print("Faled to copy: \(error)")
					
					url.stopAccessingSecurityScopedResource()
					
					userDataManager.failedUploads.insert(processId)
					userDataManager.pendingContent.remove(processId)
				}
			}
			
			userDataManager.updateStorageUsage()
			
		case .failure(let error):
			print("Import failed: \(error.localizedDescription)")
		}
	}
	
	private func saveToDocuments(from tempURL: URL) throws -> URL {
		let fileName = UUID().uuidString + "." + tempURL.pathExtension
		let destination = getDocumentsDirectory().appendingPathComponent(fileName)
		try FileManager.default.copyItem(at: tempURL, to: destination)
		return destination
	}
}

// Wallpaper Selector
struct WallpaperSelector: View {
	@Environment(UserDataManager.self) private var userDataManager
	
	@State private var showPlaylistEditor = false
	
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
					Button {
						showPlaylistEditor = true
					} label: {
						ZStack {
							if userDataManager.currentWallpaperURL != nil {
								CrossfadeBackgroundContent()
									.frame(height: 200)
									.frame(maxWidth: .infinity)
									.cornerRadius(10)
									.shadow(radius: 10)
									
								#if os(iOS)
									.blur(radius: userDataManager.wallpaperBlur)
									.opacity(userDataManager.wallpaperOpacity)
								#endif
								
								HStack {
									Image(systemName: "ellipsis")
									Text("Change Wallpapers")
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
									.frame(height: 200)
									.frame(maxWidth: .infinity)
									.cornerRadius(10)
								
								HStack {
									Image(systemName: "plus")
									Text("Select Wallpapers")
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
					.buttonStyle(.plain)
				}
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
				.disabled(userDataManager.currentWallpaperURL == nil)
				
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
				.disabled(userDataManager.currentWallpaperURL == nil)
			}
		}
		.navigationDestination(isPresented: $showPlaylistEditor) {
			PlaylistEditorView()
		}
		
#if os(macOS)
		.formStyle(.grouped)
#else
		.navigationBarTitleDisplayMode(.inline)
#endif
		
		.navigationTitle("Wallpapers")
	}
}

#Preview {
	ContentView()
}

