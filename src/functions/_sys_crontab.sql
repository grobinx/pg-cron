--DROP FUNCTION cron._sys_crontab(adata text);

CREATE OR REPLACE FUNCTION cron._sys_crontab(adata text)
 RETURNS void
 LANGUAGE plperlu
 SECURITY DEFINER
AS $function$    
  # no more then 1 milion chars
  if (length($_[0]) < 1000000) {
    open my $fh, '>', '/tmp/pgcrontab';
    print $fh $_[0];
    close $fh;
    `crontab /tmp/pgcrontab`;
  }
$function$;

ALTER FUNCTION cron._sys_crontab(adata text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION cron._sys_crontab(adata text) FROM public;
COMMENT ON FUNCTION cron._sys_crontab(adata text) IS '
Core function to set system crontab content
@summary Set crontab content
@author Andrzej Kałuża
@private
@package core';
