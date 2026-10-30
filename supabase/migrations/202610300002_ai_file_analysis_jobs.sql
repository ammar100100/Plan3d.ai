create table if not exists public.ai_jobs (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 project_id uuid not null references public.projects(id) on delete cascade,
 source_file_path text not null,
 source_file_name text not null,
 source_file_type text not null,
 status text not null default 'queued' check (status in ('queued','processing','needs_review','completed','failed')),
 result jsonb not null default '{}'::jsonb,
 error_message text,
 model text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists ai_jobs_user_created_idx on public.ai_jobs(user_id,created_at desc);
create index if not exists ai_jobs_project_idx on public.ai_jobs(project_id);
alter table public.ai_jobs enable row level security;
create policy "ai_jobs_select_own" on public.ai_jobs for select to authenticated using ((select auth.uid())=user_id);
create policy "ai_jobs_insert_own" on public.ai_jobs for insert to authenticated with check ((select auth.uid())=user_id);
create policy "ai_jobs_update_own" on public.ai_jobs for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
grant usage on schema public to authenticated;
grant select,insert,update on public.ai_jobs to authenticated;
