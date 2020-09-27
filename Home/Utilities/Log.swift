//
//  Log.swift
//  Home
//
//  Created by Tim Owings on 9/22/20.
//

import os

private let subsystem = "com.javajoe.Home"

struct Log {
  static let service = OSLog(subsystem: subsystem, category: "service")
}
