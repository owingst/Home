//
//  WebService.swift
//  Home
//
//  Created by Tim Owings on 9/22/20.
//
import Foundation
import SwiftUI
import Combine
import MQTTClient
import os

class Webservice: NSObject, ObservableObject, MQTTSessionDelegate {
    
    let opendoorURL = "http://192.168.1.75:5000/opendoor"
    let doorstatusURL = "http://192.168.1.75:5000/getDoorStatus"
    let tempURL = "http://192.168.1.75:5000/getTemp"
    let mqttBroker = "192.168.1.75"
    let session = MQTTSession()!
    var connectCount = 0
    
    
    @Published var temp: String = "0"
    @Published var humidity: String = "0"
    @Published var tempBattery = 0
    @Published var doorBattery = 0
    @Published var doorStatus: String = "-----"
    @Published var stale: Bool = false
    
    override init() {
        
        super.init()
        session.transport = MQTTCFSocketTransport()
        session.transport.host = mqttBroker
        session.transport.port = 1883
        reconnect()
        session.delegate = self
        MQTTLog.setLogLevel(DDLogLevel.off)
        getTemp()
        getDoorStatus()
    }
    
    func reconnect() {
        
        if (connectCount > 9) {
            return
        } else {
            session.connect()
            connectCount += 1
        }
    }
    
    func timeDiff(ts: String) -> Int {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = NSLocale.current
        let tsdate = dateFormatter.date(from: ts)!
        let endDate = Date()
        let diff = hoursBetween(start: tsdate, end: endDate)
        return diff
    }
    
    func hoursBetween(start: Date, end: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: start, to: end).hour!
    }
    
    
    func getDate(strDate: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = dateFormatter.date(from: strDate)
        return date!
    }
    
    func checkEventTS(ts: String) {
        
        let diff = self.timeDiff(ts: ts)
        
        DispatchQueue.main.async {
            if (diff > 0) {
                self.stale = true
            } else {
                self.stale = false
            }
        }
    }
    
    func getTemp() {
        
        guard let url = URL(string: tempURL) else {
            os_log("Error: cannot create Temperature URL",log: Log.service, type: .info)
            return
        }
        
        let urlRequest = URLRequest(url: url)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        // make the request
        let task = session.dataTask(with: urlRequest) { [self]
            (data, response, error) in
            
            guard let dataResponse = data, error == nil else {
                os_log("error calling GET on /getTemp = %{Public}d",log: Log.service, type: .info, error!.localizedDescription)
                return
            }
            
            do {
                
                let jsonResponse = try JSONSerialization.jsonObject(with: dataResponse, options: []) as! [String: Any]
                let rc = jsonResponse["Result"] as! Int
                if (rc == 0) {
                    
                    let tempValue = jsonResponse["temperature"] as! Double
                    let humValue = jsonResponse["humidity"] as! Double
                    let ts = jsonResponse["eventTime"] as! String
                    let battValue = jsonResponse["batterylow"] as! Int
                    
                    checkEventTS(ts: ts)
                    
                    DispatchQueue.main.async {
                        self.temp = String(format: "%.0f", tempValue)
                        self.humidity = String(format: "%.0f", humValue)
                        self.doorBattery = battValue
                    }
                }
                else {
                    os_log("getTemp result is non zero",log: Log.service, type: .info)
                }
            } catch let parsingError {
                os_log("parsing error calling GET on /getTemp = %{Public}d",log: Log.service, type: .info, parsingError.localizedDescription)
            }
        }
        task.resume()
    }
    
    func getDoorStatus() {
        
        guard let url = URL(string: doorstatusURL) else {
            os_log("cannot create doorstatus URL",log: Log.service, type: .info)
            return
        }
        
        let urlRequest = URLRequest(url: url)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        // make the request
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            
            guard let dataResponse = data,  error == nil else {
                os_log("error calling GET on /getDoorStatus = %{Public}d",log: Log.service, type: .info, error!.localizedDescription)
                return
            }
            
            do {
                
                let jsonResponse = try JSONSerialization.jsonObject(with: dataResponse, options: []) as! [String: Any]
                
                let rc = jsonResponse["Result"] as! Int
                let doorValue = jsonResponse["status"] as! Int
                let battValue = jsonResponse["batterylow"] as! Int
                let ts = jsonResponse["eventTime"] as! String
                self.checkEventTS(ts: ts)
                
                if (rc == 0) {
                    
                    DispatchQueue.main.async {
                        if (doorValue == 1) {
                            self.doorStatus = "Closed"
                        }
                        else {
                            if (doorValue == 0) {
                                self.doorStatus = "Open"
                            } else {
                                os_log("Unknown doorValue = %{Public}d",log: Log.service, type: .info, error!.localizedDescription, doorValue)
                            }
                        }
                        self.doorBattery = battValue
                    }
                } else {
                    os_log("getTemp result is non zero",log: Log.service, type: .info)
                }
            }  catch let parsingError {
                os_log("parsing error calling GET on /getDoorStatus = %{Public}d",log: Log.service, type: .info, parsingError.localizedDescription)
            }
        }
        task.resume()
    }
    
    func openDoor() {
        
        guard let url = URL(string: opendoorURL) else {
            os_log("cannot create opendoor URL",log: Log.service, type: .info)
            return
        }
        let urlRequest = URLRequest(url: url)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in

            guard error == nil else {
                os_log("error calling GET on /openDoor = %{Public}d",log: Log.service, type: .info, error!.localizedDescription)
                return
            }
        }
        task.resume()
    }
    
    
    func handleEvent(_ session: MQTTSession!, event eventCode: MQTTSessionEvent, error: Error!) {
        switch eventCode {
        case .connected:
            os_log("handleEvent: connected",log: Log.service, type: .info)
            break
        case .connectionClosed:
            os_log("handleEvent: connectionClosed",log: Log.service, type: .info)
            reconnect()
            break
        case .connectionClosedByBroker:
            os_log("handleEvent: connectionClosedByBroker",log: Log.service, type: .info)
            reconnect()
            break
        case .connectionError:
            os_log("handleEvent: connectionError",log: Log.service, type: .info)
            reconnect()
            break
        case .connectionRefused:
            os_log("handleEvent: connectionRefused",log: Log.service, type: .info)
            break
        case .protocolError:
            os_log("handleEvent: protocolError",log: Log.service, type: .info)
            break
        @unknown default:
            os_log("handleEvent: Unknown MQTTStatus",log: Log.service, type: .info)
        }
    }
}

