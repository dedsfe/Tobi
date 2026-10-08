# Paywall que converte: pesquisa (08/10/2026)

Pesquisa feita pelo Codex (web + leitura do código), revisada por mim.

**Minhas correções antes de usar:**
- **Item 6 (toggle de teste grátis): não fazer.** Desde janeiro de 2026 a Apple reprova paywall com toggle de trial (§3.1.2), e a Superwall confirmou isso com a Apple. Ver `docs/revisao-apple.md`.
- **Item 5 (desconto logo depois do X): arriscado.** Mostrar um preço menor no instante em que a pessoa recusa já foi reprovado como manipulação (§5.6). A carta de 24 horas grátis é segura. Desconto, só por Offer Code ou Win-Back Offer da Apple, fora do momento da recusa.
- **Bug de medição: já corrigido.** O início do teste grátis agora grava `trial_started` e só a cobrança de verdade grava `paywall_purchased`.

Ordem que eu seguiria: item 4 (cumprir o "Te aviso antes", é pequeno e também tira um risco da revisão), depois item 1 (7 dias de teste) e item 2 (mensal no lugar do semanal), um de cada vez, com o funil medindo.

---

Li os quatro arquivos indicados. O Tobi já tem anual pré-selecionado, comparação semanal, trial, timeline, restauração, carta de saída e resumo real após a cortesia. O lembrete existe, mas depende de notificações autorizadas; `trialDays = 3` é fixo; `PaywallLinks.privacy = nil`.

Os números abaixo são benchmarks ou resultados divulgados pelos fornecedores. Não representam ganhos garantidos no Tobi; vários cases não publicam amostra nem significância. Esforço: **P** pequeno, **M** médio, **G** grande.

**1. Top 7 mudanças, por impacto esperado**

1. **Testar anual com 7 dias contra os atuais 3. Esforço M.** Manter preço e apresentação iguais; buscar registros em vários dias durante o teste. RevenueCat 2026: conversão trial → pago mediana de **37,4% em 5–9 dias versus 25,5% em até 4 dias**, diferença de 11,9 pontos percentuais. É correlação entre apps, não A/B de duração. Ler duração e elegibilidade da oferta do produto selecionado, evitando divergência com a timeline. [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps)

