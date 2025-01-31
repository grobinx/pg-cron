-- DROP TABLE IF EXISTS cron.log;

CREATE TABLE IF NOT EXISTS cron.log
(
    ilog bigserial NOT NULL primary key,
    start timestamp without time zone,
    stop timestamp without time zone,
    minute character,
    hour character,
    dayofmonth character,
    month character,
    dayofweek character,
    command text,
    jobid numeric,
    success boolean DEFAULT true,
    exception text
);

ALTER TABLE IF EXISTS cron.log OWNER to cron;
GRANT SELECT ON TABLE cron.log TO cron_role;

COMMENT ON TABLE cron.log IS 'Tablica logująca zawiera informacje o czasie wykonania, godzinie rozpoczęcia oraz godzinie zakończenia, informacje czy zadanie zakończyło się sukcesem oraz jeśli zadanie zakończyło się wyjątkiem – jego treść.
Rekord do tablicy dodawany jest w chwili rozpoczęcia zadania. Gdy zadanie się zakończy uaktualniana jest tylko informacja o czasie jego zakończenia. 
@summary Tabela z logiem
@package core';

COMMENT ON COLUMN cron.log.ilog IS 'Identyfikator rekordu';
COMMENT ON COLUMN cron.log.start IS 'Data i godzina rozpoczęcia zadania';
COMMENT ON COLUMN cron.log.stop IS 'Data i godzina zakończenia zadania';
COMMENT ON COLUMN cron.log.minute IS 'Wartość kolumny minute z crona';
COMMENT ON COLUMN cron.log.hour IS 'Wartość kolumny hour z crona';
COMMENT ON COLUMN cron.log.dayofmonth IS 'Wartość kolumny dayofmonth z crona';
COMMENT ON COLUMN cron.log.month IS 'Wartość kolumny month z crona';
COMMENT ON COLUMN cron.log.dayofweek IS 'Wartość kolumny dayofweek z crona';
COMMENT ON COLUMN cron.log.command IS 'Wykonywana komenda SQL';
COMMENT ON COLUMN cron.log.jobid IS 'Wartość parametru abrokenflag';
COMMENT ON COLUMN cron.log.success IS 'Czy zadanie zakończyło się sukcesem';
COMMENT ON COLUMN cron.log.exception IS 'Treść wyjątku jeśli nastąpi';

-- DROP INDEX IF EXISTS cron.log_stop_start_i;
CREATE INDEX IF NOT EXISTS log_stop_start_i ON cron.log USING btree (COALESCE(stop, start) ASC NULLS LAST);
