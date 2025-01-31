--DROP FUNCTION cron.run(ajobid integer);

CREATE OR REPLACE FUNCTION cron.run(ajobid integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Pozwala natychmiast wykonać polecenie z zadania
 * 
 * @param ajobid Identyfikator zadania
 * @return rezultat wykonania polecenia
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_command text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  select command into l_command
    from list
   where pgjobid = ajobid;
  --
  return _run(l_command);
end;
$function$;

ALTER FUNCTION cron.run(ajobid integer) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.run(ajobid integer) FROM public;
GRANT EXECUTE ON FUNCTION cron.run(ajobid integer) TO cron_role;
COMMENT ON FUNCTION cron.run(ajobid integer) IS '';
