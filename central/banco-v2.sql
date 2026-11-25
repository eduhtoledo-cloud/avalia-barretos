-- =====================================================================
-- CENTRAL AVALIA BRASIL — atualização v2 (serviços, estoque, custos fixos)
-- Rodar depois do banco.sql
-- =====================================================================

-- Serviços da venda: placa, google_novo, google_atualizacao (pode ter mais de um)
alter table public.vendas add column if not exists servicos text[] not null default '{placa}';
alter table public.vendas alter column qtd set default 0;
alter table public.vendas drop constraint if exists vendas_qtd_check;
alter table public.vendas add constraint vendas_qtd_check check (qtd >= 0);

-- ---------- Estoque ----------
create table if not exists public.produtos (
  id         bigint generated always as identity primary key,
  nome       text not null,
  cor        text,                         -- azul / preta: usado para dar baixa automática nas vendas
  minimo     int not null default 0,       -- avisa quando o saldo ficar abaixo disso
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

create table if not exists public.movimentos (
  id          bigint generated always as identity primary key,
  data        date not null default current_date,
  produto_id  bigint not null references public.produtos(id) on delete cascade,
  tipo        text not null check (tipo in ('entrada','saida','ajuste')),
  qtd         int not null,                 -- entrada positiva, saída negativa, ajuste +/-
  custo_unit  numeric(12,2) not null default 0,
  venda_id    bigint references public.vendas(id) on delete cascade,
  obs         text,
  criado_por  uuid references public.perfis(id) default auth.uid(),
  criado_em   timestamptz not null default now()
);
create index if not exists mov_produto_idx on public.movimentos (produto_id);
create index if not exists mov_venda_idx   on public.movimentos (venda_id);

-- ---------- Custos fixos da empresa ----------
create table if not exists public.custos_fixos (
  id         bigint generated always as identity primary key,
  nome       text not null,
  categoria  text,
  valor      numeric(12,2) not null check (valor >= 0),
  dia        int check (dia between 1 and 31),
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);
alter table public.lancamentos add column if not exists custo_fixo_id bigint references public.custos_fixos(id) on delete set null;

-- ---------- Segurança ----------
alter table public.produtos     enable row level security;
alter table public.movimentos   enable row level security;
alter table public.custos_fixos enable row level security;

do $$
declare t text;
begin
  foreach t in array array['produtos','movimentos','custos_fixos'] loop
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

-- Baixa automática de estoque ao excluir/editar venda: o app recria os movimentos.
-- Vendedor precisa poder apagar a baixa da própria venda ao editar:
drop policy if exists movimentos_excluir on public.movimentos;
create policy movimentos_excluir on public.movimentos for delete
  using (public.eh_admin() or (public.eh_ativo() and venda_id is not null));

-- Produtos iniciais
insert into public.produtos (nome, cor, minimo)
select * from (values ('Placa NFC Google azul','azul',10), ('Placa NFC Google preta','preta',10)) v(nome,cor,minimo)
where not exists (select 1 from public.produtos);

-- ---------- v3: plaquinha Instagram na venda + ranking de avaliações ----------
alter table public.vendas add column if not exists qtd_insta int not null default 0;
alter table public.clientes add column if not exists place_id text;
create table if not exists public.avaliacoes_hist (
  id bigint generated always as identity primary key,
  cliente_id bigint not null references public.clientes(id) on delete cascade,
  data date not null default current_date,
  rating numeric(2,1),
  total int not null default 0,
  criado_em timestamptz not null default now(),
  unique (cliente_id, data)
);
alter table public.avaliacoes_hist enable row level security;
-- políticas: ver/criar/editar = eh_ativo(); excluir = eh_admin() (mesmo padrão das outras tabelas)

-- ---------- v4: tempo real (a central se atualiza sozinha) ----------
-- alter publication supabase_realtime add table public.clientes, public.vendas, public.lancamentos,
--   public.produtos, public.movimentos, public.custos_fixos, public.avaliacoes_hist, public.perfis;
