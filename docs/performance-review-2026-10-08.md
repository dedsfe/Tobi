# Revisão de desempenho do Tobi

Revisão por código e testes no Mac em 08/10/2026. Nenhuma execução, instalação,
captura de tela ou teste de interface no iPhone.

## Alterações

- **Parser e sugestões:** normalização e raízes dos alimentos preparadas uma vez.
  A abertura prepara a base fora da thread da interface; produtos salvos também
  são indexados em segundo plano. Comparações usam fatias sem criar arrays extras;
  a distância de edição reutiliza suas linhas de trabalho. A divisão de textos
  longos com medidas passa a ser iterativa, sem recursão.
- **Diário:** a nota do dia é buscada uma vez e reutilizada durante a edição.
  O cache de estimativas descarta revisões antigas gradualmente, com limite de
  500 entradas e 256 KB de chaves de texto. Resultados e estruturas também ocupam
  memória; esse limite não representa o consumo total do cache.
- **Editor:** faixas de linhas são reutilizadas quando o texto não muda. Atributos
  só são reaplicados às linhas alteradas. A coluna de calorias calcula o trecho
  visível com uma margem para rolagem e só atualiza o conteúdo quando necessário.
  A desmontagem libera os callbacks da tela.
- **Exportação:** abrir os Ajustes não calcula mais o CSV. O compartilhamento
  trabalha com cópias de valores, fora da interface, reaproveita refeições
  repetidas e verifica cancelamento durante a geração.
- **Buscas:** tarefas por linha têm identidade e cancelamento; respostas antigas
  não alteram outra linha ou outro dia. Sair da tela ou colocar o app em segundo
  plano cancela buscas pendentes.
- **Ditado:** cancela a inicialização ao sair da tela, invalida callbacks antigos,
  valida o formato antes de instalar o tap e desativa a sessão mesmo se a
  inicialização falhar. Uma sessão antiga não interrompe um novo ditado.
- **Scanner:** interrompe a câmera ao encontrar um código e enquanto apresenta
  o resultado; consultas são canceláveis. A configuração da lanterna usa uma
  fila serial, sem bloquear a interface.
- **Animações:** timelines de voz pausam fora do uso/primeiro plano. As demonstrações
  do onboarding suspendem suas tarefas em segundo plano; prévias nutricionais
  calculam fora do corpo da view. Reduce Motion desliga o avanço automático e
  mostra a demonstração escrita completa.

## Medições

Executável Swift em Release no Mac, usando os arquivos reais do projeto por links
simbólicos. Valores de uma execução, sem compilação concorrente na medição final.
Não são tempos de iPhone nem medições de frames da interface.

| Trabalho | Antes | Depois |
| --- | ---: | ---: |
| 20 consultas de sugestões | 11.580,22 ms | 13,58 ms |
| 100 notas de 10 linhas, sem cache | 941,77 ms | 943,90 ms |
| Construção inicial da base | 467,37 ms | 620,57 ms |
| Índice de 100 produtos salvos | 10,19 ms | 19,80 ms |

O índice antecipa trabalho: a construção inicial ficou mais cara e guarda dados
normalizados adicionais, mas sai da thread da interface e elimina o reprocessamento
da base a cada sugestão. O cálculo nutricional comum permaneceu equivalente, sem
ganho significativo nesse cenário. As sugestões mantiveram nomes e ordem nas
12 consultas comparadas; a soma nutricional permaneceu 171.718,0000000007 kcal.

O CSV atual com 500 notas de 10 linhas repetidas levou 18,76 ms. Não foi registrada
uma medição comparável do CSV anterior. O espectro de voz levou 11,01 ms para
3.000 buffers sintéticos e já usava uma fila de áudio; não foi reescrito.

## Validação

- 88 testes de lógica, em 13 suites, passaram no Mac, incluindo os novos testes
  de desempenho, sugestões, texto extenso, distância de edição, CSV e cancelamento.
- Compilação `build-for-testing` para o SDK de iOS Simulator: passou.
- Análise estática `analyze`: passou.
- Os testes UIKit do editor e cache foram compilados; não foram executados.
- O pacote temporário de testes usa os arquivos reais e exclui testes que exigem
  views iOS. O `Package.swift` compartilhado não foi alterado; o teste de paywall
  referenciava views excluídas do target de Mac.
- `git diff --check`: passou.

A loja usa APIs assíncronas e espera suspensa para a cortesia. O carregamento 3D
já compartilha o modelo e ocorre fora da interface; o código da outra sessão foi
preservado. Não foi feita redução de assets, nem medida do tamanho instalado.

## Limites e próxima avaliação

Código e testes de lógica não comprovam ausência de travamentos em todo aparelho.
FPS, pico de memória, aquecimento, abertura a frio, câmera e ditado reais ainda
precisam de avaliação no iPhone. Notas muito longas continuam exigindo trabalho
proporcional ao texto; o histórico usado para contar a sequência de dias também
merece perfil com uma base grande. Não alterei essas regras de produto sem uma
medição que justificasse outra arquitetura.

Os arquivos compartilhados contêm alterações anteriores de outras sessões.
As otimizações permanecem no working tree para revisão conjunta, sem um commit
que incorpore trabalho alheio.
