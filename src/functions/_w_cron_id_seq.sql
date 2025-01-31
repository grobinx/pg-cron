--DROP FUNCTION cron._w_cron_id_seq(adata text);

CREATE OR REPLACE FUNCTION cron._w_cron_id_seq(adata text)
 RETURNS void
 LANGUAGE plperlu
 SECURITY DEFINER
AS $function$    
  open my $fh, '>', 'cron_id.seq';
  print $fh $_[0];
  close $fh;
$function$;

ALTER FUNCTION cron._w_cron_id_seq(adata text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION cron._w_cron_id_seq(adata text) FROM public;
COMMENT ON FUNCTION cron._w_cron_id_seq(adata text) IS '
Create/write unique id for all PostgreSQL instances
@summary Set unique id
@author Andrzej Kałuża
@private
@package core';
