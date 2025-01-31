--DROP FUNCTION cron._start(ajobid bigint);

CREATE OR REPLACE FUNCTION cron._start(ajobid bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
declare
  lilog bigint;
  l_port varchar;
begin
  execute 'set application_name = ''PG_CRONTAB ID '||ajobid||'''';
  --
  if (select pg_is_in_recovery()) then
    raise 'Cannot execute jobs on database in read/only mode!';
  end if;
  --
  if _get_ctrl('password') is null or _get_ctrl('user') is null then
    raise 'Can not find user and/or password in control table!';
  end if;
  --
  l_port = _get_ctrl('port');
  --
  select ilog into lilog
    from dblink(
           'dbname='||current_database()||' password='||_get_ctrl('password')||' user='||_get_ctrl('user')||case when l_port is not null then ' port='||l_port else '' end||'',
           'insert into cron.log (start, stop, minute, hour, dayofmonth, month, dayofweek, command, jobid, success, exception)
            select clock_timestamp(), null, minute, hour, dayofmonth, month, dayofweek, command, jobid, null, null from cron.pg_list where jobid = ' || ajobid ||'
            returning ilog') as s(ilog bigint);
  return lilog;
end;
$function$;

ALTER FUNCTION cron._start(ajobid bigint) OWNER TO cron;
REVOKE EXECUTE ON FUNCTION cron._start(ajobid bigint) FROM public;
COMMENT ON FUNCTION cron._start(ajobid bigint) IS '';
