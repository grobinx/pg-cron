--DROP FUNCTION cron._parse_cron_line(aline text);

CREATE OR REPLACE FUNCTION cron._parse_cron_line(aline text)
 RETURNS character varying[]
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
  l_line text = replace(trim(aline), e'\t', ' ');
  l_full_line text = l_line;
  l_inactive varchar;
  l_minute varchar;
  l_hour varchar;
  l_day_of_month varchar;
  l_month varchar;
  l_day_of_week varchar;
begin
  if coalesce(l_line, '') = '' then
    return null;
  end if;
  --
  if substring(l_line, 1, 1) = '#' then
    l_inactive = '#';
    l_line = trim(substring(l_line, 2));
  end if;
  --
  if coalesce(l_line, '') = '' then
    return null;
  end if;
  --
  l_minute = substring(l_line, 1, "position"(l_line, ' ') -1);
  l_line = trim(substring(l_line, "position"(l_line, ' ') +1));
  --
  if l_minute not like '@%' then
    l_hour = substring(l_line, 1, "position"(l_line, ' ') -1);
    l_line = trim(substring(l_line, "position"(l_line, ' ') +1));
    --
    l_day_of_month = substring(l_line, 1, "position"(l_line, ' ') -1);
    l_line = trim(substring(l_line, "position"(l_line, ' ') +1));
    --
    l_month = substring(l_line, 1, "position"(l_line, ' ') -1);
    l_line = trim(substring(l_line, "position"(l_line, ' ') +1));
    --
    l_day_of_week = substring(l_line, 1, "position"(l_line, ' ') -1);
    l_line = trim(substring(l_line, "position"(l_line, ' ') +1));
  end if;
  --
  return array[l_inactive, l_minute, l_hour, l_day_of_month, l_month, l_day_of_week, l_line]::varchar[];
exception
  when others then
    return array[null, null, null, null, null, null, l_full_line]::varchar[];
end;
$function$;

ALTER FUNCTION cron._parse_cron_line(aline text) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._parse_cron_line(aline text) FROM public;
COMMENT ON FUNCTION cron._parse_cron_line(aline text) IS '';
