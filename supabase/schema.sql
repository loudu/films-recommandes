-- Films recommandés : base de données Supabase
-- À coller dans Supabase > SQL Editor > New query, puis « Run ».
-- On peut relancer ce script sans risque : il ne supprime aucune donnée.

-- 1. Liste des invités ------------------------------------------------------
create table if not exists public.invites (
  email    text primary key check (email = lower(trim(email))),
  name     text not null default '',
  is_admin boolean not null default false
);
alter table public.invites enable row level security;
-- Aucune règle d'accès : la liste n'est lisible que depuis le tableau de bord Supabase.
revoke all on public.invites from anon, authenticated;

-- 2. Les films --------------------------------------------------------------
create table if not exists public.films (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(trim(title)) between 1 and 200),
  director    text not null default '' check (char_length(director) <= 200),
  year        int check (year between 1888 and 2100),
  why         text not null default '' check (char_length(why) <= 4000),
  category    text check (category is null or char_length(category) between 1 and 40),
  author_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  author_name text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz
);
create index if not exists films_created_at_idx on public.films (created_at desc);

-- Texte simple uniquement : pas de balises HTML, pas d'adresse web, pas de caractères de contrôle
create or replace function public.is_plain_text(t text, multiline boolean default false) returns boolean
language sql immutable set search_path = '' as $$
  select t is null or (
        t !~ '[<>]'
    and t !~* '(https?:|ftp:|mailto:|javascript:|data:|file:|//|www\.)'
    and t !~* '[a-z0-9-]\.(com|fr|net|org|io|be|ch|eu|info|biz|tv|ly|gl|gg|xyz|app|dev|link|site|online|shop|uk|ru|cn)\M'
    and t !~ (case when multiline then '[\x01-\x09\x0B\x0C\x0E-\x1F\x7F]' else '[\x01-\x1F\x7F]' end)
  );
$$;

alter table public.films drop constraint if exists films_title_texte;
alter table public.films add constraint films_title_texte check (public.is_plain_text(title));
alter table public.films drop constraint if exists films_director_texte;
alter table public.films add constraint films_director_texte check (public.is_plain_text(director));
alter table public.films drop constraint if exists films_why_texte;
alter table public.films add constraint films_why_texte check (public.is_plain_text(why, true));
alter table public.films drop constraint if exists films_category_texte;
alter table public.films add constraint films_category_texte check (public.is_plain_text(category));

-- 3. Fonctions d'aide -------------------------------------------------------
create or replace function public.is_invited() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.invites
                 where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.invites
                 where email = lower(coalesce(auth.jwt() ->> 'email', '')) and is_admin);
$$;

-- Prénom de la personne connectée (pour l'afficher dans le site)
create or replace function public.me() returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object('name', name, 'is_admin', is_admin) from public.invites
  where email = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

revoke execute on function public.is_invited(), public.is_admin(), public.me() from public, anon;
grant execute on function public.is_invited(), public.is_admin(), public.me() to authenticated;

-- Remplit l'auteur à la création, l'heure de modification ensuite
create or replace function public.films_stamp() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.author_id   := auth.uid();
    new.author_name := coalesce((select name from public.invites
                                 where email = lower(coalesce(auth.jwt() ->> 'email', ''))), '');
    new.created_at  := now();
    new.updated_at  := null;
  else
    new.author_id   := old.author_id;
    new.author_name := old.author_name;
    new.created_at  := old.created_at;
    new.updated_at  := now();
  end if;
  return new;
end $$;
drop trigger if exists films_stamp on public.films;
create trigger films_stamp before insert or update on public.films
  for each row execute function public.films_stamp();

-- 4. Règles d'accès aux films ----------------------------------------------
alter table public.films enable row level security;
revoke all on public.films from anon;
grant select, insert, update, delete on public.films to authenticated;

drop policy if exists "invités lisent" on public.films;
create policy "invités lisent" on public.films for select to authenticated
  using (public.is_invited());

drop policy if exists "invités ajoutent" on public.films;
create policy "invités ajoutent" on public.films for insert to authenticated
  with check (public.is_invited());

drop policy if exists "auteur ou admin modifie" on public.films;
create policy "auteur ou admin modifie" on public.films for update to authenticated
  using (public.is_invited() and (author_id = auth.uid() or public.is_admin()))
  with check (public.is_invited());

drop policy if exists "auteur ou admin supprime" on public.films;
create policy "auteur ou admin supprime" on public.films for delete to authenticated
  using (public.is_invited() and (author_id = auth.uid() or public.is_admin()));

-- 5. Refuser la création de compte aux adresses non invitées ---------------
create or replace function public.only_invited_signup() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.invites where email = lower(coalesce(new.email, ''))) then
    raise exception 'Adresse non invitée';
  end if;
  return new;
end $$;
drop trigger if exists only_invited_signup on auth.users;
create trigger only_invited_signup before insert on auth.users
  for each row execute function public.only_invited_signup();
