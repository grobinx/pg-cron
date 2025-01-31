--DROP FUNCTION cron._catch_exception(aerrm text, ailog bigint);

CREATE OR REPLACE FUNCTION cron._catch_exception(aerrm text, ailog bigint)
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
         success = false,
         exception = aerrm
   where ilog = ailog;
end;
$function$;

ALTER FUNCTION cron._catch_exception(aerrm text, ailog bigint) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._catch_exception(aerrm text, ailog bigint) FROM public;
COMMENT ON FUNCTION cron._catch_exception(aerrm text, ailog bigint) IS '';
