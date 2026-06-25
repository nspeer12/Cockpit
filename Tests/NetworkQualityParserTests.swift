import Testing
@testable import Cockpit

@Test func parsesNetworkQualityVerboseSummary() async throws {
    let output = """
    ==== SUMMARY ====
    Uplink capacity: 123.067 Mbps
    Downlink capacity: 930.414 Mbps
    Responsiveness: Medium (158.257 milliseconds | 379 RPM)
    Idle Latency: 45.343 milliseconds | 1323 RPM
    Interface: en1
    Test Endpoint: usatl4-edge-fx-004.aaplimg.com
    Start: 2026-06-01 23:56:15.927
    End: 2026-06-01 23:56:33.805
    """

    let result = NetworkQualityParser.parse(output)

    #expect(result.uplinkMbps == 123.067)
    #expect(result.downlinkMbps == 930.414)
    #expect(result.responsiveness == "Medium")
    #expect(result.responsivenessMilliseconds == 158.257)
    #expect(result.responsivenessRPM == 379)
    #expect(result.idleLatencyMilliseconds == 45.343)
    #expect(result.idleLatencyRPM == 1323)
    #expect(result.interfaceName == "en1")
    #expect(result.testEndpoint == "usatl4-edge-fx-004.aaplimg.com")
    #expect(result.startTime == "2026-06-01 23:56:15.927")
    #expect(result.endTime == "2026-06-01 23:56:33.805")
    #expect(result.hasMeasuredCapacity)
}

@Test func parserHandlesMissingOptionalValues() async throws {
    let result = NetworkQualityParser.parse("networkQuality output unavailable")

    #expect(result.uplinkMbps == nil)
    #expect(result.downlinkMbps == nil)
    #expect(result.responsiveness == nil)
    #expect(!result.hasMeasuredCapacity)
}
