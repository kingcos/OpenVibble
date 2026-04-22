import Foundation
@preconcurrency import CoreBluetooth

public enum NUSCentralUUIDs {
    public static let serviceString = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    public static let rxString = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    public static let txString = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

    public static var service: CBUUID { CBUUID(string: serviceString) }
    public static var rx: CBUUID { CBUUID(string: rxString) }
    public static var tx: CBUUID { CBUUID(string: txString) }

    public static let claudeNamePrefix = "Claude"
}
