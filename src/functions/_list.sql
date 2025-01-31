--DROP FUNCTION cron._list();

CREATE OR REPLACE FUNCTION cron._list()
 RETURNS TABLE(pgjobid bigint, active character varying, minute character varying, hour character varying, dayofmonth character varying, month character varying, dayofweek character varying, command text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return query
    select ct.pgjobid, 
           case
             when ct.aline[1] = '#' then 'N'
             else 'Y'
           end::varchar as active,
           ct.aline[2] as minute, ct.aline[3] as hour, ct.aline[4] as dayofmonth, ct.aline[5] as month, ct.aline[6] as dayofweek,
           ct.aline[7]::text as command
     from (select "substring"(_crontab_l.pg_line, 16)::bigint as pgjobid, _parse_cron_line(_crontab_l.line) as aline
             from _crontab_l) ct
    where ct.aline[7] is not null;
end;
$function$;

ALTER FUNCTION cron._list() OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._list() FROM public;
COMMENT ON FUNCTION cron._list() IS '';
