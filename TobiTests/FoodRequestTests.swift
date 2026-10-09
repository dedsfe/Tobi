import Foundation
import Testing
@testable import Tobi

struct FoodRequestTests {
    private func request(_ name: String = "Produto Açúcar Novo") throws -> FoodRequest {
        try FoodRequest(name: name, anonID: UUID(), appVersion: "0.1.0", buildEnv: "debug")
    }
    private func file() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("outbox.json")
    }

    @Test func offlineRequestSurvivesRestartAndRetriesWithSameID() async throws {
        let file = file()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let request = try request()
        let offline = FoodRequests(file: file, post: { _ in .retryLater })
        #expect(try await offline.submit(request) == .queued)
        #expect(try JSONDecoder().decode([FoodRequest].self, from: Data(contentsOf: file)) == [request])
        let restarted = FoodRequests(file: file, post: { sent in
            #expect(sent.id == request.id)
            return .sent
        })
        await restarted.retryPending()
        #expect(try JSONDecoder().decode([FoodRequest].self, from: Data(contentsOf: file)).isEmpty)
    }

    @Test func repeatedNamesDoNotMultiplyOfflineRequests() async throws {
        let file = file()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let first = try request()
        let second = try FoodRequest(name: "  PRODUTO   ACUCAR novo  ", anonID: first.anonID, appVersion: "0.1.0", buildEnv: "debug")
        let queue = FoodRequests(file: file, post: { _ in .retryLater })
        _ = try await queue.submit(first)
        _ = try await queue.submit(second)
        #expect(try JSONDecoder().decode([FoodRequest].self, from: Data(contentsOf: file)) == [first])
    }

    @Test func rejectedRequestIsNotReportedAsSent() async throws {
        let file = file()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let queue = FoodRequests(file: file, post: { _ in .rejected })
        await #expect(throws: FoodRequests.Failure.self) { _ = try await queue.submit(request()) }
    }

    @Test func failedDiskWriteCannotPromiseSavedRequest() async throws {
        let file = file()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a directory".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let queue = FoodRequests(file: file.appendingPathComponent("outbox.json"), post: { _ in .sent })
        await #expect(throws: (any Error).self) { _ = try await queue.submit(request()) }
    }

    @Test func httpPayloadAndResponses() async throws {
        let request = try request()
        for code in [201, 400, 401, 429, 500] {
            let delivery = await FoodRequests.post(request) { http in
                #expect(http.httpMethod == "POST")
                #expect(http.url?.path == "/rest/v1/rpc/request_food")
                #expect(http.value(forHTTPHeaderField: "Prefer") == "return=minimal")
                let payload = try JSONSerialization.jsonObject(with: #require(http.httpBody)) as! [String: Any]
                #expect(Set(payload.keys) == ["id", "anon_id", "product_name", "normalized_name", "app_version", "build_env"])
                #expect(payload["product_name"] as? String == request.productName)
                return (Data(), HTTPURLResponse(url: http.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
            }
            #expect(delivery == (code == 201 ? .sent : code == 400 ? .rejected : .retryLater))
        }
    }

    @Test func invalidNamesAreRejectedBeforeNetwork() throws {
        #expect(throws: FoodRequests.Failure.self) { try request(" \n ") }
        #expect(throws: FoodRequests.Failure.self) { try request(String(repeating: "a", count: 201)) }
    }
}
