# Revisão Apple do paywall (08/10/2026)

Estado: antes da primeira submissão. Assinatura StoreKit 2 (anual e semanal, 3 dias grátis), paywall na tela 14, carta das 24 horas no X, app travado depois das 24 horas. Sem login, sem conta.

Veredito: **arriscado até resolver os 2 bloqueadores abaixo**. O resto é ajuste fino.

## Bloqueadores (sem isso a Apple reprova)

1. **Link de Privacidade** (§3.1.2, §5.1.1). `PaywallLinks.privacy` ainda é `nil` e o link nem aparece no paywall. O texto está pronto em `docs/privacidade.md`: publicar no site, colocar a URL em `PaywallLinks.privacy` e no campo "Privacy Policy URL" do App Store Connect.
2. **Assinaturas no App Store Connect** (§2.1). Sem isso o paywall mostra o preço de reserva e a compra falha com "A App Store não respondeu". Precisa: contrato de Apps Pagos ativo, os 2 planos no mesmo grupo, oferta introdutória de 3 dias grátis nos dois e os dois enviados junto com a primeira versão.

## Já corrigido hoje

- **Manifesto de privacidade** (§2.5.x, `Tobi/Resources/PrivacyInfo.xcprivacy`). O app usa UserDefaults, que é uma API que precisa de justificativa, e sem o manifesto a Apple barra o envio. Ele também declara o que sai do aparelho: uso do app, o código aleatório do aparelho e o texto da linha que vai pra IA. Nada ligado à pessoa e nada de rastreamento.
- **Termos de renovação completos** (§3.1.2). O rodapé agora diz que a cobrança é na conta Apple e que dá pra cancelar até 24 horas antes, nos Ajustes. **Falta conferir no iPhone 15** se continua cabendo sem rolar.

## Riscos (depende de quem revisa)

- **"3 dias de graça" maior que o preço** (§3.1.2). O título tem 32 pt e o preço do plano 25 pt. A Apple pede que o valor cobrado seja o preço mais visível. Muitos apps de calorias passam assim, mas se reprovar, a correção é diminuir o título ou aumentar o preço.
- **"Te aviso antes" na linha do tempo**. O aviso só chega se a pessoa ativou as notificações na tela 13. Quem tocou em "Agora não" recebe uma promessa que não vai se cumprir. Saída: pedir a permissão logo depois da compra, ou trocar o texto quando as notificações estiverem desligadas.
- **Contas de saúde** (§1.4.1). As metas usam Mifflin-St Jeor. "Como calculei" já explica, mas citar a fonte (Mifflin et al., 1990) ali reduz o risco de pedirem a referência.

## Ajustes pequenos

- **Restaurar e Gerenciar assinatura nos Ajustes**: hoje só existem no paywall. A Apple recomenda os dois nos Ajustes também (`.manageSubscriptionsSheet`). O `SettingsView` é da outra sessão, então não mexi.
- **Rótulos de privacidade no App Store Connect**: marcar igual ao manifesto. Dados de uso → interação com o produto, Identificadores → ID do aparelho, Conteúdo do usuário → outro conteúdo. Tudo "não vinculado a você" e "não usado pra rastrear".
- **Notas pro revisor**: explicar que o X dá 24 horas grátis e que depois disso o app pede a assinatura.

## O que está ok

Restaurar compras e Termos (EULA da Apple) no paywall, o X visível desde o começo, a carta das 24 horas (é cortesia grátis, não um desconto empurrado na saída), preço e período na frase de baixo, o selo de economia com a conta certa (85% contra 52 semanas), sem toggle de teste, sem contagem regressiva falsa, sem login antes de mostrar o app e todos os textos de permissão (câmera, microfone, fala).

## O que foi provado

Build de aparelho passou, e o manifesto está dentro do `Tobi.app` e é válido (`plutil -lint`). O app não rodou no iPhone porque ele estava fora do Mac.
