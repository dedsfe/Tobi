# Issue #1: cobertura do parser de comida

137 frases em Swift Testing: 22 em cada grupo solicitado, mais cinco regressões adicionais no grupo de ditado. Cada caso confere nomes, quantidade em gramas, faixa de kcal e confiança por item; também verifica o total da linha.

## Validação real

- Destino exclusivo: iPhone 15 físico, `00008120-000A28A411F1A01E`.
- `xcodegen generate` foi executado após adicionar o arquivo.
- Baseline: 132 casos de cobertura, 19 frases com divergências, 68 expectativas falhando.
- Regressão adicional pedida no comentário da issue: `eu gostaria muito de ter um` reproduziu Mostarda, 6,30 kcal, `estimated`, antes da proteção de correspondência completa.
- Depois: as 137 frases passam; suíte de unidade passa sem falhas ou testes ignorados.
- A validação final usou uma cópia isolada dos arquivos deste trabalho, sem as mudanças fora de escopo de outras sessões. A proteção de correspondência completa da outra sessão foi incorporada conforme o pedido explícito na issue.
- Resultado final do xcresult: 42 testes declarados, 201 execuções no dispositivo (incluindo parâmetros), zero falhas e zero ignorados.
- Não foi iniciado nem utilizado simulador. A primeira tentativa dentro do sandbox não localizou o aparelho e não executou testes; as execuções no aparelho foram feitas fora do sandbox.

Comando de teste (mesma invocação na cópia isolada):

```sh
xcodebuild test -project Tobi.xcodeproj -scheme Tobi \
  -destination id=00008120-000A28A411F1A01E \
  -only-testing:TobiTests -derivedDataPath build/dd
```

Os valores da tabela abaixo são SAÍDAS CAPTURADAS no iPhone, arredondadas a duas casas apenas para leitura. O baseline original está em `build/coverage-baseline.log` e `build/coverage-baseline.xcresult`. A regressão adicional e a validação final estão em `/private/tmp/Tobi-issue1-verify/build/coverage-sentence-before.xcresult` e `coverage-sentence-after.xcresult`; os logs de ação exportados estão em `build/coverage-sentence-before-action.json` e `build/coverage-sentence-after-action.json`.

## Antes e depois

| Frase | Antes | Agora |
| --- | --- | --- |
| `pão francês com manteiga` | Pão francês: ~150.00 kcal (estimated); Manteiga: ~72.60 kcal (estimated) | Pão com manteiga: ~221.70 kcal (estimated) |
| `buchada` | não reconhecido: ?0.00 kcal (unknown) | Buchada de bode: ~125.00 kcal (estimated) |
| `milkshake` | não reconhecido: ?0.00 kcal (unknown) | Milk shake: ~483.27 kcal (estimated) |
| `brownie` | Brownie (Outback): ~290.00 kcal (estimated) | não reconhecido: ?0.00 kcal (unknown) |
| `um copo de milkshake` | não reconhecido: ?0.00 kcal (unknown) | Milk shake: 386.62 kcal (exact) |
| `cheeseburger` | não reconhecido: ?0.00 kcal (unknown) | Hambúrguer: ~500.00 kcal (estimated) |
| `whopper jr` | Whopper (Burger King): ~717.01 kcal (estimated) | Whopper Jr. (Burger King): 388.00 kcal (exact) |
| `1 concha de feijão` | Feijão: 106.40 kcal (exact) | Feijão: ~106.40 kcal (estimated) |
| `arroz e feijão, 10g de cada` | Arroz branco: ~192.00 kcal (estimated); Feijão: ~106.40 kcal (estimated) | Arroz branco: 12.80 kcal (exact); Feijão: 7.60 kcal (exact) |
| `2 colheres de arroz e feijão cada` | Arroz branco: 64.00 kcal (exact); Feijão: 30.40 kcal (exact) | Arroz branco: 64.00 kcal (exact); Feijão: ~30.40 kcal (estimated) |
| `1 colher de chá de açúcar` | Açúcar: 19.35 kcal (exact) | Açúcar: ~19.35 kcal (estimated) |
| `comi 2 ovos` | Ovo: ~73.00 kcal (estimated) | Ovo: 146.00 kcal (exact) |
| `eu comi duas bananas` | Banana: ~68.60 kcal (estimated) | Banana: 137.20 kcal (exact) |
| `hoje almocei 200g de arroz e 100g de frango` | Arroz branco: ~256.00 kcal (estimated); Frango grelhado: 159.00 kcal (exact) | Arroz branco: 256.00 kcal (exact); Frango grelhado: 159.00 kcal (exact) |
| `quero registrar 2 big mac` | Big Mac (McDonald's): ~524.00 kcal (estimated) | Big Mac (McDonald's): 1048.00 kcal (exact) |
| `tomei um copo de café com leite` | Café com leite: ~75.46 kcal (estimated) | Café com leite: 75.46 kcal (exact) |
| `100g de feijao e 2 ovoss` | Feijão: 76.00 kcal (exact); não reconhecido: ?0.00 kcal (unknown) | Feijão: 76.00 kcal (exact); Ovo: ~146.00 kcal (estimated) |
| `hoje tomei 350ml de refri` | Refrigerante: ~119.00 kcal (estimated) | Refrigerante: 119.00 kcal (exact) |
| `eu gostaria muito de ter um` | Mostarda: ~6.30 kcal (estimated) | não reconhecido: ?0.00 kcal (unknown) |

