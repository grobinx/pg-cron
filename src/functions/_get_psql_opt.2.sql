--DROP FUNCTION cron._get_psql_opt(aopt text, acommand text);

CREATE OR REPLACE FUNCTION cron._get_psql_opt(aopt text, acommand text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return
   (select value
      from (select opt, lead(opt) over () as value
              from (select unnest(string_to_array(substring(command, "position"(command, ' psql ') +6, "position"(command, ' -c "') -"position"(command, ' psql ') -6), ' ')) opt
                      from (select acommand command) t) t) t
     where opt = aopt);
end;
$function$;

ALTER FUNCTION cron._get_psql_opt(aopt text, acommand text) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._get_psql_opt(aopt text, acommand text) FROM public;
COMMENT ON FUNCTION cron._get_psql_opt(aopt text, acommand text) IS '';
