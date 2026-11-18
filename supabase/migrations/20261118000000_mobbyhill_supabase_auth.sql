-- MobbyHill wallets now belong to Supabase Auth users, so players sign in with the email they already have.
alter table mh_wallets drop constraint if exists mh_wallets_user_id_fkey;
alter table mh_unlocks drop constraint if exists mh_unlocks_user_id_fkey;
alter table mh_payments drop constraint if exists mh_payments_user_id_fkey;
alter table mh_spends drop constraint if exists mh_spends_user_id_fkey;
delete from mh_spends; delete from mh_payments; delete from mh_unlocks; delete from mh_wallets;
alter table mh_wallets add constraint mh_wallets_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table mh_unlocks add constraint mh_unlocks_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table mh_payments add constraint mh_payments_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table mh_spends add constraint mh_spends_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
drop function if exists mh_signup(text, text);
drop function if exists mh_login(text);
drop table if exists mh_accounts;