## O que mudou

- Quantidade de `cada` é lida antes de processar os alimentos, inclusive quando vem no fim.
- Uma lista fechada de palavras introdutórias de ditado é removida antes de ler contagens e medidas.
- Medidas caseiras sem peso específico no alimento continuam calculadas com o fallback existente, mas recebem `estimated`.
- `ovoss` é corrigido para `ovo` somente se a forma resultante existir no vocabulário, mantendo `estimated`.
- A correção de digitação só é aceita quando a frase corrigida é entendida inteira; isso impede interpretar palavras de frases sem comida como alimentos parecidos.
- Apelidos `pão francês com manteiga`, `milkshake` e `buchada` usam linhas IBGE já incluídas. `buchada` permanece estimado por escolher bode como preparo de referência.
- `cheeseburger` usa a estimativa genérica de hambúrguer que já existia.
- `whopper jr` e `whopper junior` apontam ao item `WHOPPER® Jr.` da tabela original do Burger King.
- Brownie sem rede não usa mais Outback. `brownie do outback` continua reconhecido e estimado.
- `fastfood.json` foi regenerado com o comando documentado no topo de `scripts/build_fastfood.py`. Todos os nutrientes, pesos e IDs dos 538 itens permaneceram idênticos; somente apelidos e sua ordem mudaram.
- O projeto recebe apenas as quatro referências de `FoodCoverageTests.swift`; referências do onboarding e de testes de outra sessão não entram neste commit.

## Fontes dos números

- TACO: IDs indicados em cada expectativa, sem copiar novos valores para a base.
- IBGE POF 2008–2009: `8570328-99` (pão com manteiga), `6907501-99` (milk shake), `7107204-99` (buchada de bode); aliases preservam nutrientes, porções e medidas.
- Redes: tabelas já transcritas em `data/fastfood/`; não foram inventados valores nem pesos.
- Faixas de teste: valor da fonte × gramas / 100, com tolerância de arredondamento de 1% ou 1 kcal, o que for maior.
- Pratos genéricos: somente estimativas que já existiam em `FoodDatabase.curated`. Nenhuma nova estimativa nutricional foi adicionada.

## Sem solução nutricional específica

| Entrada | Comportamento confirmado | O que falta |
| --- | --- | --- |
| `moqueca` | `unknown`, 0 kcal | Especificar baiana/capixaba ou obter uma fonte para o preparo escolhido; as duas variantes explícitas são reconhecidas. |
| `donut` | `unknown`, 0 kcal | Fonte genérica por preparo/porção; uma tabela do Habib's não deve roubar a comida comum. |
| `brownie` | `unknown`, 0 kcal | Fonte genérica e porção; a estimativa dos EUA fica restrita a `brownie do outback`. |
| `wrap` | `unknown`, 0 kcal | Recheio, porção e fonte da receita. |
| `burrito` | `unknown`, 0 kcal | Recheio, porção e fonte da receita. |
| `churros do bk` | Churro genérico do IBGE, `estimated`, 236,98 kcal | Tabela nutricional específica do BK. O nome é entendido parcialmente; não é tratado como item exato da rede. |

O caso de `churros do bk` não recebeu correção de produto: a expectativa inicial de desconhecido foi ajustada para o comportamento de nome parcialmente entendido previsto na issue. A tabela de antes/depois contém 19 frases com alteração real, incluindo a regressão adicional. As entradas sem dados não foram apagadas nem ignoradas: permanecem testadas. IA pode ajudar a identificar uma receita ou pedir detalhes, mas não substitui uma fonte nutricional.
