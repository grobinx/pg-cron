--DROP FUNCTION cron.remove(ajobid integer);

CREATE OR REPLACE FUNCTION cron.remove(ajobid integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Usuwa zadanie z CRON-a
 * 
 * @param ajobid Identyfikator zadania
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return null;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active, minute, hour, dayofmonth, month, dayofweek, command),
           e'\n')||e'\n'
    into l_ct
    from _list()
   where coalesce(pgjobid, 0) <> ajobid;
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return ajobid;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
END;
$function$;

ALTER FUNCTION cron.remove(ajobid integer) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.remove(ajobid integer) FROM public;
GRANT EXECUTE ON FUNCTION cron.remove(ajobid integer) TO cron_role;
COMMENT ON FUNCTION cron.remove(ajobid integer) IS '';
