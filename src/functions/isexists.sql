--DROP FUNCTION cron.isexists(ajobid integer);

CREATE OR REPLACE FUNCTION cron.isexists(ajobid integer)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
begin
  perform * from pg_list where jobid = ajobid;
  return found::integer;
end;
$function$;

ALTER FUNCTION cron.isexists(ajobid integer) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.isexists(ajobid integer) FROM public;
GRANT EXECUTE ON FUNCTION cron.isexists(ajobid integer) TO cron_role;
COMMENT ON FUNCTION cron.isexists(ajobid integer) IS '';
