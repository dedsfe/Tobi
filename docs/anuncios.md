# TikTok Ads e Meta Ads: o que preparar (08/10/2026)

Pesquisa feita pelo Codex (docs oficiais + leitura do código), revisada por mim.

**Resumo:**
- O app ainda não tem nenhum SDK de anúncio. Pra instalar, faltam os IDs que só você gera nos painéis (TikTok Events Manager e Meta for Developers, seção 4). Com eles na mão, a integração leva uma sessão.
- **Decisão sua antes de integrar:** pedir ou não a permissão de rastreamento (ATT). Se pedir, a política de privacidade e os rótulos da App Store mudam ("usado pra rastrear"), e a frase "não rastreamos você" da `docs/privacidade.md` precisa sair.
- Teste grátis e compra já estão separados nos eventos (`trial_started` e `paywall_purchased`), que era o primeiro bug pra medir anúncio direito.
- Smart+: a doc nova diz que App Campaigns no iOS rodam só em TikTok/Lemon8, sem Pangle, mas confere o relatório por placement mesmo assim.

---


## 1. O que precisa existir no app

- **TikTok App Events SDK**, produto SPM `TikTokBusinessSDK`, versão publicada verificada **1.7.2**. URL do pacote: [https://github.com/tiktok/tiktok-business-ios-sdk](https://github.com/tiktok/tiktok-business-ios-sdk). Não confundir com OpenSDK de login/compartilhamento. [Releases oficiais](https://github.com/tiktok/tiktok-business-ios-sdk/releases).
- **Meta iOS SDK**, produto SPM `FacebookCore`, módulo `FBSDKCoreKit`; base publicada verificada **18.1.1**. URL: [https://github.com/facebook/facebook-ios-sdk](https://github.com/facebook/facebook-ios-sdk). Fixe a versão validada no build Swift 6/iOS 26. [Releases oficiais](https://github.com/facebook/facebook-ios-sdk/releases).
- [project.yml](/Users/andrefelipe/Programação/Tobi/project.yml) ainda não declara esses pacotes e gera o Info.plist. A futura integração precisa sobreviver ao `xcodegen`, incluindo propriedades estruturadas do plist.
- Inicialize os SDKs uma vez no ciclo de lançamento, com ponte de `UIApplicationDelegate` para SwiftUI; encaminhe ativação do app conforme cada SDK. O ponto atual é `TobiApp.init()` em [TobiApp.swift](/Users/andrefelipe/Programação/Tobi/Tobi/App/TobiApp.swift:19).
- **Meta Info.plist:** `FacebookAppID`, `FacebookClientToken`, `FacebookDisplayName`; controle `FacebookAutoLogAppEventsEnabled` e `FacebookAdvertiserIDCollectionEnabled` explicitamente. Para eventos manuais, recomendo autolog desativado e ativação registrada pelo ciclo de vida. Nunca embarque o **Meta App Secret**. [Configuração no SDK oficial](https://github.com/facebook/facebook-ios-sdk/blob/v18.1.1/FBSDKCoreKit/FBSDKCoreKit/Settings.swift).
- **TikTok:** inicialização recebe `appId`, `tiktokAppId` e `accessToken` correspondente ao App Secret gerado para esse SDK; não invente uma chave plist `TikTokAppID` como substituto. Desative pagamento automático com `disablePaymentTracking()` se reportar manualmente. [Integração iOS oficial](https://business-api.tiktok.com/portal/docs?id=1739585432134657).
- **Correção sobre `SKAdNetworkItems`:** a Apple exige a lista no app **que exibe anúncios**. Tobi é o app anunciado; não precisa dela apenas para comprar instalações. Ele precisa registrar conversões. [Apple: responsabilidades de cada participante](https://developer.apple.com/documentation/storekit/skadnetwork).
- IDs de referência: **Meta:** `v9wttpbfk9.skadnetwork`, `n38lu8286q.skadnetwork`; **TikTok/Pangle:** `22mmun2rn5.skadnetwork`, `238da6jt44.skadnetwork`. Se futuramente exibir anúncios, cada ID entra em um dicionário `SKAdNetworkIdentifier` dentro do array `SKAdNetworkItems`; confira a lista vigente do fornecedor. [Meta](https://developers.facebook.com/docs/setting-up/platform-setup/ios/SKAdNetwork/), [Pangle](https://www.pangleglobal.com/zh/resource/27851), [Apple](https://developer.apple.com/documentation/storekit/configuring-a-source-app).
- `NSAdvertisingAttributionReportEndpoint` é **opcional**, para receber cópias de postbacks em servidor próprio; a tabela REST de analytics atual não é esse receptor. [Apple](https://developer.apple.com/documentation/storekit/verifying-an-install-validation-postback).
- **ATT: minha recomendação é pedir**, uma vez, com o app ativo e contexto claro, antes de habilitar tracking. Pode melhorar atribuição consentida; não garante desempenho. Use `NSUserTrackingUsageDescription`, por exemplo: “Com sua permissão, compartilhamos dados de uso com parceiros para medir nossos anúncios em apps e sites de outras empresas.”
- Negativa deve preservar o uso do app. SKAN/AdAttributionKit funcionam sem ATT; negar IDFA também proíbe substituí-lo por e-mail hash, UUID ou fingerprint para tracking. No Meta moderno/iOS 26, o SDK consulta o estado ATT; não force `isAdvertiserTrackingEnabled = true`. [Apple ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/), [SDK Meta](https://github.com/facebook/facebook-ios-sdk/blob/v18.1.1/FBSDKCoreKit/FBSDKCoreKit/Settings.swift).
- **AdAttributionKit:** framework nativo, sem pacote SPM ou entitlement especial para simples medição de instalação. A Apple recomenda sua adoção; a integração deve respeitar o suporte da rede e a interoperabilidade com SKAN, sem dois gestores concorrentes. [WWDC25](https://developer.apple.com/videos/play/wwdc2025/221/), [interoperabilidade](https://developer.apple.com/documentation/adattributionkit/adattributionkit-skadnetwork-interoperability).

## 2. Eventos e pontos exatos no Tobi

| Ação real | TikTok | Meta | Onde disparar |
|---|---|---|---|
| Primeira abertura após instalação | `InstallApp` automático | App Install pelo SDK; ativação `.activatedApp` | Inicialização/ciclo de vida de `TobiApp`; não criar uma segunda instalação manual. |
| Onboarding completo | Complete Tutorial | `.completedTutorial` | `TobiApp.body`, callback de `OnboardingView`, junto da gravação `didCompleteOnboarding = true`; evento persistente de primeira conclusão. |
| Trial StoreKit confirmado | Start Trial | `.startTrial` | `TobiStore.purchase(_:)`, somente no resultado `.verified`, após classificar a oferta como teste grátis. |
| Primeira assinatura paga, inclusive conversão do trial | Subscribe | `.subscribe` | Transação verificada em `purchase(_:)` ou no consumidor de `Transaction.updates` em `TobiStore.init()`. |
| Cada cobrança efetiva | Purchase | `.purchased` / `logPurchase` | Mesmo processamento central de transações, com valor e moeda reais, uma vez por transação. |

Nomes e suporte: [TikTok, eventos padrão, fevereiro/2025](https://ads.tiktok.com/help/article/all-supported-in-app-events), [instalação automática, março/2026](https://ads.tiktok.com/help/article/how-to-integrate-tiktok-app-events-sdk), [constantes oficiais Meta](https://github.com/facebook/facebook-ios-sdk/blob/v18.1.1/FBSDKCoreKit/FBSDKCoreKit/AppEvents/FBSDKAppEventName.m).

- **Bug de medição atual:** `PaywallStep.buy()` em [Paywall.swift](/Users/andrefelipe/Programação/Tobi/Tobi/Onboarding/Paywall.swift:205) registra `paywall_purchased` também no trial. Esse evento não pode ser encaminhado diretamente como receita.
- [TobiStore.purchase(_:) e init()](/Users/andrefelipe/Programação/Tobi/Tobi/Store/TobiStore.swift:47) hoje finalizam transações e atualizam acesso, sem registrar receita. Recomendo um processamento comum, com deduplicação persistente por `transaction.id`, usado pelos dois caminhos.
- Trial exige oferta **free trial**, não apenas `.introductory`, que também pode ser paga. Trial tem receita **zero**; não envie o preço anual futuro como compra. [Apple: informações da oferta](https://developer.apple.com/documentation/storekit/transaction/offer-swift.struct).
- Para cobrança brasileira, envie valor numérico, como `99.90`, e moeda `BRL`, obtidos de `transaction.price`/`transaction.currency`; não use `fallbackPrice` ou texto “R$ 99,90”. Não rotule outra moeda como BRL. [Apple: preço e moeda](https://developer.apple.com/documentation/storekit/transaction-properties).
- `Subscribe` identifica a primeira cobrança; `Purchase` registra receita. Não some os dois como duas vendas. Renovações geram somente a cobrança correspondente.
- `acceptFreePass()` e `TobiStore.grantFreePass()` dão **24 horas sem assinatura**: mantenha `free_pass_accepted` como evento próprio, fora do Start Trial usado para aquisição.
- `restore()`, consulta de entitlements, cancelamento e compra pendente não são novas vendas. Preserve [Analytics.track()](/Users/andrefelipe/Programação/Tobi/Tobi/App/Analytics.swift:25) para análise interna, sem encaminhar indiscriminadamente todos os eventos.

## 3. Conversion value e SKAN

- **Esquema conceitual recomendado:** fine CV `0` abertura, `1` onboarding, `2` trial semanal, `3` trial anual, `4` primeira cobrança semanal, `5` primeira cobrança anual. Reserve os demais valores.
- Janela **0 a 2 dias:** coarse `low` abertura/onboarding, `medium` trial, `high` pagamento imediato. Janela **3 a 7:** `low` retorno sem pagamento, `medium` primeira cobrança semanal, `high` anual. Janela **8 a 35:** sinal de continuidade paga, se observado.
- Trial de três dias normalmente converte na segunda janela; não espere essa receita no fine CV do primeiro postback. Fine detalhado depende de privacidade; posteriores são coarse. Não bloqueie janelas cedo no lançamento. [Apple: janelas e atrasos](https://developer.apple.com/documentation/storekit/receiving-postbacks-in-multiple-conversion-windows).
- **Um único gestor de CV.** Para MVP, TikTok pode gerir SKAN e Meta usar AEM quando elegível; desative o gestor SKAN da Meta com `FacebookSKAdNetworkReportEnabled = false`. Configure o esquema que a interface TikTok realmente suporta.
- Para SKAN nas duas redes, use um gestor único com esquema compatível, frequentemente um MMP. Com outro gestor, TikTok exige `disableSKAdNetworkSupport()` e configuração correspondente do esquema. Não aplique uma tabela própria sem alinhar a decodificação nas redes. [TikTok: conflitos e configuração](https://ads.tiktok.com/help/article/how-to-integrate-tiktok-app-events-sdk).
- **AEM da Meta é distinto de SKAN**, não é uma tabela de conversion values nem dispensa ATT quando existe tracking. [Meta Blueprint](https://www.facebookblueprint.com/student/path/253008-use-app-events-to-target-optimize-measure).

## 4. Fora do código, nesta ordem

1. **App Store Connect:** criar app `com.andrefelipe.tobi`, obter Apple ID numérico; cadastrar os produtos anual/semanal no mesmo grupo, preços BRL e ofertas de três dias. O arquivo local `.storekit` não configura a loja. [Apple: assinaturas](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).
2. **Contas:** configurar TikTok Business Center/Ads Manager e Meta Business Portfolio, conta de anúncios, Página/Instagram, pagamentos e permissões sobre o app.
3. **TikTok Events Manager:** Connect data source → App → TikTok SDK; gerar TikTok App ID e App Secret, vinculando o app correto. Apple ID e TikTok App ID são diferentes. [Guia oficial, março/2026](https://ads.tiktok.com/help/article/how-to-integrate-tiktok-app-events-sdk).
4. **Meta for Developers:** criar app, adicionar plataforma iOS, bundle ID e App Store ID; obter App ID/Client Token, associar conta de anúncios e fonte de App Events. [SDK oficial](https://github.com/facebook/facebook-ios-sdk).
5. **Domínio:** publicar política de privacidade e suporte. Verificação de domínio para web e verificação de propriedade do app são processos distintos; cumpra a verificação solicitada pelo painel, sem tratar domínio como requisito universal de SKAN.
6. **Validar:** Test Events nas duas redes, instalação limpa, ATT aceito/negado, trial, pagamento, restauração e deduplicação. No Meta, verificar elegibilidade de app/eventos para AEM e diagnósticos antes de escolher otimização. Algumas páginas Meta exigiram login nesta consulta; confirme os requisitos exibidos na conta.
7. **Publicar e confirmar sinais reais:** teste TikTok não entra no reporting. Começar com App Promotion/instalação; migrar para Start Trial quando houver volume e elegibilidade, acompanhando custo por assinante pago. [TikTok: teste e publicação](https://ads.tiktok.com/help/article/how-to-integrate-tiktok-app-events-sdk).

## 5. Armadilhas que importam

- **Smart+ mudou:** a doc de App Campaigns de agosto/2026 lista iOS em TikTok/Lemon8, sem Pangle; o Smart+ atualizado também oferece controles de placement conforme disponibilidade. Confira o objetivo, OS e placements reais. Duplicar ad group não garante exclusão; publique TikTok-only quando disponível e confira o relatório por placement. [App Campaigns](https://ads.tiktok.com/resources/help/article/about-smart-plus-app-campaigns), [controles atualizados](https://ads.tiktok.com/business/en/blog/smart-plus-ai-performance-solution).
- Não combine pagamento automático, manual e servidor sem deduplicação. `transaction.originalID` identifica a cadeia da assinatura; `transaction.id` identifica cada cobrança.
- Para captar conversão do trial **com o app fechado**, prepare backend com App Store Server Notifications V2; `Transaction.updates` sozinho depende do app executando. Servidor também precisa respeitar consentimento e deduplicação. [Apple](https://developer.apple.com/documentation/appstoreservernotifications).
- **App Privacy:** declare dados coletados pelos SDKs e “Data Used to Track You” quando houver esse uso, mesmo só para quem aceita ATT. Confira manifests e relatório de privacidade; UUID interno não torna tracking anônimo. [Apple](https://developer.apple.com/app-store/user-privacy-and-data-use/).
- Tobi lida com saúde/nutrição: não envie peso, refeições, metas, idade, respostas ou textos pessoais às redes. Desative captura automática de conteúdo/telas que exponha isso. [Termos oficiais TikTok](https://ads.tiktok.com/i18n/official/policy/business-products-terms).
- SKAN tem atrasos e supressão por privacidade. Eventos recebidos, instalações atribuídas e assinaturas da App Store são métricas diferentes; não some resultados Meta e TikTok como usuários únicos.