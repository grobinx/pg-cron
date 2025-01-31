--DROP FUNCTION cron.pg_list();

CREATE OR REPLACE FUNCTION cron.pg_list()
 RETURNS TABLE(jobid bigint, database character varying, role character varying, minute character varying, hour character varying, dayofmonth character varying, month character varying, dayofweek character varying, last_start timestamp without time zone, this_start timestamp without time zone, total_time bigint, failures bigint, times bigint, command text, active character varying, autoremove character varying)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
begin
  return query
    select c.jobid, c.database, c.role, c.minute, c.hour, c.dayofmonth, c.month, c.dayofweek, c.last_start, c.this_start, c.total_time, c.failures, c.times, c.command, c.active, c.autoremove
      from (select cl.pgjobid as jobid, coalesce(_get_psql_opt('-d', cl.command), _get_psql_opt(1, cl.command))::varchar as database, 
                   substring(cl.command from 'set role "?([#$\w]+)"?;')::varchar as role, 
                   cl.minute, cl.hour, cl.dayofmonth, cl.month, cl.dayofweek, l.last_start,
                   (select l.start
                      from (select log.start, log.stop
                              from log
                             where log.jobid = cl.pgjobid
                             order by log.start desc
                             limit 1) l
                     where l.stop is null) as this_start,
                   l.total_time, l.failures, l.times,
                   substring(cl.command from 'set role "?[#$\w]+"?; (.*); reset role;') as command,
                   cl.active, 
                   case
                       when "position"(cl.command, ('perform remove(' || cl.pgjobid::text) || ');') > 0 then 'Y'
                       else 'N'
                   end::varchar as autoremove
              from _list() cl
         left join ( select log.jobid, count(
                           case
                               when not log.success then 1
                               else null::integer
                           end) as failures, max(
                           case
                               when log.stop is not null then log.start
                               else null::timestamp without time zone
                           end) as last_start, round(date_part('epoch', sum(log.stop - log.start))::numeric, 0)::bigint as total_time, count(0) as times
                      from log
                     group by log.jobid) l on cl.pgjobid::numeric = l.jobid
        where cl.pgjobid is not null) c
     where c.database = current_database() or
           (select pg_roles.rolsuper
              from pg_roles
             where pg_roles.rolname = session_user);
end;
$function$;

ALTER FUNCTION cron.pg_list() OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.pg_list() FROM public;
GRANT EXECUTE ON FUNCTION cron.pg_list() TO cron_role;
COMMENT ON FUNCTION cron.pg_list() IS '';
