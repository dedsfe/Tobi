import Foundation

/// O que a tela "Primeira refeição" escreve sozinha, linha por linha, pra mostrar o Tobi calculando.
/// Os testes garantem que a base reconhece tudo (nada de "?" na demonstração).
enum FirstMealDemo {
    static let lines = [
        "Café da manhã",
        "2 ovos mexidos e 1 pão francês",
        "café com leite",
        "Almoço",
        "arroz, feijão e bife",
    ]

    /// Ritmo da escrita: tempo por letra e pausa no fim de cada linha.
    static let letterDelay: Duration = .milliseconds(45)
    static let linePause: Duration = .milliseconds(550)
}
