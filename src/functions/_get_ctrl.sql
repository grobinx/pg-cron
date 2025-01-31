--DROP FUNCTION cron._get_ctrl(aname name, adefaultvalue text);

CREATE OR REPLACE FUNCTION cron._get_ctrl(aname name, adefaultvalue text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return coalesce((select value from ctrl where name = aname), adefaultvalue);
end;
$function$;

ALTER FUNCTION cron._get_ctrl(aname name, adefaultvalue text) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._get_ctrl(aname name, adefaultvalue text) FROM public;
COMMENT ON FUNCTION cron._get_ctrl(aname name, adefaultvalue text) IS '';
