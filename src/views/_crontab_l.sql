--drop view cron._crontab_l;

create or replace view cron._crontab_l as
select l.pg_line, l.line
  from (select c.pg_line, case when c.pg_line is not null then c.pg_cmd_line else c.line end as line
          from (select case
                         when substr(line.line, 1, 11) = '#PG_CRONTAB'::text then line.line
                         else null::text
                       end as pg_line,
                       case
                         when substr(line.line, 1, 11) = '#PG_CRONTAB'::text then lead(line.line) over ()
                         else null::text
                       end as pg_cmd_line,
                       case
                         when btrim(
                         case
                           when substr(lag(line.line) over (), 1, 11) <> '#PG_CRONTAB'::text and substr(line.line, 1, 11) <> '#PG_CRONTAB'::text or lag(line.line) over () is null then line.line
                           else null::text
                         end) <> ''::text then line.line
                         else null::text
                       end as line
                  from unnest(string_to_array(_sys_crontab_l()::text, e'\n'::text)) line(line)) c) l
 where l.line is not null;

alter view cron._crontab_l owner to cron;
comment on view cron._crontab_l is 'cron native line with id if exists
@package core';