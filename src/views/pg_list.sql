-- DROP VIEW cron.pg_list;

create or replace view cron.pg_list as
select *
  from cron.pg_list();

alter table cron.pg_list owner to cron;
grant select on table cron.pg_list TO cron_role;

comment on view cron.pg_list is 'Lista aktualnych zadań CRON dla aktualnej bazy danych.
Superuser widzi zadania z wszystkich baz danych.
@summary Lista aktualnych zadań
@package core';
y
comment on column cron.pg_list.jobid is 'Id zadania z sekwencji lokalnej lub globalnej.';
comment on column cron.pg_list.database is 'Baza danych dla której utworzono zadanie.';
comment on column cron.pg_list.role is 'Rola/Użytkownik w ramach której zadanie będzie wykonane.';
comment on column cron.pg_list.minute is 'Minuta w której zadanie będzie wykonane.';
comment on column cron.pg_list.hour is 'Godzina w której zadanie będzie wykonane.';
comment on column cron.pg_list.dayofmonth is 'Dzień miesiąca w którym zadanie zostanie wykonane.';
comment on column cron.pg_list.month is 'Miesiąc wykonania zadania.';
comment on column cron.pg_list.dayofweek is 'Dzień tygodnia w którym zadanie będzie wykonane.';
comment on column cron.pg_list.last_start is 'Ostatnia data i godzina wykonania zadania (z tabeli log)';
comment on column cron.pg_list.this_start is 'Data i godzina w której rozpoczęto wykonanie tego zadania (z tabeli log)';
comment on column cron.pg_list.total_time is 'Całkowity czas wykonania zadania (z tabeli log)';
comment on column cron.pg_list.failures is 'Informacja o ilości wykonań zadania, które zakończyły sie błędem (z tabeli log).';
comment on column cron.pg_list.times is 'Ilość wykonań zadania (z tabeli log)';
comment on column cron.pg_list.command is 'Polecenie PostgreSQL, które zostanie wykonane.';
comment on column cron.pg_list.active is 'Czy zadanie jest aktywne.';
comment on column cron.pg_list.autoremove is 'Czy zadanie jest jednorazowe, zostanie automatycznie usunięte po wykonaniu.';
