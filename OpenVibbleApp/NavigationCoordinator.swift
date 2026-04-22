// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Combine

/// Drives deep-link-initiated navigation from outside the view tree (e.g.
/// tapping the Live Activity chrome). `HomeScreen` consumes `pendingRoute`
/// and clears it after applying the change.
@MainActor
final class NavigationCoordinator: ObservableObject {
    enum Route: Equatable {
        case status
    }

    @Published var pendingRoute: Route?

    func handle(url: URL) {
        guard url.scheme == "openvibble" else { return }
        switch url.host {
        case "status":
            pendingRoute = .status
        default:
            break
        }
    }
}
