-- =====================================================================
-- CENTRAL AVALIA BRASIL — banco de dados (Supabase)
-- Rodar uma vez em: Supabase → SQL Editor → New query → colar tudo → Run
-- =====================================================================

-- ---------- Perfis (1 por login) ----------
create table if not exists public.perfis (
  id        uuid primary key references auth.users on delete cascade,
  nome      text not null default '',
  email     text,
  papel     text not null default 'vendedor' check (papel in ('admin','vendedor')),
  ativo     boolean not null default false,
  criado_em timestamptz not null default now()
);

-- Quem está liberado para usar a central
create or replace function public.eh_ativo() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and ativo)
$$;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and ativo and papel = 'admin')
$$;

-- Ao criar um login: o PRIMEIRO vira admin liberado; os demais entram aguardando liberação
create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists (select 1 from perfis) into primeiro;
  insert into perfis (id, nome, email, papel, ativo)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', ''), new.email,
          case when primeiro then 'admin' else 'vendedor' end, primeiro);
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

-- ---------- Clientes (carteira) ----------
create table if not exists public.clientes (
  id          bigint generated always as identity primary key,
  empresa     text not null,
  contato     text,
  telefone    text,
  email       text,
  cidade      text,
  segmento    text,
  google_link text,
  status      text not null default 'lead' check (status in ('lead','negociando','cliente','perdido')),
  obs         text,
  vendedor_id uuid references public.perfis(id) default auth.uid(),
  criado_em   timestamptz not null default now()
);

-- ---------- Vendas ----------
create table if not exists public.vendas (
  id          bigint generated always as identity primary key,
  data        date not null default current_date,
  cliente_id  bigint references public.clientes(id) on delete set null,
  qtd         int not null default 1 check (qtd > 0),
  cor         text default 'azul',
  valor       numeric(12,2) not null default 0,
  custo       numeric(12,2) not null default 0,   -- custo da placa + envio que a empresa paga nessa venda
  canal       text default 'whatsapp',
  pagamento   text default 'pix',
  status      text not null default 'pago' check (status in ('pendente','pago','enviado','entregue','cancelado')),
  obs         text,
  vendedor_id uuid references public.perfis(id) default auth.uid(),
  criado_em   timestamptz not null default now()
);

-- ---------- Financeiro (entradas e saídas fora das vendas) ----------
create table if not exists public.lancamentos (
  id         bigint generated always as identity primary key,
  data       date not null default current_date,
  tipo       text not null check (tipo in ('custo','despesa','investimento','entrada')),
  categoria  text,
  descricao  text not null,
  valor      numeric(12,2) not null check (valor >= 0),
  pago       boolean not null default true,
  criado_por uuid references public.perfis(id) default auth.uid(),
  criado_em  timestamptz not null default now()
);

create index if not exists vendas_data_idx on public.vendas (data);
create index if not exists lanc_data_idx   on public.lancamentos (data);

-- ---------- Segurança (RLS) ----------
-- Regra: quem está liberado vê e edita tudo; excluir e gerenciar equipe só o admin.
alter table public.perfis      enable row level security;
alter table public.clientes    enable row level security;
alter table public.vendas      enable row level security;
alter table public.lancamentos enable row level security;

drop policy if exists perfis_ver    on public.perfis;
drop policy if exists perfis_editar on public.perfis;
create policy perfis_ver    on public.perfis for select using (id = auth.uid() or public.eh_ativo());
create policy perfis_editar on public.perfis for update using (public.eh_admin()) with check (public.eh_admin());

do $$
declare t text;
begin
  foreach t in array array['clientes','vendas','lancamentos'] loop
    execute format('drop policy if exists %1$s_ver on public.%1$s', t);
    execute format('drop policy if exists %1$s_criar on public.%1$s', t);
    execute format('drop policy if exists %1$s_editar on public.%1$s', t);
    execute format('drop policy if exists %1$s_excluir on public.%1$s', t);
    execute format('create policy %1$s_ver     on public.%1$s for select using (public.eh_ativo())', t);
    execute format('create policy %1$s_criar   on public.%1$s for insert with check (public.eh_ativo())', t);
    execute format('create policy %1$s_editar  on public.%1$s for update using (public.eh_ativo()) with check (public.eh_ativo())', t);
    execute format('create policy %1$s_excluir on public.%1$s for delete using (public.eh_admin())', t);
  end loop;
end $$;
