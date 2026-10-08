-- Eventos anônimos do app (sem login, sem dado pessoal): o app só grava, ninguém de fora lê.
create table public.analytics_events (
    id bigint generated always as identity primary key,
    created_at timestamptz not null default now(),
    anon_id uuid not null,
    event text not null check (char_length(event) <= 64),
    step text check (char_length(step) <= 64),
    step_index smallint,
    properties jsonb not null default '{}'::jsonb check (pg_column_size(properties) <= 2048),
    app_version text check (char_length(app_version) <= 32),
    build_env text not null check (build_env in ('debug', 'testflight', 'appstore')),
    -- Etiqueta pra filtrar: "debug" é teste rodando pelo Xcode, "producao" é TestFlight ou App Store.
    ambiente text generated always as (case when build_env = 'debug' then 'debug' else 'producao' end) stored
);

create index analytics_events_event_created_at on public.analytics_events (event, created_at);

alter table public.analytics_events enable row level security;

revoke all on public.analytics_events from anon, authenticated;
grant insert on public.analytics_events to anon, authenticated;

create policy "app grava eventos" on public.analytics_events
    for insert to anon, authenticated with check (true);

-- Funil do onboarding, separado por ambiente (produção primeiro, debug embaixo).
-- Cada pessoa conta até a tela mais longe que viu.
-- "chegaram" = viram essa tela ou passaram dela (o prazo pulado por quem mantém o peso não vira queda).
-- "pararam_aqui" = essa foi a última tela que viram.
create view public.onboarding_funnel with (security_invoker = true) as
with telas as (
    select distinct step_index, step
    from public.analytics_events
    where event = 'onboarding_step_viewed'
),
mais_longe as (
    select ambiente, anon_id, max(step_index) as ultima
    from public.analytics_events
    where event = 'onboarding_step_viewed'
    group by ambiente, anon_id
),
ambientes as (
    select ambiente, count(*) as total from mais_longe group by ambiente
)
select
    a.ambiente,
    t.step_index as ordem,
    t.step as tela,
    count(m.anon_id) filter (where m.ultima >= t.step_index) as chegaram,
    round(100.0 * count(m.anon_id) filter (where m.ultima >= t.step_index) / a.total, 1) as pct_do_inicio,
    count(m.anon_id) filter (where m.ultima = t.step_index) as pararam_aqui
from ambientes a
cross join telas t
left join mais_longe m on m.ambiente = a.ambiente
group by a.ambiente, a.total, t.step_index, t.step
order by a.ambiente desc, t.step_index;

revoke all on public.onboarding_funnel from anon, authenticated;
