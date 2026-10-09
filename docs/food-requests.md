# Pedidos de novos produtos

Ao tocar um alimento vermelho, o usuário pode escolher **Pedir para adicionar**, abaixo das sugestões. Isso envia apenas o nome daquele alimento, um identificador anônimo e a versão/ambiente do app. A refeição permanece igual. Sem rede, o pedido fica no aparelho e tenta novamente a cada 30 segundos com o app aberto e ao voltar ao app.

No Supabase, consulte `public.food_requests_queue` para priorizar produtos pelo número de pessoas que os pediram. Filtre `ambiente = 'producao'` para excluir testes de desenvolvimento. TestFlight e App Store ficam juntos em produção; cada registro mantém `build_env` para distingui-los.

`public.food_requests` guarda os pedidos individuais. Depois de pesquisar o rótulo/fonte e adicionar o produto ao catálogo, altere `status` de `pending` para `added`. Use `dismissed` para pedidos descartados. Os pedidos resolvidos saem da fila. O app chama somente `request_food`, uma função que insere ou ignora duplicatas. Não há acesso direto à tabela nem permissão para ler os pedidos ou alterar o status.

O mesmo usuário não conta duas vezes para um nome normalizado no mesmo ambiente. Caixa, acentos e espaços repetidos são normalizados no app. Reenvios usam o mesmo UUID e a API ignora conflitos, inclusive quando a resposta se perde depois de gravar.

A migração é `supabase/migrations/20261009120000_food_requests.sql`. Testes de interface usam um identificador próprio (`a080e2b5-a367-4c21-abaf-cc0a61698dc1`) e uma fila local separada da fila real.
