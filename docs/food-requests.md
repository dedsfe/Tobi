# Pedidos de novos produtos

Ao tocar um alimento vermelho, o usuário pode escolher **Pedir para adicionar**, abaixo das sugestões. Isso envia apenas o nome daquele alimento, um identificador anônimo e a versão/ambiente do app. A refeição permanece igual. Ao enviar, o painel mostra uma pequena confirmação verde com o símbolo se desenhando, “Pedido enviado” e um toque háptico; fecha sozinho após 1,8 segundo. Com Reduzir Movimento, o símbolo fica estático. Sem rede, o pedido fica no aparelho e tenta novamente a cada 30 segundos com o app aberto e ao voltar ao app.

No Supabase, consulte `public.food_requests_queue` para priorizar produtos pelo total de pedidos (`requests_received`). A fila também mostra quantas pessoas distintas pediram (`people_requesting`), para distinguir insistência de alcance. Filtre `ambiente = 'producao'` para excluir testes de desenvolvimento. TestFlight e App Store ficam juntos em produção; cada registro mantém `build_env` para distingui-los.

`public.food_requests` guarda os pedidos individuais. Depois de pesquisar o rótulo/fonte e adicionar o produto ao catálogo, altere `status` de `pending` para `added`. Use `dismissed` para pedidos descartados. Os pedidos resolvidos saem da fila. O app chama somente `request_food`, uma função que insere ou ignora duplicatas. Não há acesso direto à tabela nem permissão para ler os pedidos ou alterar o status.

O usuário pode reabrir o painel e solicitar o mesmo produto quantas vezes quiser: cada novo gesto tem um UUID novo e conta como mais um pedido, mesmo se estiver offline. Só as tentativas automáticas de entregar o mesmo pedido reutilizam seu UUID e não aumentam a contagem, inclusive quando a resposta se perde depois de gravar. Caixa, acentos e espaços repetidos são normalizados no app para agrupar os pedidos na fila.

As migrações são `20261009120000_food_requests.sql` e `20261009130000_repeated_food_requests.sql`. Testes de interface usam um identificador próprio (`a080e2b5-a367-4c21-abaf-cc0a61698dc1`) e uma fila local separada da fila real.
