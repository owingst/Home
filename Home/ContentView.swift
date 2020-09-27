//
//  ContentView.swift
//  Home
//
//  Created by Tim Owings on 9/22/20.
//

import SwiftUI
import Combine

struct ContentView: View {
    
    @ObservedObject var net = Webservice()
    
    var body: some View {
        
        ZStack {

            VStack (spacing: 25) {
                
                HStack (spacing: 125) {
                    VStack {
                        Text(self.net.temp).bold()
                            .lineLimit(1)
                            .font(Font.custom("Montserrat-Bold", size: 30.0))
                            .overlay(Circle()
                                .stroke(Color.blue,lineWidth: 8)
                                .frame(width: 150, height: 150,  alignment: .leading))
                            .padding()
                        Image(systemName: "thermometer")
                            .imageScale(.large)
                    }
                    VStack {
                        Text(self.net.humidity).bold()
                            .lineLimit(1)
                            .font(Font.custom("Montserrat-Bold", size: 30.0))
                            .overlay(Circle()
                                .stroke(Color.blue,lineWidth: 8)
                                .frame(width: 150, height: 150,  alignment: .leading))
                            .padding()
                        Image(systemName: "cloud.drizzle")
                            .imageScale(.large)
                    }
                }
                .padding()
                .frame(width: 300, height: 175)
                
                if (self.net.stale) {
                    Image(systemName: "asterisk.circle.fill")
                        .imageScale(.large)
                    Text("Temp/Humidity Data may be stale")
                }
                
                if (self.net.tempBattery == 1) {
                    Image(systemName: "battery.25")
                        .imageScale(.large)
                    Text("Low Temp/Humidity Battery")
                }
                Text("The Garage Door is:")
                    .bold()
                    .font(.title)
                    .background(Color.black)
                
                Text(self.net.doorStatus)
                    .font(Font.custom("Montserrat-Bold", size: 25.0))
                    .foregroundColor((self.net.doorStatus=="Closed") ? .red : .green)

                if (self.net.doorBattery == 1) {
                    Image(systemName: "battery.25")
                        .imageScale(.large)
                    Text("Low Tilt Sensor Battery")
                }
                Button(action: {
                    DispatchQueue.main.async {
                        self.net.openDoor()
                    }
                }) {
                    if (self.net.doorStatus == "Closed") {
                        Text("Open Garage Door")
                            .fontWeight(.bold)
                            .font(.title)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(40)
                            .foregroundColor(.white)
                        
                    } else {
                        Text("Close Garage Door")
                            .fontWeight(.bold)
                            .font(.title)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(40)
                            .foregroundColor(.white)
                    }
                }.fixedSize(horizontal: true, vertical: false)
                Button(action: {
                    DispatchQueue.main.async {
                        self.net.getTemp()
                        self.net.getDoorStatus()
                    }
                }) {
                    Text("Refresh")
                        .fontWeight(.bold)
                        .font(.title)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(40)
                        .foregroundColor(.white)
                }.fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
