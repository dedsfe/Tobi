import Foundation

/// Produto de marca como vem do Open Food Facts (dados do rótulo, licença ODbL).
struct BrandProductInfo: Sendable, Equatable {
    let barcode: String
    let name: String
    let brand: String?
    /// "350 ml", "200 g" — como está na embalagem.
    let quantity: String?
    /// Gramas/ml de uma porção ou da embalagem inteira, quando o rótulo diz.
    let servingGrams: Double?
    let per100: Nutrition
}

/// Cliente do Open Food Facts: busca por código de barras e por nome, só produtos com calorias.
/// https://openfoodfacts.github.io/openfoodfacts-server/api/
enum OpenFoodFacts {
    private static let fields = "code,product_name,product_name_pt,brands,quantity,serving_quantity,nutriments,countries_tags"
    private static let userAgent = "Tobi/0.1 (iOS; contador de calorias)"

    static func product(barcode: String) async throws -> BrandProductInfo? {
        var url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")!
        url.append(queryItems: [URLQueryItem(name: "fields", value: fields)])
        let response: ProductResponse = try await get(url)
        guard response.status == 1, let product = response.product else { return nil }
        return product.info
    }

    /// Produtos vendidos no Brasil cujo nome tem todas as palavras buscadas.
    static func search(_ query: String, limit: Int = 5) async throws -> [BrandProductInfo] {
        var url = URL(string: "https://search.openfoodfacts.org/search")!
        url.append(queryItems: [
            URLQueryItem(name: "q", value: "\(query) countries_tags:\"en:brazil\""),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: fields),
        ])
        let response: SearchResponse = try await get(url)
        let words = FoodParser.tokenize(query)
        return response.hits
            .compactMap(\.info)
            .filter { info in
                let name = Set(FoodParser.tokenize("\(info.name) \(info.brand ?? "")"))
                return words.allSatisfy(name.contains)
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - JSON

    private struct ProductResponse: Decodable {
        let status: Int
        let product: Product?
    }

    private struct SearchResponse: Decodable {
        let hits: [Product]
    }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let product_name_pt: String?
        let brands: Brands?
        let quantity: String?
        let serving_quantity: Flexible?
        let nutriments: [String: Flexible]?

        var info: BrandProductInfo? {
            guard let code, let n = nutriments, let kcal = n["energy-kcal_100g"]?.value else { return nil }
            let name = [product_name_pt, product_name].compactMap { $0 }.first { !$0.isEmpty }
            guard let name else { return nil }
            let per100 = Nutrition(
                kcal: kcal,
                protein: n["proteins_100g"]?.value ?? 0,
                carbs: n["carbohydrates_100g"]?.value ?? 0,
                fat: n["fat_100g"]?.value ?? 0,
                sugar: n["sugars_100g"]?.value ?? 0,
                fiber: n["fiber_100g"]?.value ?? 0,
                sodium: (n["sodium_100g"]?.value ?? 0) * 1000  // vem em gramas
            )
            let serving = serving_quantity?.value.flatMap { $0 > 0 ? $0 : nil }
            return BrandProductInfo(barcode: code, name: name, brand: brands?.first, quantity: quantity,
                                    servingGrams: serving, per100: per100)
        }
    }

    /// `brands` vem como "Coca-Cola, Femsa" na busca por código e como lista na busca por nome.
    private struct Brands: Decodable {
        let first: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let list = try? container.decode([String].self) {
                first = list.first
            } else {
                first = try? container.decode(String.self).split(separator: ",").first.map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }

    /// Número que às vezes vem como texto ("200") no Open Food Facts.
    private struct Flexible: Decodable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                value = number
            } else if let text = try? container.decode(String.self) {
                value = Double(text.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }
}