2. **Testar anual + mensal contra anual + semanal. Esforço M.** Manter anual destacado; começar mensal em **R$ 19,90**. O semanal atual custa R$ 670,80 em 52 cobranças, contra R$ 99,90 anual: uma diferença grande para um hábito contínuo. Em teste público, Preu AI adicionou anual à estrutura mensal e reportou **+80% em receita líquida por usuário e +22% em conversão de trial**; é evidência de outro segmento. Não eliminar semanal sem teste: a Adapty registra aproximadamente **56% da receita agregada em planos semanais**, sem provar superioridade em calorias. [Preu AI, 2026](https://superwall.com/case-studies/preu-ai), [Adapty, 2026](https://adapty.io/glossary/subscription-fatigue/)

3. **Trazer a prova pessoal para a primeira oferta. Esforço M.** O paywall inicial tem benefícios genéricos; mostrar objetivo escolhido, meta diária e a primeira refeição já registrada. Preservar o resumo verdadeiro do bloqueio. JourneyStamp reportou **+50% em conversão**, chegando a **7,3%**, ao testar ofertas por contexto, mensagens, preços e momentos: não foi personalização isolada. Testar separadamente uma avaliação real em português perto da decisão; não encontrei ganho isolado confiável de prova social em apps de calorias. [Case público, 2026](https://superwall.com/case-studies/journeystamp)

4. **Cumprir a promessa do lembrete para cada estado de permissão. Esforço P.** Hoje a timeline diz “Te aviso antes” mesmo quando o agendamento será ignorado. Oferecer autorização contextual após iniciar o trial, informar quando o aviso estiver desativado e testar aviso **48h antes** no trial de 7 dias, com data, preço e acesso ao gerenciamento da assinatura. **55,4% dos cancelamentos de trials de 3 dias acontecem no D0**; reduzir medo de cobrança é uma hipótese relevante, sem uplift isolado comprovado para notificações. [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps), [Superwall: lembretes e ansiedade, 2025](https://superwall.com/blog/two-paywall-trends-driving-arpu-gains)

5. **Testar recuperação após recusa e uma oferta distinta para ex-assinantes. Esforço G.** Comparar a carta atual de 24h com anual de **R$ 79,90 no primeiro ano**, renovando pelo preço claramente informado; oferecer também após cancelamento do checkout. Esse desconto é hipótese, não resultado comprovado. Para win-back, Unscripted reportou **mais de +30% em conversão de trial** e receita líquida por usuário quase dobrada com novo teste de 7 dias para usuários anteriormente cancelados. [Case, 2025](https://superwall.com/case-studies/unscripted)
   **Mecanismo Apple:** introductory offer para elegíveis, uma por grupo; promotional offer assinada para assinantes atuais/anteriores; win-back para expirados elegíveis, disponível desde iOS 18; Offer Codes para novos, atuais ou anteriores conforme configuração. Incluir resgate no `LockedPaywall`; não tratar a cortesia local como assinatura StoreKit. [Apple: modalidades](https://developer.apple.com/app-store/subscriptions/), [Offer Codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes)

6. **Testar toggle de trial como escolha real, depois dos testes anteriores. Esforço M.** Comparar trial explícito atual com escolha “Testar grátis” / “Assinar agora”, mostrando cobrança imediata quando aplicável. Linearity Curve fez A/B entre trial automático e opt-in e reportou **+10% na conversão do trial**, apesar de menos inícios. É outro segmento; medir pago por instalação para evitar celebrar seleção de usuários mais qualificados. No iOS, um toggle não desativa introductory offer do mesmo produto: usar produtos adequados no mesmo grupo; promotional offer não atende novos usuários sem histórico. [A/B, 2026](https://superwall.com/case-studies/linearity-curve), [Apple: elegibilidade](https://developer.apple.com/documentation/storekit/implementing-promotional-offers-in-your-app)

7. **Testar bloqueio atual contra acesso limitado após 24h. Esforço G.** Comparar `LockedPaywall` com histórico legível e uma anotação manual diária, cobrando recursos de IA e uso ampliado. RevenueCat: download → pago mediano de **10,7% com hard paywall versus 2,1% freemium**; isso não prova que endurecer o Tobi melhora receita. Manter o bloqueio atual como controle e medir conversão D35, receita D60 e reembolsos. [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps)

**Como validar:** randomização persistente, uma hipótese por vez e coortes com trials encerrados. Hoje `paywall_purchased` também registra início de trial; separar trial iniciado, primeira cobrança, renovação e reembolso. Cal AI divulgou **123 A/Bs e +31% relativo em trial → pago**, resultado do programa inteiro, não de um truque específico. Botsi/Fitness AI descreve controle simultâneo, mas não publica percentual verificável no case. [Cal AI, 2026](https://superwall.com/case-studies/cal-ai), [Botsi/Fitness AI](https://www.botsi.com/customers/fitness-ai)

**2. Preço recomendado para o Brasil**

**Faixa para testar:** anual **R$ 99,90–149,90**, mantendo R$ 99,90 como controle; mensal **R$ 19,90–29,90**; semanal **R$ 9,90–12,90**, se continuar vencendo em receita e retenção. Saída: **R$ 79,90 no primeiro ano**, com renovação explícita. São hipóteses comerciais, não preços ótimos demonstrados.

| Concorrente, App Store BR | Preços públicos reais encontrados |
|---|---|
| [Amy](https://apps.apple.com/br/app/amy-food-journal/id6753904989) | Mensal R$ 59,90; anual R$ 599,90 |
| [Yazio](https://apps.apple.com/br/app/yazio-contador-de-calorias/id946099227) | 12 meses R$ 89,90 e R$ 214,90; 3 meses R$ 89,99 |
| [MyFitnessPal](https://apps.apple.com/br/app/myfitnesspal-di%C3%A1rio-alimentar/id341232718) | Mensal R$ 31,90 e R$ 82,90; anual R$ 162,90 e R$ 329,90 |
| [Lose It!](https://apps.apple.com/br/app/lose-it-calorie-counter/id297368629) | IAPs de R$ 31,90 a R$ 309,90; periodicidade não identificada nos nomes |
| [Cal AI original, Viral Development](https://apps.apple.com/br/app/cal-ai-ai-calorie-tracker/id6480417616) | IAPs de R$ 14,90 a R$ 249,90; periodicidade não identificada nos nomes |
| [Fastic](https://apps.apple.com/br/app/fastic-perda-de-peso-jejum/id1459260306) | 1 mês R$ 79,90; 3 meses R$ 107,90; outros IAPs R$ 49,90–299,90 |
| [BetterMe Well-Being Coach](https://apps.apple.com/br/app/betterme-well-being-coach/id1264546236) | Semanal R$ 37,90; mensais R$ 19,90–99,90; anuais R$ 82,90 e R$ 124,90 |
| [Tecnonutri, brasileiro](https://apps.apple.com/br/app/tecnonutri-encontre-sua-dieta/id574794938) | Mensais R$ 25,90, R$ 30,90 e R$ 39,90; anual R$ 239,90 |

As fichas listam variantes, podendo incluir ofertas e produtos antigos; não garantem disponibilidade para toda conta. Não atribuí periodicidade quando o nome não permite confirmá-la. Não localizei A/B público com números verificáveis para Amy, Lose It!, MyFitnessPal, Yazio, Fastic ou BetterMe.

**3. O que NÃO fazer**

- **Enviar sem privacidade acessível:** `PaywallLinks.privacy` está `nil`, removendo o link desse fluxo. A Apple exige política na ficha e dentro do app; o bloqueio precisa permitir acesso. [Regra 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)
- **Prometer trial antes de confirmar oferta e elegibilidade:** o código começa com `trialEligible = true` e consulta apenas o anual. Evitar preço provisório apresentado como definitivo, datas fixas incompatíveis com StoreKit e mensagem de erro substituindo os termos de cobrança. [Apple: assinatura transparente](https://developer.apple.com/app-store/subscriptions/)
- **Inventar avaliações, descontos, escassez ou resultado corporal:** não usar contador que reinicia, “última chance” permanente nem promessa de emagrecimento garantido. Trocar a justificativa da carta sobre custo de IA por benefício e condições objetivas. [Apple: práticas enganosas](https://developer.apple.com/app-store/review/guidelines/)
- **Usar dados de saúde para publicidade ou preço individualizado:** personalizar a apresentação localmente; não enviar peso, metas ou refeições a redes de anúncios. [Regra 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)
- **Copiar checkout externo de cases americanos para a loja brasileira:** usar IAP e ofertas oficiais, respeitando as regras específicas da storefront. Também evitar animações que escondam preço, termos ou controles enquanto o usuário espera. [Regras 3.1.1–3.1.3](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)