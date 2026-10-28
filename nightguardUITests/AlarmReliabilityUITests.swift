import Foundation
import XCTest

@MainActor
final class AlarmReliabilityUITests: XCTestCase {
    private struct SessionConfiguration: Decodable {
        let sessionId: String
        let sessionIndex: Int
        let controlURL: URL
        let hostURI: String
        let t0Sgv: Int
        let durationSeconds: Int
        let lowThresholdMgdl: Int
        let missedThresholdMinutes: Int
        let units: String
    }

    func testAlarmSession() async throws {
        let environment = ProcessInfo.processInfo.environment
        let configData = environment["TEST_RUNNER_SESSION_CONFIG"]
            .flatMap { FileManager.default.contents(atPath: $0) }
        guard let data = configData else {
            XCTFail("TEST_RUNNER_SESSION_CONFIG must name a readable session file")
            return
        }
        let config = try JSONDecoder().decode(SessionConfiguration.self, from: data)
        print("ALARM_RELIABILITY_CONFIG_LOADED sessionId=\(config.sessionId)")
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--reliability-host-uri", config.hostURI,
            "--reliability-low-threshold-mgdl", String(config.lowThresholdMgdl),
            "--reliability-units", config.units,
            "--reliability-missed-threshold-minutes", String(config.missedThresholdMinutes)
        ]
        print("ALARM_RELIABILITY_APP_LAUNCH sessionId=\(config.sessionId)")
        app.launch()

        let bgValue = app.staticTexts["reliability-bg-value"]
        let readyDeadline = Date().addingTimeInterval(180)
        var t0DisplayedAt: Int64?
        var bufferedEvents: [[String: Any]] = []
        var eventCount = 0
        let flushInterval = 5

        while Date() < readyDeadline && t0DisplayedAt == nil {
            if bgValue.waitForExistence(timeout: 1) {
                let value = bgValue.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if Int(value) == config.t0Sgv {
                    t0DisplayedAt = Self.wallClockMilliseconds()
                    let event = Self.sample(
                        app: app,
                        bgValue: bgValue,
                        sessionId: config.sessionId
                    )
                    bufferedEvents.append(event)
                    try await Self.post(
                        to: config.controlURL.appendingPathComponent("faults-start-at"),
                        body: [
                            "sessionId": config.sessionId,
                            "faultsStartAt": t0DisplayedAt!
                        ]
                    )
                    try await Self.flushEvents(
                        bufferedEvents,
                        controlURL: config.controlURL,
                        sessionId: config.sessionId
                    )
                    bufferedEvents.removeAll(keepingCapacity: true)
                }
            } else {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if t0DisplayedAt == nil && bgValue.exists {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        guard let t0DisplayedAt else {
            XCTFail("The session t0 reading was not displayed within 180 seconds")
            app.terminate()
            return
        }

        let sessionEnd = Date(timeIntervalSince1970: Double(t0DisplayedAt) / 1000)
            .addingTimeInterval(TimeInterval(config.durationSeconds))
        while Date() < sessionEnd {
            let event = Self.sample(
                app: app,
                bgValue: bgValue,
                sessionId: config.sessionId
            )
            bufferedEvents.append(event)
            eventCount += 1
            if eventCount % flushInterval == 0 {
                try await Self.flushEvents(
                    bufferedEvents,
                    controlURL: config.controlURL,
                    sessionId: config.sessionId
                )
                bufferedEvents.removeAll(keepingCapacity: true)
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        try await Self.flushEvents(
            bufferedEvents,
            controlURL: config.controlURL,
            sessionId: config.sessionId
        )
        bufferedEvents.removeAll(keepingCapacity: true)
        app.terminate()
    }

    private static func sample(
        app: XCUIApplication,
        bgValue: XCUIElement,
        sessionId: String
    ) -> [String: Any] {
        [
            "sessionId": sessionId,
            "hostWallClockMs": wallClockMilliseconds(),
            "bgValue": bgValue.exists ? bgValue.label : "",
            "lastUpdate": app.staticTexts["reliability-last-update"].label,
            "time": app.staticTexts["reliability-time"].label,
            "alarmReason": bgValue.value as? String ?? ""
        ]
    }

    private static func wallClockMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func flushEvents(
        _ events: [[String: Any]],
        controlURL: URL,
        sessionId: String
    ) async throws {
        guard !events.isEmpty else { return }
        try await post(
            to: controlURL.appendingPathComponent("events"),
            body: ["sessionId": sessionId, "events": events]
        )
    }

    private static func post(to url: URL, body: [String: Any]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "AlarmReliabilityUITests",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: "Gateway control returned a non-success response"]
            )
        }
    }
}
