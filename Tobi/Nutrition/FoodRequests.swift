import Foundation

/// Só o nome explicitamente solicitado sai do aparelho, nunca a nota ou a quantidade.
struct FoodRequest: Codable, Sendable, Equatable {
    let id: UUID
    let anonID: UUID
    let productName: String
    let normalizedName: String
    let appVersion: String
    let buildEnv: String

    enum CodingKeys: String, CodingKey {
        case id, anonID = "anon_id", productName = "product_name"
        case normalizedName = "normalized_name", appVersion = "app_version", buildEnv = "build_env"
    }

    init(name: String, anonID: UUID, appVersion: String, buildEnv: String) throws {
        let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty, name.unicodeScalars.count <= 200 else { throw FoodRequests.Failure.invalidName }
        self.id = UUID()
        self.anonID = anonID
        self.productName = name
        self.normalizedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
        self.appVersion = String(appVersion.prefix(32))
        self.buildEnv = buildEnv
    }

    var duplicateKey: String { "\(anonID)/\(buildEnv)/\(normalizedName)" }
}

actor FoodRequests {
    enum Submission: Sendable { case sent, queued }
    enum Delivery: Sendable { case sent, retryLater, rejected }
    enum Failure: Error { case invalidName, queueFull, rejected }
    typealias Post = @Sendable (FoodRequest) async -> Delivery
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let shared = FoodRequests(file: storageFile)
    private static var storageFile: URL {
        let testing = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        return URL.applicationSupportDirectory.appendingPathComponent(testing ? "food-requests-testing.json" : "food-requests.json")
    }

    private let file: URL
    private let post: Post
    private var pending: [FoodRequest]?
    private var flushing = false

    init(file: URL, post: @escaping Post = { await FoodRequests.post($0) }) {
        self.file = file
        self.post = post
    }

    static func send(name: String) async throws -> Submission {
        let testing = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let anonID = UUID(uuidString: testing ? "A080E2B5-A367-4C21-ABAF-CC0A61698DC1" : Analytics.anonID) ?? UUID()
        let request = try FoodRequest(name: name, anonID: anonID,
                                     appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                                     buildEnv: await Analytics.buildEnv())
        return try await shared.submit(request)
    }

    func submit(_ request: FoodRequest) async throws -> Submission {
        try load()
        let existing = pending!.first { $0.duplicateKey == request.duplicateKey }
        let target = existing ?? request
        if existing == nil {
            guard pending!.count < 100 else { throw Failure.queueFull }
            // Persiste antes de tentar a rede. Se o disco falhar, a interface não promete um pedido salvo.
            try save(pending! + [target])
            pending!.append(target)
        }
        let outcomes = try await flush()
        if outcomes[target.id] == .rejected { throw Failure.rejected }
        return outcomes[target.id] == .sent ? .sent : .queued
    }

    func retryPending() async {
        do { _ = try await flush() } catch { /* A fila permanece no disco para a próxima abertura. */ }
    }

    private func load() throws {
        guard pending == nil else { return }
        if FileManager.default.fileExists(atPath: file.path) {
            pending = try JSONDecoder().decode([FoodRequest].self, from: Data(contentsOf: file))
        } else { pending = [] }
    }

    private func save(_ requests: [FoodRequest]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(requests).write(to: file, options: .atomic)
    }

    private func flush() async throws -> [UUID: Delivery] {
        try load()
        guard !flushing else { return [:] }
        flushing = true
        defer { flushing = false }
        var outcomes: [UUID: Delivery] = [:]
        while let request = pending!.first {
            let delivery = await post(request)
            outcomes[request.id] = delivery
            if delivery == .retryLater { break }
            // Outros pedidos podem entrar enquanto a rede responde. Remove só o que foi enviado.
            let remaining = pending!.filter { $0.id != request.id }
            try save(remaining)
            pending = remaining
        }
        return outcomes
    }

    static func post(_ request: FoodRequest, fetch: Fetch = { try await URLSession.shared.data(for: $0) }) async -> Delivery {
        var http = URLRequest(url: URL(string: "https://wluqzlfkclrjocdjlmeu.supabase.co/rest/v1/rpc/request_food")!)
        http.httpMethod = "POST"
        http.timeoutInterval = 12
        http.setValue("sb_publishable_cryhZudzqSF0tlHwCTKQAg_v0OXxHic", forHTTPHeaderField: "apikey")
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        do {
            http.httpBody = try JSONEncoder().encode(request)
            let (_, response) = try await fetch(http)
            guard let response = response as? HTTPURLResponse else { return .retryLater }
            if (200..<300).contains(response.statusCode) { return .sent }
            if [400, 413, 422].contains(response.statusCode) { return .rejected }
            return .retryLater
        } catch { return .retryLater }
    }
}

enum FoodRequestState {
    case idle, sending, sent, queued, failed
}
