//
//  ContentView.swift
//  Screen Saver
//
//  Created by Chris on 2025-12-02.
//

import SwiftUI

struct ContentView: View {
	let customDateFormat: Date.FormatStyle = .dateTime
		.weekday(.abbreviated)
		.month(.abbreviated)
		.day(.defaultDigits)
		.locale(Locale.current) // Ensures localization is handled correctly
	
    var body: some View {
		ZStack {
			Image("WallpaperApplied")
				.resizable()
				.scaledToFill() // Ensures it covers the entire screen
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
				.opacity(0.8) // Make it subtle
				.ignoresSafeArea(.all)
				.blur(radius: 20)
			
			VStack {
				Text(Date.now.formatted(customDateFormat))
					.font(.system(size: 25, weight: .semibold))
					.foregroundColor(.white.opacity(0.7))
				
				Text(Date(), style: .time)
					.bold(true)
					.padding(1)
					.font(.system(size: 64, weight: .heavy))
					.shadow(radius: 10)
			}
			.foregroundColor(.white)
			
			VStack {
				HStack {
					Spacer()
					Button(action: {
						print("button tapped")
					}) {
						Image(systemName: "gearshape.fill")
							.font(.title2)
							.padding(15)
							.background(Color.white.opacity(0.3))
							.foregroundColor(.white)
							.clipShape(Circle())
					}
					.padding(.trailing, 40)
				}
				Spacer()
			}
			.padding(.top, 20)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(.black)
    }
}

#Preview {
    ContentView()
}
