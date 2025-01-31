--DROP FUNCTION cron._r_cron_id_seq();

CREATE OR REPLACE FUNCTION cron._r_cron_id_seq()
 RETURNS character varying
 LANGUAGE plperlu
 SECURITY DEFINER
AS $function$
  open my $fh, '<', 'cron_id.seq';
  my $no = <$fh>;
  close $fh;
  return $no;
$function$;

ALTER FUNCTION cron._r_cron_id_seq() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION cron._r_cron_id_seq() FROM PUBLIC;
COMMENT ON FUNCTION cron._r_cron_id_seq() IS 'Get unique id for all PostgreSQL instances
@summary Get unique id
@author Andrzej Kałuża
@private
@package core';
