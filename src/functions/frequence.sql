--DROP FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying);

CREATE OR REPLACE FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying DEFAULT NULL::character varying, adayofmonth character varying DEFAULT NULL::character varying, amonth character varying DEFAULT NULL::character varying, adayofweek character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Pozwala zmienić częstototliwość wykonywania zadania.
 * 
 * @param ajobid Identyfikator zadania
 * @param aminute Minuta wykonania (0-59)
 * @param ahour Godzina wykonania (0-23)
 * @param adayofmonth Dzień miesiąca wykonania (1-31)
 * @param amonth Miesiąc wykonania (1-12) lub (JAN, FEB, MAR, etc.)
 * @param adayofweek Dzień tygodnia wykonania (0-6) lub (MON, TUE, WED, etc.)
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active,
             case when pgjobid = ajobid then aminute else minute end,
             case when pgjobid = ajobid then ahour else hour end,
             case when pgjobid = ajobid then adayofmonth else dayofmonth end,
             case when pgjobid = ajobid then amonth else month end,
             case when pgjobid = ajobid then adayofweek else dayofweek end,
             command),
           e'\n')||e'\n'
    into l_ct
    from _list();
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return 1;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$function$;

ALTER FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) FROM public;
GRANT EXECUTE ON FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) TO cron_role;
COMMENT ON FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) IS '';
