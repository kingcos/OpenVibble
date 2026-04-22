// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
