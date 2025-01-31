--DROP FUNCTION cron.version();

CREATE OR REPLACE FUNCTION cron.version()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
/**
 * Funkcja zwraca wersję pakietu.
 * 
 * @return {text} wersja pakietu w formacie 'major.minor.release'
 * 
 * @since 1.0.5
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 * 
 * @changelog 1.0.10 obsługa poleceń administracyjnych, które nie są poleceniami harmonogramu CRON, np. MAILTO=adres@domena.pl
 * @changelog 1.0.11 dodanie globalnego locka by dwie lub więcej funkcji nie mogły jednocześnie zmieniać cron-a systemowego
 * @changelog 1.0.12 dodana została możliwość wstawiania do crona zadań z identyfikatorem zadania <code>cron.add('funckja($(jobid), ...)')</code>, <code>$(jobid)</code> zostanie zastąpiony numerem zadania
 * @changelog 1.1.14 zmiana nazewnictwa funkcji, porządki z uprawnieniami
 */
begin
  return '1.1.14';
end;
$function$;

ALTER FUNCTION cron.version() OWNER TO cron;
COMMENT ON FUNCTION cron.version() IS '';
