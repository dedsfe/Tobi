-- Pedidos explícitos feitos no painel de um alimento não reconhecido.
begin;

create table public.food_requests (
    id uuid primary key,
    created_at timestamptz not null default now(),
    anon_id uuid not null,
    product_name text not null check (char_length(btrim(product_name)) between 1 and 200),
    normalized_name text not null check (char_length(btrim(normalized_name)) between 1 and 200),
    app_version text not null check (char_length(app_version) <= 32),
    build_env text not null check (build_env in ('debug', 'testflight', 'appstore')),
    ambiente text generated always as (case when build_env = 'debug' then 'debug' else 'producao' end) stored,
    status text not null default 'pending' check (status in ('pending', 'added', 'dismissed')),
    unique (anon_id, normalized_name, build_env)
);

alter table public.food_requests enable row level security;
revoke all on public.food_requests from anon, authenticated;
-- Função estreita: insere ou ignora duplicatas sem liberar leitura nem edição da tabela.
create function public.request_food(id uuid, anon_id uuid, product_name text,
                                    normalized_name text, app_version text, build_env text)
returns void language sql security definer set search_path = '' as $$
    insert into public.food_requests (id, anon_id, product_name, normalized_name, app_version, build_env)
    values ($1, $2, $3, $4, $5, $6)
    on conflict do nothing;
$$;
revoke all on function public.request_food(uuid, uuid, text, text, text, text) from public;
grant execute on function public.request_food(uuid, uuid, text, text, text, text) to anon, authenticated;

-- Acesso só para administração: os clientes não leem pedidos de outras pessoas.
create view public.food_requests_queue with (security_invoker = true) as
select normalized_name, ambiente,
       (array_agg(product_name order by created_at desc))[1] as product_name,
       count(distinct anon_id) as people_requesting,
       min(created_at) as first_requested_at,
       max(created_at) as last_requested_at
from public.food_requests
where status = 'pending'
group by normalized_name, ambiente
order by people_requesting desc, last_requested_at desc;
revoke all on public.food_requests_queue from anon, authenticated;

commit;
