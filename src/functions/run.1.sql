--DROP FUNCTION cron.run(acommand character varying, arole character varying);

CREATE OR REPLACE FUNCTION cron.run(acommand character varying, arole character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Dodaje nowe zadanie do crona. Wykonane zostanie natychmiast i zostanie usunięte z lity
 * 
 * @param acommand Polecenie SQL która zostanie wykonana
 * @param arole (NULL) Rola w ramach której zadanie ma zostać uruchomione
 * 
 * @author Andrzej Kałuża
 * @version 2.0
 * @since 1.0.8
 * @public
 * 
 * @package core
 * 
 * @changelog 2024-12-05 <Andrzej Kałuża> teraz wykona się na pewno zawsze
 */
begin
  return cron.add(acommand, '*', '*', '*', '*', aautoremove := true, arole := arole);
end;
$function$;

ALTER FUNCTION cron.run(acommand character varying, arole character varying) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.run(acommand character varying, arole character varying) FROM public;
GRANT EXECUTE ON FUNCTION cron.run(acommand character varying, arole character varying) TO cron_role;
COMMENT ON FUNCTION cron.run(acommand character varying, arole character varying) IS '';
