# Estados do Tobi no onboarding

Proposta baseada no fluxo atual de `Tobi/Onboarding/OnboardingView.swift` e na demonstração em `Tobi/Views/DayView.swift`. Ainda não aplicada ao app.

## Estados reutilizáveis

| Estado | Expressão e movimento | Onde usar |
| --- | --- | --- |
| Alegre | Sorriso atual, olhos relaxados, língua com movimentos leves e descanso, orelhas independentes. Uma pequena inclinação de recepção ao entrar. | Boas-vindas. |
| Atento | Cabeça mais centralizada, piscadas suaves, menos movimento da língua e olhares ocasionais. Mantém o sorriso discreto. | Gênero, aniversário, altura, peso e prazo. |
| Curioso | Inclinação leve da cabeça, olhos encontram um alvo e a cabeça acompanha depois. Orelhas respondem com atraso. | Objetivo e atividade. |
| Apresentando | Olhar breve para o cartão de metas abaixo, retorno ao centro e idle contente. | Suas metas e retorno dos ajustes da meta. |
| Celebrando | Expressão alegre um pouco mais marcada, movimento breve da língua e das orelhas; termina naturalmente no estado Apresentando. | Primeira apresentação do plano pronto. |

## Reações à interação

- Selecionar uma opção: uma piscada e uma inclinação discreta confirmam a interação. A reação é igual para todas as opções de gênero, objetivo e atividade.
- Confirmar data, altura ou peso: reagir depois de confirmar e fechar o seletor, sem acompanhar cada valor da roleta.
- Peso e prazo: manter uma expressão acolhedora também quando houver uma orientação de correção. Não associar felicidade, tristeza ou reprovação ao valor escolhido.
- Voltar: entrar no estado da tela anterior, sem repetir uma comemoração.
- Plano: apresentar e celebrar a chegada do plano, sem introduzir uma espera artificial. O cálculo atual é síncrono.
- Demonstração da primeira refeição: manter a tela real existente. Ela não tem `TobiStage`; não inserir o cachorro ali nesta proposta. A conclusão já usa a legenda de pronto e o botão Continuar.

## Integração e acabamento

Manter uma única instância do personagem no palco existente, com a mesma posição e altura. Trocar os parâmetros do comportamento e combinar gestos pontuais com o idle, preservando a identidade e os pivôs das peças.

Interpolar os parâmetros ao trocar de estado. Cancelar gestos da tela anterior, evitar reiniciar todos os relógios a cada seleção e não atrasar a navegação para terminar uma reação. Apresentação e comemoração acontecem uma vez por entrada pertinente, não a cada redesenho ou ajuste de calorias.

Ao pausar, ir ao fundo ou ativar Movimento Reduzido, suspender movimentos. A expressão estática de cada estado continua visível. Validar entradas, saídas, retorno e seletores apenas no iPhone físico antes de aplicar ao onboarding.

Os estados combinam os canais já presentes: olhos/piscada, olhar, inclinação da cabeça, orelhas e língua. A integração ainda requer parâmetros de intensidade e uma transição entre estados; o onboarding atual continua com o emoji estático.
