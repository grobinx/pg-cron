--DROP FUNCTION cron._sys_crontab_l();

CREATE OR REPLACE FUNCTION cron._sys_crontab_l()
 RETURNS character varying
 LANGUAGE plperlu
 SECURITY DEFINER
AS $function$    
  use Encode;
  my $output = `crontab -l`;
  chomp($output);
  return Encode::decode('utf-8', $output);
$function$;

ALTER FUNCTION cron._sys_crontab_l() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION cron._sys_crontab_l() FROM public;
COMMENT ON FUNCTION cron._sys_crontab_l() IS '
Core function for get crontab content
@summary Get crontab content
@author Andrzej Kałuża
@private
@package core';
