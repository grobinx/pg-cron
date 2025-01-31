--DROP FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying);

CREATE OR REPLACE FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean DEFAULT false, arole character varying DEFAULT NULL::character varying)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
/**
 * @since 1.0.0
 * @version 1.1
 * @private
 * @changelog 1.1 dodanie podmiany $(jobid) identyfikatorem zadania
 * 
 * @package core
 */
declare
  l_port varchar;
begin
  -- no null command
  if (acommand is null) then 
    raise 'Command cannot be null';
  end if;
  --
  -- no new line in command!
  if position(chr(10) in acommand) > 0 then
    raise 'Command cannot contain a new line';
  end if;
  acommand = replace(trim(trailing ';' from acommand), '"', '\"');
  acommand = replace(acommand, '$(jobid)', ajobid::text);
  acommand = 'do \$\$ declare lilog bigint; begin select _start('|| ajobid ||') into lilog; set role '||coalesce(arole, session_user)||'; ' || acommand || '; reset role; perform _stop(lilog);';
  if aautoremove then
    acommand := acommand || ' perform remove('|| ajobid ||');';
  end if;
  acommand := acommand || ' exception when others then reset role; perform _catch_exception(SQLERRM, lilog);';
  if aautoremove then
    acommand := acommand || ' perform remove('|| ajobid ||');';
  end if;
  acommand := acommand || ' end \$\$;';
  --
  l_port = _get_ctrl('port');
  -- merge command with psql
  acommand = 'PGPASSWORD='||_get_ctrl('password')||' psql '||current_database()||' -q -U '||_get_ctrl('user')||case when l_port is not null then ' - '||l_port else '' end||' -w -c "' || acommand || '" > /dev/null 2>&1';
  --    
  return acommand;
end;
$function$;

ALTER FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying) FROM public;
COMMENT ON FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying) IS '';
