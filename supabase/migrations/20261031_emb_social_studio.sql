-- EMB SPARKLY Social Studio: additive schema only.
-- Review and apply in Supabase SQL Editor after confirming the existing admin UID.
-- No existing shop tables or customer/order records are modified.

create table if not exists public.emb_social_accounts (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('facebook','instagram','tiktok')),
  provider_account_id text not null,
  display_name text not null,
  page_id text,
  connected_by uuid references auth.users(id) on delete set null,
  token_secret_ref text, -- reference to server-side secret storage; never store raw OAuth tokens here
  scopes text[] not null default '{}',
  connection_status text not null default 'pending'
    check (connection_status in ('pending','connected','expired','revoked','error')),
  connected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, provider_account_id)
);

create table if not exists public.emb_social_posts (
  id uuid primary key default gen_random_uuid(),
  caption text not null default '',
  media_path text,
  media_type text check (media_type in ('image','video','carousel')),
  status text not null default 'draft'
    check (status in ('draft','pending_approval','approved','scheduled','publishing','published','failed','cancelled')),
  scheduled_at timestamptz,
  timezone text not null default 'Africa/Lagos',
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  published_at timestamptz,
  last_error text,
  idempotency_key text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.emb_social_post_targets (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.emb_social_posts(id) on delete cascade,
  account_id uuid not null references public.emb_social_accounts(id) on delete cascade,
  provider_post_id text,
  status text not null default 'queued'
    check (status in ('queued','publishing','published','failed','skipped')),
  published_at timestamptz,
  last_error text,
  attempts integer not null default 0 check (attempts >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, account_id)
);

create table if not exists public.emb_social_publish_logs (
  id bigint generated always as identity primary key,
  post_target_id uuid references public.emb_social_post_targets(id) on delete set null,
  event_type text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists emb_social_posts_status_schedule_idx
  on public.emb_social_posts(status, scheduled_at);
create index if not exists emb_social_targets_status_idx
  on public.emb_social_post_targets(status, updated_at);
create index if not exists emb_social_publish_logs_created_idx
  on public.emb_social_publish_logs(created_at desc);

alter table public.emb_social_accounts enable row level security;
alter table public.emb_social_posts enable row level security;
alter table public.emb_social_post_targets enable row level security;
alter table public.emb_social_publish_logs enable row level security;

-- Admin-only policies. Confirm this UUID is still the authorized EMB admin.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='emb_social_accounts' and policyname='emb_social_accounts_admin_all') then
    create policy emb_social_accounts_admin_all on public.emb_social_accounts
      for all to authenticated
      using (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid)
      with check (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='emb_social_posts' and policyname='emb_social_posts_admin_all') then
    create policy emb_social_posts_admin_all on public.emb_social_posts
      for all to authenticated
      using (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid)
      with check (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='emb_social_post_targets' and policyname='emb_social_targets_admin_all') then
    create policy emb_social_targets_admin_all on public.emb_social_post_targets
      for all to authenticated
      using (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid)
      with check (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='emb_social_publish_logs' and policyname='emb_social_logs_admin_all') then
    create policy emb_social_logs_admin_all on public.emb_social_publish_logs
      for all to authenticated
      using (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid)
      with check (auth.uid() = '1ec1684c-db5b-4032-a385-ac006a47fc08'::uuid);
  end if;
end $$;
