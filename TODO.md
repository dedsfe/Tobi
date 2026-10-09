# TODO

## Onboarding

Código em `Tobi/Onboarding/OnboardingView.swift`. Toda tela tem o palco do Tobi no topo (`TobiStage`), botões em Liquid Glass e motion de `Motion.swift`.

- [x] 1. Boas-vindas
- [x] 2. Gênero (Masculino, Feminino, Prefiro não dizer)
- [x] 3. Nascimento
- [x] 4. Altura (só cm)
- [x] 5. Objetivo: perder peso, manter, ganhar massa (decide a direção da meta e a proteína)
- [x] 6. Peso atual e peso-meta (meta só pra perder/ganhar; data-alvo ficou de fora)
- [x] 7. Nível de atividade
- [x] 8. Em quanto tempo: Tranquilo, Recomendado, Rápido (perder 0,25/0,5/0,75 kg por semana, no máximo 1% do peso; ganhar 0,15/0,25/0,5) e Personalizado (data; até 1,5% do peso e 2 kg por semana pra perder, 0,5 kg pra ganhar; aviso amarelo acima de 1% / 0,55%, vermelho acima de 1,5 kg). Pula pra quem quer manter.
- [x] 9. Suas metas: Mifflin-St Jeor × atividade ± o déficit/superávit do prazo. "Como calculei" e "Mudar meta" (edita todas as respostas e as calorias numa folha só). Salva meta e fatias dos macros no app
- [x] 10. Primeira refeição: a DayView de verdade escrevendo sozinha (`FirstMealDemo`), sem as opções do topo e sem salvar; ✨ em cada linha e as calorias aparecendo; "Continuar" no fim.
- [x] 11. Formas de registrar: palco de vidro rodando Escrever, Falar e Escanear com o rótulo de calorias de verdade, e pílulas de story que enchem e pulam de cena
- [x] 12. Tudo pronto: promessa no título ("Em março, você chega nos 65 kg"), curva do peso se desenhando com marcos vibrando, meta estourando com confete e pulso, números contando em 3 vidros, botão só no fim, depois o pedido de avaliação
- [x] 13. Notificações: os 3 lembretes (café 9:00, almoço 12:30, jantar 20:00) chegam na tela como no iPhone; "Ativar lembretes" pede a permissão e agenda exatamente esses; "Agora não" segue
- [x] 14. Paywall: anual (destacado, com a economia) e semanal, os dois com 3 dias grátis; linha do tempo do teste com as datas de verdade; StoreKit 2 em `TobiStore` (IDs e preços de reserva num lugar só, `Tobi.storekit` pra testar rodando pelo Xcode). O X abre a carta do Tobi com 24 horas de cortesia; a compra solta canhões de confete. Sem plano e sem as 24 horas, o app trava no paywall (Ajustes → Debug → "Travar o app"): em cima, o resumo das 24 horas (calorias subindo, barra da meta a partir de 50%, anéis de C/P/G); sem nada anotado, um cartão onde a pessoa testa o Tobi escrevendo o que comeu (`PaywallGate.swift`)
- [x] Paywall: os dois planos criados no App Store Connect pelo CLI `asc` (grupo Premium: anual R$ 99,90 nível 1, semanal R$ 12,90 nível 2, 3 dias grátis, 175 países, Ready to Submit)
- [x] Paywall: link de Privacidade em `PaywallLinks.privacy` aponta pra https://tobicalorias.vercel.app/privacidade (site em ~/Programação/Tobi Website, repo dedsfe/tobi-website, Vercel tobi-app; política já cita o RevenueCat)
- [x] Tela de alegria depois da compra (`PaywallJoy.swift`): datas reais do teste e botão "Ativar" o aviso pra quem negou notificação
- [x] Ajustes: "Gerenciar assinatura" e "Restaurar compras"
- [x] Ícone do Icon Composer (`Asset-Icon/TobiIcon.icon`) e build 0.1.0 (1) enviado pro App Store Connect em 08/10/2026
- [ ] App Store: página do app (prints, descrição, rótulos de privacidade iguais ao `PrivacyInfo.xcprivacy`, nota pro revisor sobre as 24 horas). Próximo build sobe o número (`CURRENT_PROJECT_VERSION` no project.yml)
- [ ] Paywall: testar 7 dias de teste e plano mensal (`docs/paywall-conversao.md`)
- [x] Anúncios: pedido de rastreamento (ATT) depois do onboarding (`Tracking.swift`), RevenueCat coleta IDFA/IDFV, manifesto e política do site atualizados
- [ ] Anúncios: SDKs do TikTok e da Meta + integrações de anúncio no RevenueCat; falta o André criar os apps nos painéis e passar os IDs (`docs/anuncios.md`)
- [x] RevenueCat: SDK observando as compras StoreKit 2 (`purchasesAreCompletedBy: .myApp`) e notificações da Apple (produção e sandbox) apontando pro RevenueCat
- [ ] RevenueCat: mandar os eventos de compra pras redes de anúncio (TikTok/Meta) e declarar "Compras" nos rótulos de privacidade da App Store
- [x] PostHog (US, projeto 654398): os mesmos eventos do Supabase com o mesmo `anon_id`, abrir/fechar o app e gravação de sessão com o que é digitado coberto
- [ ] PostHog: montar o funil do onboarding e o painel
- [ ] Testar onboarding em formato de chat (perguntas na voz do Tobi) contra as telas atuais
- [x] Medir abandono em cada tela: eventos anônimos no Supabase (`analytics_events`, coluna `ambiente` = debug ou producao), funil na view `onboarding_funnel`; sem rede, o evento espera no aparelho (`Tobi/App/Analytics.swift`)
- [ ] Trocar o 🐶 do `TobiStage` pelas animações do Tobi (depende da arte)

## Em espera

Ficam pra quando o Tobi tiver o que precisa.

- Login (Apple, Google, e-mail): precisa de servidor
- Apple Health: precisa da integração com o HealthKit
- Widget na tela de início e na tela bloqueada: precisa do widget
- Localização pra restaurantes: precisa de base de restaurantes
- Comparação de precisão com outros apps: precisa de benchmark de verdade
- Foto do prato, cardápio, Siri, Apple Watch
- Tela de preferências (alta proteína, pouco carboidrato): tirada porque não mudava nada; volta se tiver receitas
