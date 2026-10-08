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
- [x] 12. Tudo pronto: resumo do plano (cal por dia e quando chega na meta), confete nas cores dos macros e pedido de avaliação nativo depois de 1,6 s
- [ ] 13. Notificações: explica pra que serve, depois pede a permissão
- [ ] 14. Paywall: planos e linha do tempo do teste grátis
- [ ] Testar onboarding em formato de chat (perguntas na voz do Tobi) contra as telas atuais
- [ ] Medir abandono em cada tela
- [ ] Trocar o 🐶 do `TobiStage` pelas animações do Tobi (depende da arte)

## Em espera

Ficam pra quando o Tobi tiver o que precisa.

- Login (Apple, Google, e-mail): precisa de servidor
- Apple Health: precisa da integração com o HealthKit
- Widget na tela de início e na tela bloqueada: precisa do widget
- Localização pra restaurantes: precisa de base de restaurantes
- "24h por minha conta" quando a pessoa fecha o paywall: faz sentido quando tiver IA com custo
- Comparação de precisão com outros apps: precisa de benchmark de verdade
- Foto do prato, cardápio, Siri, Apple Watch
- Tela de preferências (alta proteína, pouco carboidrato): tirada porque não mudava nada; volta se tiver receitas
