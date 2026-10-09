-- Cada novo toque explícito conta. Reenvios de transporte continuam idempotentes pelo UUID.
begin;

alter table public.food_requests
    drop constraint food_requests_anon_id_normalized_name_build_env_key;

create or replace view public.food_requests_queue with (security_invoker = true) as
select normalized_name, ambiente,
       (array_agg(product_name order by created_at desc))[1] as product_name,
       count(distinct anon_id) as people_requesting,
       min(created_at) as first_requested_at,
       max(created_at) as last_requested_at,
       count(*) as requests_received
from public.food_requests
where status = 'pending'
group by normalized_name, ambiente
order by requests_received desc, people_requesting desc, last_requested_at desc;
revoke all on public.food_requests_queue from anon, authenticated;

commit;
