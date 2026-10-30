-- Plan3D AI initial schema. Apply only to a dedicated Supabase project after review.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  preferred_language text not null default 'en' check (preferred_language in ('en','ar')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  status text not null default 'draft' check (status in ('draft','processing','ready','archived')),
  source_file_path text,
  source_file_name text,
  source_file_type text,
  dimensions jsonb not null default '{}'::jsonb,
  model_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_assets (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  asset_type text not null check (asset_type in ('floor_plan','preview_image','model_glb','model_stl','model_3mf','render')),
  storage_path text not null,
  file_name text not null,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.print_partners (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete set null,
  business_name text not null,
  city text,
  service_regions text[] not null default '{}',
  materials text[] not null default '{}',
  machines jsonb not null default '[]'::jsonb,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.print_quotes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  customer_user_id uuid not null references auth.users(id) on delete cascade,
  partner_id uuid not null references public.print_partners(id) on delete cascade,
  scale text not null,
  material text not null,
  finish text not null default 'raw',
  quantity integer not null default 1 check (quantity > 0),
  quoted_price numeric(12,2) check (quoted_price is null or quoted_price >= 0),
  currency char(3) not null default 'EGP',
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  status text not null default 'requested' check (status in ('requested','quoted','accepted','rejected','expired')),
  created_at timestamptz not null default now()
);

create table if not exists public.print_orders (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null unique references public.print_quotes(id),
  project_id uuid not null references public.projects(id) on delete cascade,
  customer_user_id uuid not null references auth.users(id) on delete cascade,
  partner_id uuid not null references public.print_partners(id),
  status text not null default 'pending' check (status in ('pending','confirmed','printing','quality_check','shipped','delivered','cancelled')),
  shipping_address jsonb,
  tracking_code text,
  total_amount numeric(12,2) not null check (total_amount >= 0),
  currency char(3) not null default 'EGP',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists projects_user_created_idx on public.projects(user_id, created_at desc);
create index if not exists assets_project_idx on public.project_assets(project_id);
create index if not exists quotes_customer_idx on public.print_quotes(customer_user_id, created_at desc);
create index if not exists quotes_partner_idx on public.print_quotes(partner_id, status);
create index if not exists orders_customer_idx on public.print_orders(customer_user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_assets enable row level security;
alter table public.print_partners enable row level security;
alter table public.print_quotes enable row level security;
alter table public.print_orders enable row level security;

create policy "profiles_select_own" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "projects_select_own" on public.projects for select to authenticated using ((select auth.uid()) = user_id);
create policy "projects_insert_own" on public.projects for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "projects_update_own" on public.projects for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "projects_delete_own" on public.projects for delete to authenticated using ((select auth.uid()) = user_id);

create policy "assets_select_own" on public.project_assets for select to authenticated using ((select auth.uid()) = user_id);
create policy "assets_insert_own" on public.project_assets for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "assets_delete_own" on public.project_assets for delete to authenticated using ((select auth.uid()) = user_id);

create policy "partners_read_active" on public.print_partners for select to authenticated using (is_active = true or owner_user_id = (select auth.uid()));
create policy "partners_insert_owner_pending" on public.print_partners for insert to authenticated with check (owner_user_id = (select auth.uid()) and is_active = false);
-- Partner activation and sensitive business-profile changes are admin/server operations only.

create policy "quotes_customer_read" on public.print_quotes for select to authenticated using (customer_user_id = (select auth.uid()));
create policy "quotes_customer_create" on public.print_quotes for insert to authenticated with check (customer_user_id = (select auth.uid()));
create policy "quotes_partner_read" on public.print_quotes for select to authenticated using (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid())));
create policy "quotes_partner_update" on public.print_quotes for update to authenticated using (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid())));

create policy "orders_customer_read" on public.print_orders for select to authenticated using (customer_user_id = (select auth.uid()));
create policy "orders_customer_create" on public.print_orders for insert to authenticated with check (customer_user_id = (select auth.uid()) and exists (select 1 from public.print_quotes q where q.id = quote_id and q.customer_user_id = (select auth.uid()) and q.status = 'accepted' and q.project_id = project_id and q.partner_id = partner_id));
create policy "orders_partner_read" on public.print_orders for select to authenticated using (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid())));
create policy "orders_partner_update" on public.print_orders for update to authenticated using (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.print_partners p where p.id = partner_id and p.owner_user_id = (select auth.uid())));

-- Create a PRIVATE Storage bucket named floor-plans in Supabase Storage.
-- Object path convention: <auth.uid()>/<project-id>/<filename>
create policy "floor_plans_select_own" on storage.objects for select to authenticated using (bucket_id = 'floor-plans' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "floor_plans_insert_own" on storage.objects for insert to authenticated with check (bucket_id = 'floor-plans' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "floor_plans_update_own" on storage.objects for update to authenticated using (bucket_id = 'floor-plans' and (storage.foldername(name))[1] = (select auth.uid())::text) with check (bucket_id = 'floor-plans' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "floor_plans_delete_own" on storage.objects for delete to authenticated using (bucket_id = 'floor-plans' and (storage.foldername(name))[1] = (select auth.uid())::text);