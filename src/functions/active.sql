--DROP FUNCTION cron.active(ajobid integer, aactive character varying);

CREATE OR REPLACE FUNCTION cron.active(ajobid integer, aactive character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Pozwala aktywować wybrane zadanie.
 * 
 * @summary Aktywacja zadania
 *
 * @param ajobid Identyfikator zadania
 * @param aactive Nowa wartość dla parametru active (Y/N)
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, case when pgjobid = ajobid then aactive else active end, minute, hour, dayofmonth, month, dayofweek, command),
           e'\n')||e'\n'
    into l_ct
    from _list();
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return 1;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$function$;

ALTER FUNCTION cron.active(ajobid integer, aactive character varying) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.active(ajobid integer, aactive character varying) FROM public;
GRANT EXECUTE ON FUNCTION cron.active(ajobid integer, aactive character varying) TO cron_role;
COMMENT ON FUNCTION cron.active(ajobid integer, aactive character varying) IS '';
