-- Opinião das pessoas sobre o app (o modal "O que você está achando do Tobi?").
-- O app só grava; quem lê é o André, pelo painel do Supabase (view feedback_recente).
create table public.app_feedback (
    id bigint generated always as identity primary key,
    created_at timestamptz not null default now(),
    anon_id uuid not null,
    sentiment text not null check (sentiment in ('gostou', 'nao_gostou')),
    message text check (char_length(message) <= 2000),
    -- A pessoa marcou que topa ser chamada pra conversar sobre o feedback.
    can_contact boolean not null default false,
    contact text check (char_length(contact) <= 200),
    app_version text check (char_length(app_version) <= 32),
    build_env text not null check (build_env in ('debug', 'testflight', 'appstore')),
    ambiente text generated always as (case when build_env = 'debug' then 'debug' else 'producao' end) stored
);

alter table public.app_feedback enable row level security;

revoke all on public.app_feedback from anon, authenticated;
grant insert on public.app_feedback to anon, authenticated;

create policy "app grava feedback" on public.app_feedback
    for insert to anon, authenticated with check (true);

-- O que as pessoas disseram, o mais novo primeiro.
create view public.feedback_recente with (security_invoker = true) as
select created_at, ambiente, sentiment, message, can_contact, contact, app_version
from public.app_feedback
order by created_at desc;
