--DROP FUNCTION cron._stop(ailog bigint);

CREATE OR REPLACE FUNCTION cron._stop(ailog bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  update log
     set stop = clock_timestamp(),
         success = true
   where ilog = ailog;
end;
$function$;

ALTER FUNCTION cron._stop(ailog bigint) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._stop(ailog bigint) FROM public;
COMMENT ON FUNCTION cron._stop(ailog bigint) IS '';
