-- Jalankan seluruh SQL ini di Supabase Dashboard > SQL Editor.
-- Storage bucket dibuat private, file maksimal 10 MiB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('member-submissions', 'member-submissions', false, 10485760,
        array['application/zip','application/x-zip-compressed','application/octet-stream','text/markdown','text/plain'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.submission_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 100),
  description text not null default '' check (char_length(description) <= 1000),
  file_name text not null,
  storage_path text not null unique,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint submissions_file_extension check (lower(file_name) ~ '\.(zip|skill|md)$'),
  constraint submissions_storage_owner_path check (split_part(storage_path, '/', 1) = user_id::text)
);

alter table public.submission_admins enable row level security;
alter table public.submissions enable row level security;
revoke all on public.submission_admins from anon, authenticated;
revoke all on public.submissions from anon, authenticated;
grant select, insert on public.submissions to authenticated;

drop policy if exists "Read approved submissions" on public.submissions;
create policy "Read approved submissions" on public.submissions for select to anon, authenticated using (status = 'approved');
drop policy if exists "Members read own submissions" on public.submissions;
create policy "Members read own submissions" on public.submissions for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Admins read all submissions" on public.submissions;
create policy "Admins read all submissions" on public.submissions for select to authenticated using (
  exists (select 1 from public.submission_admins a where a.user_id = auth.uid())
);
drop policy if exists "Members submit own pending files" on public.submissions;
create policy "Members submit own pending files" on public.submissions for insert to authenticated with check (
  auth.uid() = user_id and status = 'pending'
  and split_part(storage_path, '/', 1) = auth.uid()::text
);

create or replace function public.is_submission_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.submission_admins a where a.user_id = (select auth.uid())) $$;
revoke all on function public.is_submission_admin() from public;
grant execute on function public.is_submission_admin() to authenticated;

create or replace function public.review_submission(submission_id uuid, new_status text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_submission_admin() then raise exception 'Tidak memiliki izin admin'; end if;
  if new_status not in ('approved','rejected') then raise exception 'Status tidak valid'; end if;
  update public.submissions set status = new_status, reviewed_at = now() where id = submission_id and status = 'pending';
  if not found then raise exception 'Pengajuan tidak ditemukan atau sudah ditinjau'; end if;
end;
$$;
revoke all on function public.review_submission(uuid, text) from public;
grant execute on function public.review_submission(uuid, text) to authenticated;

-- Storage RLS: user hanya bisa upload ke folder UID miliknya. Download hanya untuk file approved,
-- pemilik, atau admin. URL download yang dibuat UI bersifat signed dan berlaku 60 detik.
drop policy if exists "Members upload own submission files" on storage.objects;
create policy "Members upload own submission files" on storage.objects for insert to authenticated with check (
  bucket_id = 'member-submissions'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(name) ~ '\.(zip|skill|md)$'
);
drop policy if exists "Read approved or authorized submission files" on storage.objects;
create policy "Read approved or authorized submission files" on storage.objects for select to anon, authenticated using (
  bucket_id = 'member-submissions' and (
    exists (select 1 from public.submissions s where s.storage_path = storage.objects.name and s.status = 'approved')
    or (auth.uid() is not null and (storage.foldername(name))[1] = (select auth.uid())::text)
    or exists (select 1 from public.submission_admins a where a.user_id = (select auth.uid()))
  )
);
drop policy if exists "Members remove own unsubmitted files" on storage.objects;
create policy "Members remove own unsubmitted files" on storage.objects for delete to authenticated using (
  bucket_id = 'member-submissions' and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (select 1 from public.submissions s where s.storage_path = storage.objects.name)
);

-- Setelah akun admin mendaftar dan email terverifikasi, jalankan perintah berikut
-- dengan mengganti email admin. Jangan pernah memberi akses admin lewat input publik.
-- insert into public.submission_admins (user_id)
-- select id from auth.users where email = 'EMAIL_ADMIN_KAMU';
