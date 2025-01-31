--DROP FUNCTION cron.clear_log();

CREATE OR REPLACE FUNCTION cron.clear_log()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Pozwala wyczyścić log zgodnie z opcją log.interval (domyślnie 1 miesiąc).
 * 
 * Można dodać wywołanie tej funkcji jako codzienne zadanie CRON by log-i nie przyrastały zbytnio.
 * 
 * @summary Czyszczenie log-a
 * 
 * @example
 * -- Poniższy przykład demonstruje jak dodać zadanie z czyszczeniem log-a. Zadanie to będzie wykonywane codziennie o godzinie 0:15.
 * do $$
 * begin
 *   perform add('perform clear_log()', '15', '0');
 * end; $$
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
begin
  delete from log
   where coalesce(stop, start) < now() -_get_ctrl('log.interval', '1 month')::interval;
end;
$function$;

ALTER FUNCTION cron.clear_log() OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.clear_log() FROM public;
GRANT EXECUTE ON FUNCTION cron.clear_log() TO cron_role;
COMMENT ON FUNCTION cron.clear_log() IS '';