extension Webservice: MQTTSessionManagerDelegate {
    
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        
        do {
            
            let msg = String(data: data, encoding: .utf8)
            
            // Had an issue with converting data from newMessage. I was unable to get data to
            // to convert to utf8...so did it twice and that worked...must be something funky
            // with the MQTT stuff. Did not have an issue when using CocoaMQTT.
            if let payload = msg!.data(using: .utf8) {
                
                let jsonResponse = try JSONSerialization.jsonObject(with: payload, options: []) as! [String: Any]
                
                let msgType = jsonResponse["type"] as! String
                
                if (msgType.contains("door")) {
                    
                    let doorValue = jsonResponse["doorstatus"] as! Int
                    let battValue = jsonResponse["battery"] as! Int
                    
                    DispatchQueue.main.async {
                        if (doorValue == 1) {
                            self.doorStatus = "Closed"
                        } else {
                            if (doorValue == 0) {
                                self.doorStatus = "Open"
                            } else{
                                os_log("didReceiveMessage: Invalid doorValue %d",log: Log.service, type: .info, doorValue)
                            }
                        }
                        self.doorBattery = battValue
                    }
                } else if (msgType.contains("temp")) {
                    
                    let tempValue = jsonResponse["temperature"] as! Double
                    let humValue = jsonResponse["humidity"] as! Double
                    let battValue = jsonResponse["battery"] as! Int
                    
                    DispatchQueue.main.async {
                        self.temp = String(format: "%.0f", tempValue)
                        self.humidity = String(format: "%.0f", humValue)
                        self.tempBattery = battValue
                    }
                }
            } else {

                os_log("invalid Data in new message",log: Log.service, type: .info)
            }
        } catch let error {

            os_log("Exception %{Public}s converting data to json",log: Log.service, type: .error, error.localizedDescription)
        }
    }
    
    func connected(_ session: MQTTSession!) {
        os_log("connected: connected...",log: Log.service, type: .info)
        session.subscribe(toTopic: "Changed", at: .atMostOnce)
        os_log("connected: subscribed...",log: Log.service, type: .info)
    }
    
    func subAckReceived(_ session: MQTTSession!, msgID: UInt16, grantedQoss qoss: [NSNumber]!) {

        os_log("subAckReceived: Subscription accepted...",log: Log.service, type: .info)
    }
}


