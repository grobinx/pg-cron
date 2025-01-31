--DROP FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying);

CREATE OR REPLACE FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying DEFAULT NULL::character varying, adayofmonth character varying DEFAULT NULL::character varying, amonth character varying DEFAULT NULL::character varying, adayofweek character varying DEFAULT NULL::character varying, ajobid integer DEFAULT NULL::integer, aactive character varying DEFAULT NULL::character varying, aautoremove boolean DEFAULT false, arole character varying DEFAULT NULL::character varying)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Dodaje nowe zadanie do crona.
 * 
 * @param acommand Komenda SQL która zostanie wykonana
 * @param aminute Minuta wykonania (0-59)
 * @param ahour Godzina wykonania (0-23)
 * @param adayofmonth Dzień miesiąca wykonania (1-31)
 * @param amonth Miesiąc wykonania (1-12) lub (JAN, FEB, MAR, etc.)
 * @param adayofweek Dzień tygodnia wykonania (0-6) lub (MON, TUE, WED, etc.)
 * @param ajobid (NULL) Identyfikator zadania, jeśli nowe to null
 * @param aactive (NULL) Przyjmuje wartość „Y” lub „N”. Zadanie dodane jako broken nie zostanie wykonane. Do CRON’a zostanie dodano jako zakomentowane
 * @param aautoremove (FALSE) Czy zadanie jednorazowe – ma być usunięte po wykonaniu
 * @param arole (od 1.0.3) (NULL) Rola w ramach której zadanie ma zostać uruchomione
 * 
 * @return {integer} jobid
 * 
 * @author Andrzej Kałuża
 * @version 1.0.3
 * @since 1.0
 * @public
 * 
 * @todo zmienić active varchar na boolean
 * 
 * @example
 * -- Dodanie zadania do crona. Zadanie będzie się wykonywać co miesiąc 6 dnia miesiąca o godzinie 15:30.
 * select cron.add('perform public.test_function(''some_param'')', '30', '15', '6');
 * 
 * @package core
 */
declare
  l_jobid integer;
  l_ct text;
begin
  -- make sure aactive values is correct
  aactive = coalesce(upper(aactive), 'Y');
  if aactive not in ('Y', 'N') then
    return -1;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  -- select ID if gives 0
  if coalesce(ajobid, 0) != 0 then
    l_jobid := ajobid;
  else
    l_jobid := _r_cron_id_seq()::integer +1;
    if l_jobid is null then
      l_jobid := nextval('job_seq');
    else
      perform _w_cron_id_seq(l_jobid::text);
    end if;
  end if;
  raise debug 'jobid: %', l_jobid;
  --
  -- checking if jobid exists
  if isexists(l_jobid) <> 0 then
    raise 'Cannot add jobid % - it exists', l_jobid;
  end if;
  --
  acommand = _prepare_command(l_jobid, acommand, aautoremove, arole);
  raise debug 'command: %', acommand;
  --
  -- collecting existig cron jobs and new one
  select string_agg(line, e'\n')||e'\n'
    into l_ct
    from (select _create_cron_line(pgjobid, active, minute, hour, dayofmonth, month, dayofweek, command) line
            from _list()
           union all
          select _create_cron_line(l_jobid, aactive, aminute, ahour, adayofmonth, amonth, adayofweek, acommand)) c;
  --
  raise debug 'all command: %', l_ct;
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return l_jobid;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$function$;

ALTER FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) FROM public;
GRANT EXECUTE ON FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) TO cron_role;
COMMENT ON FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) IS '';