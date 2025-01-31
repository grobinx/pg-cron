--DROP FUNCTION cron.change(ajobid integer, acommand text);

CREATE OR REPLACE FUNCTION cron.change(ajobid integer, acommand text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Pozwala zmienić polecenie SQL w istniejącym zadaniu.
 * 
 * @param ajobid Identyfikator zadania
 * @param acommand Nowe polecenie SQL
 * 
 * @summary Zmiana polecenia
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
  acommand = _prepare_command(ajobid, acommand, case when (select autoremove from pg_list where jobid = ajobid) = 'Y' then true else false end, (select role from pg_list where jobid = ajobid));
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active, minute, hour, dayofmonth, month, dayofweek, case when pgjobid = ajobid then acommand else command end),
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

ALTER FUNCTION cron.change(ajobid integer, acommand text) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.change(ajobid integer, acommand text) FROM public;
GRANT EXECUTE ON FUNCTION cron.change(ajobid integer, acommand text) TO cron_role;
COMMENT ON FUNCTION cron.change(ajobid integer, acommand text) IS '';
