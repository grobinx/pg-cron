--DROP FUNCTION cron._run(acommand text);

CREATE OR REPLACE FUNCTION cron._run(acommand text)
 RETURNS character varying
 LANGUAGE plperlu
 SECURITY DEFINER
AS $function$
  my $cmd = $_[0];
  my $output = `$cmd`;
  chomp($output);
  return $output;
$function$;

ALTER FUNCTION cron._run(acommand text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION cron._run(acommand text) FROM public;
COMMENT ON FUNCTION cron._run(acommand text) IS 'Function for run command on system console
@summary Run console command
@author Andrzej Kałuża
@private
@package core';
