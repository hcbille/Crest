import Foundation
import XCTest

@testable import Crest

@MainActor
final class BrowserSpaceBrandingTests: XCTestCase {
    func testDeviceAppearanceIsExcludedFromSpacePersistence() throws {
        let original = BrowserSpaceBranding(colors: [.indigo, .gold])
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        XCTAssertNil(payload["tabAppearance"])
        XCTAssertNil(payload["addressAppearance"])
        // Ignore the unreleased per-Space prototype's fields when reading a review profile.
        payload["tabAppearance"] = ["pinFill": 0.7]
        payload["addressAppearance"] = ["border": 0.6]
        let restored = try JSONDecoder().decode(
            BrowserSpaceBranding.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertEqual(restored, original)
    }

    func testDeviceAppearancePersistsLocallyAndToleratesUnknownFields() throws {
        let firstName = "crest-test-appearance-" + UUID().uuidString
        let secondName = "crest-test-appearance-" + UUID().uuidString
        let first = try XCTUnwrap(UserDefaults(suiteName: firstName))
        let second = try XCTUnwrap(UserDefaults(suiteName: secondName))
        defer {
            first.removePersistentDomain(forName: firstName)
            second.removePersistentDomain(forName: secondName)
        }
        first.set(
            try JSONSerialization.data(withJSONObject: [
                "borders": "future", "pinFill": 0.7, "hoverFill": 4, "cornerRadius": 0,
            ]),
            forKey: BrowserDeviceAppearanceStore.tabsKey)
        let local = BrowserDeviceAppearanceStore(defaults: first)
        XCTAssertEqual(local.tabs.borders, .selected)
        XCTAssertTrue(local.tabs.dimsUnloadedTabs)
        XCTAssertEqual(local.tabs.pinFill, 0.7)
        XCTAssertEqual(local.tabs.hoverFill, 1)
        XCTAssertEqual(local.cornerRadius, 0)
        XCTAssertEqual(local.containerCornerRadius(padding: 4), 0)
        local.cornerRadius = 4
        XCTAssertEqual(local.containerCornerRadius(padding: 4), 8)
        local.cornerRadius = 40
        XCTAssertEqual(local.sidebarCornerRadius, 40)
        XCTAssertEqual(local.containerCornerRadius(), 10)
        XCTAssertEqual(local.containerCornerRadius(padding: 4), 14)
        local.cornerRadius = 24
        local.tabs.dimsUnloadedTabs = false
        local.address.border = 0.6
        let restored = BrowserDeviceAppearanceStore(defaults: first)
        XCTAssertEqual(restored.tabs, local.tabs)
        XCTAssertFalse(restored.tabs.dimsUnloadedTabs)
        XCTAssertEqual(restored.cornerRadius, 24)
        XCTAssertEqual(restored.address, local.address)
        let otherDevice = BrowserDeviceAppearanceStore(defaults: second)
        XCTAssertEqual(otherDevice.tabs, .init())
        XCTAssertEqual(otherDevice.cornerRadius, 10)
        XCTAssertEqual(otherDevice.address, .init())
    }

    func testResetAllLookAndFeelPersistsDefaultDeviceAppearance() throws {
        let name = "crest-test-appearance-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let appearance = BrowserDeviceAppearanceStore(defaults: defaults)
        appearance.tabs.dimsUnloadedTabs = false
        appearance.tabs.pinFill = 0.7
        appearance.address.border = 0.6
        appearance.cornerRadius = 24

        BrowserLookAndFeelDefaults.resetAll(
            appearance: appearance, chrome: defaults, density: defaults, folders: defaults)

        let restored = BrowserDeviceAppearanceStore(defaults: defaults)
        XCTAssertEqual(restored.tabs, BrowserLookAndFeelDefaults.tabs)
        XCTAssertTrue(restored.tabs.dimsUnloadedTabs)
        XCTAssertEqual(restored.address, BrowserLookAndFeelDefaults.address)
        XCTAssertEqual(restored.cornerRadius, BrowserLookAndFeelDefaults.cornerRadius)
    }
}
