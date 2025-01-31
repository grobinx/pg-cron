-- DROP TABLE IF EXISTS cron.ctrl;

create table if not exists cron.ctrl (
    name name not null primary key,
    value text
);

alter table if exists cron.ctrl owner to cron;

comment on table cron.ctrl is 'Tablica ctrl zawiera wartości parametrów konfiguracji mechanizmu CRON po stronie bazy danych.
Takie jak użytkownik i hasło. Tabela ctrl jest dostępna tylko dla użytkownika CRON.
@summary Parametry konfiguracji
@package core';

comment on column cron.ctrl.name is 'Nazwa parametru';
comment on column cron.ctrl.value is 'Wartość parametru';