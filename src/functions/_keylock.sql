--DROP FUNCTION cron._keylock();

CREATE OR REPLACE FUNCTION cron._keylock()
 RETURNS bigint
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
/**
 * Generate global lock key
 * 
 * @return globalny identyfikator blokady
 * @since 1.0.10
 * 
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return ('x'||substr(md5('cron.global.sem'), 1, 16))::bit(64)::bigint;
end;
$function$;

ALTER FUNCTION cron._keylock() OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._keylock() FROM public;
COMMENT ON FUNCTION cron._keylock() IS '';
