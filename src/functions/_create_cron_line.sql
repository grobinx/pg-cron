--DROP FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text);

CREATE OR REPLACE FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text)
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
declare
  l_id varchar;
begin
  l_id = case when apgjobid is not null then '#PG_CRONTAB ID '||apgjobid||e'\n' else '' end;
  -- prepare frequence
  aminute = coalesce(regexp_replace(aminute, '[ \t]*', '', 'g'), '0');
  if aminute like '@%' and ahour is null and adayofmonth is null and amonth is null and adayofweek is null then
    return l_id||case when aactive = 'N' then '#' else '' end||aminute||e' '||acommand;
  else
    if apgjobid is null and ahour is null and adayofmonth is null and amonth is null and adayofweek is null and acommand is not null then
      return acommand;
    else
      ahour = coalesce(regexp_replace(ahour, '[ \t]*', '', 'g'), '*');
      adayofmonth = coalesce(regexp_replace(adayofmonth, '[ \t]*', '', 'g'), '*');
      amonth = coalesce(regexp_replace(amonth, '[ \t]*', '', 'g'), '*');
      adayofweek = coalesce(regexp_replace(adayofweek, '[ \t]*', '', 'g'), '*');
      --
      return l_id||case when aactive = 'N' then '#' else '' end||aminute||e' '||ahour||e' '||adayofmonth||e' '||amonth||e' '||adayofweek||e' '||acommand;
    end if;
  end if;
end;
$function$;

ALTER FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) FROM public;
COMMENT ON FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) IS '';
