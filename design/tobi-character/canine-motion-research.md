# Pesquisa: expressão e movimento canino para o Tobi

Pesquisa concluída em 8 de outubro de 2026. Nesta etapa não foram inspecionados os modos atuais nem alterados o código ou as malhas do app. As sugestões abaixo orientam a próxima revisão; ainda não são decisões de implementação.

## O que as fontes sustentam

- Um cão relaxado pode ter a boca fechada ou aberta, com a língua para fora. Relaxamento aparece no conjunto: olhos suaves, rosto sem tensão e orelhas em posição natural. Logo, a língua não precisa estar sempre visível para o personagem parecer contente. [Dogs Trust](https://www.dogstrust.org.uk/dog-advice/understanding-your-dog/body-language).
- Na atenção, as orelhas podem se orientar para a frente e a boca permanecer fechada, sem tensão. Em cães de orelha caída, é importante observar a base da orelha. A forma da raça muda como esse sinal aparece. [PetMD, revisão veterinária](https://www.petmd.com/dog/behavior/how-to-read-dog-body-language).
- Olhos suaves, olhar direto relaxado e boca aberta podem acompanhar contentamento. A posição das orelhas varia e deve ser lida com o restante da expressão. [Texas A&M Veterinary Medicine](https://vetmed.tamu.edu/news/pet-talk/understanding-canine-body-language/).
- Panting e lambidas também podem aparecer em desconforto. Não são sinais exclusivos de felicidade; a expressão completa e o contexto importam. [San Francisco SPCA](https://www.sfspca.org/resource/body-language/).
- Na animação, partes soltas acompanham o movimento principal em ritmos diferentes e podem continuar se acomodando depois que ele termina. Isso dá peso e flexibilidade. [Material de ensino de animação, BMCC/CUNY](https://openlab.bmcc.cuny.edu/mmp260/week-8/), [aula do animador Ferdinand Engländer](https://www.animatorisland.com/2900/).

## Tradução artística para o Tobi

A tabela é uma proposta para o personagem do produto, inspirada nas fontes; não é um diagnóstico do comportamento de um cão real.

| Estado | Boca e língua | Orelhas | Olhos e cabeça |
| --- | --- | --- | --- |
| Idle relaxado | Alternar repouso com a língua recolhida e pequenos trechos de boca aberta/língua exposta. | Caídas, com pequenos ajustes e acomodação depois dos movimentos da cabeça. | Piscar, observar e voltar a repousar. |
| Atento | Recolher a língua por completo e fechar suavemente a boca. | Elevar a base e orientar para a frente; conservar a ponta caída. | Encontrar um alvo e sustentar um olhar suave. |
| Curioso | Boca fechada ou discretamente aberta, conforme a pose. | Uma orelha pode se orientar antes da outra, mantendo um alvo coerente. | Inclinar a cabeça e sustentar a pose por um momento. |
| Alegre | Boca relaxada, língua aparecendo em alguns gestos, com pausas. | Soltas e responsivas à cabeça, sem rigidez. | Olhos suaves e expressão receptiva. |
| Apresentando | Expressão tranquila, sem depender de panting contínuo. | Acompanhar o gesto que orienta a atenção para o conteúdo. | Olhar para o cartão e retornar à pessoa. |
| Celebrando | Gesto breve mais expressivo, depois recuperar o repouso. | Maior resposta ao movimento da cabeça, com acomodação gradual. | Expressão alegre que se resolve naturalmente no estado seguinte. |

A revisão deve conferir quais modos realmente existem hoje e adaptar esse mapa ao fluxo atual.

## Capacidades que vale verificar no rig

### Língua e boca

A língua precisa de poses de extensão e recolhimento, com possibilidade de curvar a ponta. A boca precisa acompanhar essa mudança. O critério visual é que a língua entre na boca e desapareça por estar recolhida/oculta, sem um corte visível no meio da transição ou uma peça achatada ainda pendurada no focinho.

Checar se o modelo tem abertura e espaço interno suficientes para isso. Não assumir que uma boca desenhada como linha aceita um movimento de mandíbula sem alterar sua geometria.

### Orelhas

Cada orelha precisa conseguir elevar sua base, girar para a frente e voltar ao repouso. A ponta deve dobrar/acomodar com alguma independência da base. Isso preserva a identidade de orelha caída do Tobi e permite um sinal de atenção legível.

Checar movimentos em mais de um eixo e deformação ao longo da peça. A ligação com a cabeça deve continuar presa: mover a orelha inteira para cima pode fazê-la parecer descolada. Girar uma peça rígida também pode ser insuficiente para mostrar flexibilidade.

### Expressão e sequência

Definir primeiro poses estáticas claramente distintas. Depois construir sequências com motivo, por exemplo: percebe algo → recolhe a língua → orienta as orelhas → acompanha com olhos/cabeça → sustenta → relaxa.

Variações de ritmo e intensidade enriquecem essas ações, mas não substituem a mudança de pose. Cada parte conserva sua independência; quando o gesto tem um alvo, elas trabalham juntas para comunicar a mesma intenção.

## Caminhos técnicos pesquisados

Deformações de malha, também chamadas blend shapes/morph targets, permitem modelar formas orgânicas além do que rotação e escala conseguem expressar. Precisam preservar a correspondência dos vértices entre as poses. [Manual oficial do Blender: shape keys](https://docs.blender.org/manual/id/4.5/animation/shape_keys/introduction.html).

RealityKit fornece `BlendShapeWeightsComponent` para acessar os pesos de blend shapes presentes nos modelos. Isso é uma opção a avaliar, não uma indicação de que o asset atual já tenha esses alvos ou de que seja necessário trocar a ferramenta usada no projeto. [Documentação oficial da Apple](https://developer.apple.com/documentation/realitykit/blendshapeweightscomponent).

Na revisão, decidir entre poses/deformações procedurais e um rig com articulações a partir do modelo atual, da qualidade visual e da medição no iPhone físico. Não há estimativa de desempenho feita nesta pesquisa.

## Critérios para a futura conferência

- Existe uma pose com boca relaxada e língua completamente recolhida?
- A língua entra e sai sem atravessar o focinho ou desaparecer abruptamente?
- As orelhas mostram atenção pela base e orientação para a frente?
- A ponta conserva flexibilidade e o contorno de orelha caída?
- Os modos são reconhecíveis pela pose, mesmo com animação pausada?
- Os gestos têm início, sustentação e retorno, sem se repetir mecanicamente?
- As partes continuam encaixadas durante as transições extremas?
- Movimento Reduzido mantém uma expressão legível e estática?

A implementação e os testes serão feitos somente após a próxima solicitação do usuário, exclusivamente no iPhone físico.
