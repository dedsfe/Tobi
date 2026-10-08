import Foundation

/// Pergunta à IA (função `resolve-line` no Supabase, que chama o Jev) qual alimento da base é o
/// pedaço que o Tobi não entendeu. A IA só escolhe entre os candidatos que mandamos: o número
/// continua vindo sempre da tabela.
enum LineResolver {
    private static let url = URL(string: "https://wluqzlfkclrjocdjlmeu.supabase.co/functions/v1/resolve-line")!
    /// Chave pública do projeto (a do Jev fica guardada no Supabase).
    private static let key = "sb_publishable_cryhZudzqSF0tlHwCTKQAg_v0OXxHic"
    private static let cache = AnswerCache()
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    /// Os candidatos que a IA achou mais prováveis, o confirmado primeiro. Vazio se ela acha que
    /// não é comida ou que nenhum serve.
    static func suggestions(for text: String, among candidates: [Food], fetch: Fetch? = nil) async throws -> [Food] {
        try Task.checkCancellation()
        let text = bounded(text.trimmingCharacters(in: .whitespacesAndNewlines), to: 200)
        let sent = Array(candidates.prefix(40))
        guard !sent.isEmpty, !text.isEmpty else { return [] }
        let names = sent.map { bounded($0.name, to: 120) }
        let cacheKey = AnswerCache.Key(text: text, names: names)
        if fetch == nil, let indices = await cache.indices(for: cacheKey) {
            try Task.checkCancellation()
            return indices.map { sent[$0] }
        }
        let indices = selectedIndices(in: try await answer(for: text, among: names, fetch: fetch), count: sent.count)
        if fetch == nil { await cache.store(indices, for: cacheKey) }
        return indices.map { sent[$0] }
    }

    /// Qual dos nomes a IA escolheu e depois conferiu que é o mesmo alimento do texto. Nil se não
    /// é comida, se nenhum serve ou se ela ficou na dúvida: quem chama não salva nada.
    static func confirmed(_ text: String, among names: [String], fetch: Fetch? = nil) async throws -> Int? {
        try Task.checkCancellation()
        let text = bounded(text.trimmingCharacters(in: .whitespacesAndNewlines), to: 200)
        let names = names.prefix(40).map { bounded($0, to: 120) }
        guard !names.isEmpty, !text.isEmpty else { return nil }
        let answer = try await answer(for: text, among: names, fetch: fetch)
        guard (0.5...1).contains(answer.isFood), let id = answer.match, let index = Int(id), String(index) == id,
              names.indices.contains(index) else { return nil }
        return index
    }

    private static func answer(for text: String, among names: [String], fetch: Fetch?) async throws -> Answer {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "apikey")
        let body = Request(text: text,
                           candidates: names.enumerated().map { .init(id: String($0.offset), name: $0.element) })
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        if let fetch { (data, response) = try await fetch(request) }
        else { (data, response) = try await URLSession.shared.data(for: request) }
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        guard data.count <= 32_768 else { throw URLError(.dataLengthExceedsMaximum) }
        return try JSONDecoder().decode(Answer.self, from: data)
    }

    private static func selectedIndices(in answer: Answer, count: Int) -> [Int] {
        guard (0.5...1).contains(answer.isFood) else { return [] }

        let ids = [answer.match].compactMap { $0 } + answer.top.filter { (0.15...1).contains($0.p) }.compactMap(\.id)
        var seen = Set<Int>()
        return ids.compactMap { id in
            guard let index = Int(id), String(index) == id, (0..<count).contains(index),
                  seen.insert(index).inserted else { return nil }
            return index
        }
    }

    /// O limite do serviço conta unidades UTF-16, inclusive quando tem emoji.
    private static func bounded(_ text: String, to limit: Int) -> String {
        var count = 0
        return String(text.prefix { character in
            count += character.utf16.count
            return count <= limit
        })
    }

    private struct Request: Encodable {
        struct Candidate: Encodable { let id: String; let name: String }
        let text: String
        let candidates: [Candidate]
    }

    private struct Answer: Decodable {
        struct Option: Decodable { let id: String?; let p: Double }
        let isFood: Double
        let match: String?
        let top: [Option]
    }
}

/// Só índices e textos curtos; nunca guarda o diário nem modelos do banco.
private actor AnswerCache {
    struct Key: Hashable, Sendable { let text: String; let names: [String] }
    private struct Entry { let indices: [Int]; let expires: Date }
    private var entries: [Key: Entry] = [:]
    private var order: [Key] = []

    func indices(for key: Key) -> [Int]? {
        guard let entry = entries[key], entry.expires > .now else { return nil }
        return entry.indices
    }

    func store(_ indices: [Int], for key: Key) {
        order.removeAll { $0 == key }
        while order.count >= 40 { entries.removeValue(forKey: order.removeFirst()) }
        order.append(key)
        entries[key] = Entry(indices: indices, expires: .now.addingTimeInterval(300))
    }
}
