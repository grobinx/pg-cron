--
-- PostgreSQL database dump
--

-- Dumped from database version 15.10 (Debian 15.10-0+deb12u1)
-- Dumped by pg_dump version 17.0

-- Started on 2025-01-31 20:37:52

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 13 (class 2615 OID 16524)
-- Name: cron; Type: SCHEMA; Schema: -; Owner: cron
--

CREATE SCHEMA cron;


ALTER SCHEMA cron OWNER TO cron;

--
-- TOC entry 3564 (class 0 OID 0)
-- Dependencies: 13
-- Name: SCHEMA cron; Type: COMMENT; Schema: -; Owner: cron
--

COMMENT ON SCHEMA cron IS '
<section>
<h3>Informacje ogólne</h3>
<p>Na schemacie „cron” znajdują się funkcje do zarządzani mechanizmem cron, który jest odpowiedzialny za uruchamianie ustalonych przez użytkownika funkcji w określonym czasie oraz ich cykliczność. Schemat dodatkowo zawiera log zadań wykonanych oraz jedną tablicę słownikową dla zwracanych wartości przez funkcję cronalter().</p>
<p>Cron jest uniksowym demonem zajmującym się cyklicznym wywoływaniem innych programów. Na potrzeby PostgreSQL został wykorzystany do wywoływania komend SQL oraz do wywołań pojedynczych, nie okresowych oraz wywołań niestandardowych nie obsługiwanych przez sam mechanizm (kwartał, trzecia sobota miesiąca, etc.).</p>
<div class="alert">
<h4>UWAGA</h4>
<p>W przypadku dodawania zadań do CRON-a w bazach danych spiętych w cluster (np. PgPool) należy łączyć się zawsze do bazy danych, która jest masterem – nie przez PgPool.</p>
</div>
Definicja zadania w crontab:
<code><pre># Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) or jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) 
# |  |  |  |  |            or sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed</pre></code>
<p>Gwiazdka (*) oznacza wykonanie wszystkich wartości, np. „*” w kolumnie month oznacza, że zadanie będzie wykonywane każdego miesiąca.</p>
<p>Parametry można oddzielać przecinkami, np. 1,3,6,16. Jeżeli w ten sposób zapiszemy parametr hour, zadania wykona się o godzinach 01:00 w nocy, 03:00, 06:00 oraz o 16:00.</p>
<p>Parametry liczbowe mogą również przyjmować przedziały zapisane jako przedział (z kreską) jak np. 1-5, co również oznacza taki sam zapis jak 1,2,3,4,5.</p>
<p>Istnieje również możliwość określenie zakresu co definiuje się przez znak ukośnika (/) np. 1-15/2 będzie oznaczało to samo co 1,3,5,7,9,11,13,15.</p>
</section>
<section>
<h3>Sekwencja identyfikatora</h3>
<p>Na schemacie CRON znajduje się sekwencja job_seq z której pobierany jest kolejny identyfikator zadania wstawianego do cron-a. Sekwencja ta sprawdza się w przypadku gdy na jednym serwerze znajduje się wyłącznie jedna baza danych z implementacją mechanizmu CRON.</p>
<p>W przypadku gdy baz danych jest więcej należy skorzystać z globalnej numeracji, która jest zaimplementowana w mechanizmie CRON dla PostgreSQL. W celu uruchomienia mechanizmu należy w katalogu domowym PostgreSQL ./N.X/data utworzyć plik cron_id.seq i zapisać w nim pierwszą wartość sekwencji, np. 1. Od tego momentu wszystkie identyfikatory zadań we wszystkich bazach danych będą nadawane z globalnej sekwencji.</p>
Jeśli posiadamy prawa administratora można również wywołać poniższe polecenie:
<code><pre>do $$
begin
  perform cron._w_cron_id_seq(''NNN'');
end; $$</pre></code>
<p>Polecenie to spowoduje zapis wartości NNN do odpowiedniego pliku. NNN to ostatnia wartość sekwencji ze wszystkich maz danych.</p>
</section>
';


--
-- TOC entry 311 (class 1255 OID 16954)
-- Name: _catch_exception(text, bigint); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._catch_exception(aerrm text, ailog bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  update log
     set stop = clock_timestamp(),
         success = false,
         exception = aerrm
   where ilog = ailog;
end;
$$;


ALTER FUNCTION cron._catch_exception(aerrm text, ailog bigint) OWNER TO cron;

--
-- TOC entry 380 (class 1255 OID 16972)
-- Name: _create_cron_line(bigint, character varying, character varying, character varying, character varying, character varying, character varying, text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


ALTER FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) OWNER TO cron;

--
-- TOC entry 320 (class 1255 OID 16991)
-- Name: _get_ctrl(name, text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._get_ctrl(aname name, adefaultvalue text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return coalesce((select value from ctrl where name = aname), adefaultvalue);
end;
$$;


ALTER FUNCTION cron._get_ctrl(aname name, adefaultvalue text) OWNER TO cron;

--
-- TOC entry 321 (class 1255 OID 16989)
-- Name: _get_psql_opt(integer, text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._get_psql_opt(aopt integer, acommand text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return
   (select opt
      from (select row_number() over () rownum, opt
              from (select unnest(string_to_array(substring(command, "position"(command, ' psql ') +6, "position"(command, ' -c "') -"position"(command, ' psql ') -6), ' ')) opt
                      from (select acommand command) t) t) t
     where rownum = aopt);
end;
$$;


ALTER FUNCTION cron._get_psql_opt(aopt integer, acommand text) OWNER TO cron;

--
-- TOC entry 319 (class 1255 OID 16990)
-- Name: _get_psql_opt(text, text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._get_psql_opt(aopt text, acommand text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return
   (select value
      from (select opt, lead(opt) over () as value
              from (select unnest(string_to_array(substring(command, "position"(command, ' psql ') +6, "position"(command, ' -c "') -"position"(command, ' psql ') -6), ' ')) opt
                      from (select acommand command) t) t) t
     where opt = aopt);
end;
$$;


ALTER FUNCTION cron._get_psql_opt(aopt text, acommand text) OWNER TO cron;

--
-- TOC entry 317 (class 1255 OID 16960)
-- Name: _keylock(); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._keylock() RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/**
 * Generate global lock key
 * 
 * @return globalny identyfikator blokady
 * @since 1.0.10
 * 
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return ('x'||substr(md5('cron.global.sem'), 1, 16))::bit(64)::bigint;
end;
$$;


ALTER FUNCTION cron._keylock() OWNER TO cron;

--
-- TOC entry 322 (class 1255 OID 16980)
-- Name: _list(); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._list() RETURNS TABLE(pgjobid bigint, active character varying, minute character varying, hour character varying, dayofmonth character varying, month character varying, dayofweek character varying, command text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  return query
    select ct.pgjobid, 
           case
             when ct.aline[1] = '#' then 'N'
             else 'Y'
           end::varchar as active,
           ct.aline[2] as minute, ct.aline[3] as hour, ct.aline[4] as dayofmonth, ct.aline[5] as month, ct.aline[6] as dayofweek,
           ct.aline[7]::text as command
     from (select "substring"(_crontab_l.pg_line, 16)::bigint as pgjobid, _parse_cron_line(_crontab_l.line) as aline
             from _crontab_l) ct
    where ct.aline[7] is not null;
end;
$$;


ALTER FUNCTION cron._list() OWNER TO cron;

--
-- TOC entry 391 (class 1255 OID 16979)
-- Name: _parse_cron_line(text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._parse_cron_line(aline text) RETURNS character varying[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


ALTER FUNCTION cron._parse_cron_line(aline text) OWNER TO cron;

--
-- TOC entry 390 (class 1255 OID 16956)
-- Name: _prepare_command(bigint, text, boolean, character varying); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean DEFAULT false, arole character varying DEFAULT NULL::character varying) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
/**
 * @since 1.0.0
 * @version 1.1
 * @private
 * @changelog 1.1 dodanie podmiany $(jobid) identyfikatorem zadania
 * 
 * @package core
 */
declare
  l_port varchar;
begin
  -- no null command
  if (acommand is null) then 
    raise 'Command cannot be null';
  end if;
  --
  -- no new line in command!
  if position(chr(10) in acommand) > 0 then
    raise 'Command cannot contain a new line';
  end if;
  acommand = replace(trim(trailing ';' from acommand), '"', '\"');
  acommand = replace(acommand, '$(jobid)', ajobid::text);
  acommand = 'do \$\$ declare lilog bigint; begin select _start('|| ajobid ||') into lilog; set role '||coalesce(arole, session_user)||'; ' || acommand || '; reset role; perform _stop(lilog);';
  if aautoremove then
    acommand := acommand || ' perform remove('|| ajobid ||');';
  end if;
  acommand := acommand || ' exception when others then reset role; perform _catch_exception(SQLERRM, lilog);';
  if aautoremove then
    acommand := acommand || ' perform remove('|| ajobid ||');';
  end if;
  acommand := acommand || ' end \$\$;';
  --
  l_port = _get_ctrl('port');
  -- merge command with psql
  acommand = 'PGPASSWORD='||_get_ctrl('password')||' psql '||current_database()||' -q -U '||_get_ctrl('user')||case when l_port is not null then ' - '||l_port else '' end||' -w -c "' || acommand || '" > /dev/null 2>&1';
  --    
  return acommand;
end;
$_$;


ALTER FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying) OWNER TO cron;

--
-- TOC entry 284 (class 1255 OID 16526)
-- Name: _r_cron_id_seq(); Type: FUNCTION; Schema: cron; Owner: postgres
--

CREATE FUNCTION cron._r_cron_id_seq() RETURNS character varying
    LANGUAGE plperlu SECURITY DEFINER
    AS $_$
  open my $fh, '<', 'cron_id.seq';
  my $no = <$fh>;
  close $fh;
  return $no;
$_$;


ALTER FUNCTION cron._r_cron_id_seq() OWNER TO postgres;

--
-- TOC entry 3575 (class 0 OID 0)
-- Dependencies: 284
-- Name: FUNCTION _r_cron_id_seq(); Type: COMMENT; Schema: cron; Owner: postgres
--

COMMENT ON FUNCTION cron._r_cron_id_seq() IS 'Get unique id for all PostgreSQL instances
@summary Get unique id
@author Andrzej Kałuża
@private
@package core';


--
-- TOC entry 288 (class 1255 OID 16527)
-- Name: _run(text); Type: FUNCTION; Schema: cron; Owner: postgres
--

CREATE FUNCTION cron._run(acommand text) RETURNS character varying
    LANGUAGE plperlu SECURITY DEFINER
    AS $_X$
  my $cmd = $_[0];
  my $output = `$cmd`;
  chomp($output);
  return $output;
$_X$;


ALTER FUNCTION cron._run(acommand text) OWNER TO postgres;

--
-- TOC entry 3577 (class 0 OID 0)
-- Dependencies: 288
-- Name: FUNCTION _run(acommand text); Type: COMMENT; Schema: cron; Owner: postgres
--

COMMENT ON FUNCTION cron._run(acommand text) IS 'Function for run command on system console
@summary Run console command
@author Andrzej Kałuża
@private
@package core';


--
-- TOC entry 414 (class 1255 OID 16977)
-- Name: _start(bigint); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._start(ajobid bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION cron._start(ajobid bigint) OWNER TO cron;

--
-- TOC entry 318 (class 1255 OID 16978)
-- Name: _stop(bigint); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron._stop(ailog bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * @author Andrzej Kałuża
 * @private
 * 
 * @package core
 */
begin
  update log
     set stop = clock_timestamp(),
         success = true
   where ilog = ailog;
end;
$$;


ALTER FUNCTION cron._stop(ailog bigint) OWNER TO cron;

--
-- TOC entry 285 (class 1255 OID 16528)
-- Name: _sys_crontab(text); Type: FUNCTION; Schema: cron; Owner: postgres
--

CREATE FUNCTION cron._sys_crontab(adata text) RETURNS void
    LANGUAGE plperlu SECURITY DEFINER
    AS $_X$    
  # no more then 1 milion chars
  if (length($_[0]) < 1000000) {
    open my $fh, '>', '/tmp/pgcrontab';
    print $fh $_[0];
    close $fh;
    `crontab /tmp/pgcrontab`;
  }
$_X$;


ALTER FUNCTION cron._sys_crontab(adata text) OWNER TO postgres;

--
-- TOC entry 3581 (class 0 OID 0)
-- Dependencies: 285
-- Name: FUNCTION _sys_crontab(adata text); Type: COMMENT; Schema: cron; Owner: postgres
--

COMMENT ON FUNCTION cron._sys_crontab(adata text) IS '
Core function to set system crontab content
@summary Set crontab content
@author Andrzej Kałuża
@private
@package core';


--
-- TOC entry 286 (class 1255 OID 16529)
-- Name: _sys_crontab_l(); Type: FUNCTION; Schema: cron; Owner: postgres
--

CREATE FUNCTION cron._sys_crontab_l() RETURNS character varying
    LANGUAGE plperlu SECURITY DEFINER
    AS $_$    
  use Encode;
  my $output = `crontab -l`;
  chomp($output);
  return Encode::decode('utf-8', $output);
$_$;


ALTER FUNCTION cron._sys_crontab_l() OWNER TO postgres;

--
-- TOC entry 3583 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION _sys_crontab_l(); Type: COMMENT; Schema: cron; Owner: postgres
--

COMMENT ON FUNCTION cron._sys_crontab_l() IS '
Core function for get crontab content
@summary Get crontab content
@author Andrzej Kałuża
@private
@package core';


--
-- TOC entry 287 (class 1255 OID 16530)
-- Name: _w_cron_id_seq(text); Type: FUNCTION; Schema: cron; Owner: postgres
--

CREATE FUNCTION cron._w_cron_id_seq(adata text) RETURNS void
    LANGUAGE plperlu SECURITY DEFINER
    AS $_X$    
  open my $fh, '>', 'cron_id.seq';
  print $fh $_[0];
  close $fh;
$_X$;


ALTER FUNCTION cron._w_cron_id_seq(adata text) OWNER TO postgres;

--
-- TOC entry 3585 (class 0 OID 0)
-- Dependencies: 287
-- Name: FUNCTION _w_cron_id_seq(adata text); Type: COMMENT; Schema: cron; Owner: postgres
--

COMMENT ON FUNCTION cron._w_cron_id_seq(adata text) IS '
Create/write unique id for all PostgreSQL instances
@summary Set unique id
@author Andrzej Kałuża
@private
@package core';


--
-- TOC entry 415 (class 1255 OID 16971)
-- Name: active(integer, character varying); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.active(ajobid integer, aactive character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Pozwala aktywować wybrane zadanie.
 * 
 * @summary Aktywacja zadania
 *
 * @param ajobid Identyfikator zadania
 * @param aactive Nowa wartość dla parametru active (Y/N)
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, case when pgjobid = ajobid then aactive else active end, minute, hour, dayofmonth, month, dayofweek, command),
           e'\n')||e'\n'
    into l_ct
    from _list();
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return 1;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$$;


ALTER FUNCTION cron.active(ajobid integer, aactive character varying) OWNER TO cron;

--
-- TOC entry 385 (class 1255 OID 27456)
-- Name: add(character varying, character varying, character varying, character varying, character varying, character varying, integer, character varying, boolean, character varying); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying DEFAULT NULL::character varying, adayofmonth character varying DEFAULT NULL::character varying, amonth character varying DEFAULT NULL::character varying, adayofweek character varying DEFAULT NULL::character varying, ajobid integer DEFAULT NULL::integer, aactive character varying DEFAULT NULL::character varying, aautoremove boolean DEFAULT false, arole character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Dodaje nowe zadanie do crona.
 * 
 * @param acommand Komenda SQL która zostanie wykonana
 * @param aminute Minuta wykonania (0-59)
 * @param ahour Godzina wykonania (0-23)
 * @param adayofmonth Dzień miesiąca wykonania (1-31)
 * @param amonth Miesiąc wykonania (1-12) lub (JAN, FEB, MAR, etc.)
 * @param adayofweek Dzień tygodnia wykonania (0-6) lub (MON, TUE, WED, etc.)
 * @param ajobid (NULL) Identyfikator zadania, jeśli nowe to null
 * @param aactive (NULL) Przyjmuje wartość „Y” lub „N”. Zadanie dodane jako broken nie zostanie wykonane. Do CRON’a zostanie dodano jako zakomentowane
 * @param aautoremove (FALSE) Czy zadanie jednorazowe – ma być usunięte po wykonaniu
 * @param arole (od 1.0.3) (NULL) Rola w ramach której zadanie ma zostać uruchomione
 * 
 * @return {integer} jobid
 * 
 * @author Andrzej Kałuża
 * @version 1.0.3
 * @since 1.0
 * @public
 * 
 * @todo zmienić active varchar na boolean
 * 
 * @example
 * -- Dodanie zadania do crona. Zadanie będzie się wykonywać co miesiąc 6 dnia miesiąca o godzinie 15:30.
 * select cron.add('perform public.test_function(''some_param'')', '30', '15', '6');
 * 
 * @package core
 */
declare
  l_jobid integer;
  l_ct text;
begin
  -- make sure aactive values is correct
  aactive = coalesce(upper(aactive), 'Y');
  if aactive not in ('Y', 'N') then
    return -1;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  -- select ID if gives 0
  if coalesce(ajobid, 0) != 0 then
    l_jobid := ajobid;
  else
    l_jobid := _r_cron_id_seq()::integer +1;
    if l_jobid is null then
      l_jobid := nextval('job_seq');
    else
      perform _w_cron_id_seq(l_jobid::text);
    end if;
  end if;
  raise debug 'jobid: %', l_jobid;
  --
  -- checking if jobid exists
  if isexists(l_jobid) <> 0 then
    raise 'Cannot add jobid % - it exists', l_jobid;
  end if;
  --
  acommand = _prepare_command(l_jobid, acommand, aautoremove, arole);
  raise debug 'command: %', acommand;
  --
  -- collecting existig cron jobs and new one
  select string_agg(line, e'\n')||e'\n'
    into l_ct
    from (select _create_cron_line(pgjobid, active, minute, hour, dayofmonth, month, dayofweek, command) line
            from _list()
           union all
          select _create_cron_line(l_jobid, aactive, aminute, ahour, adayofmonth, amonth, adayofweek, acommand)) c;
  --
  raise debug 'all command: %', l_ct;
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return l_jobid;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$$;


ALTER FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) OWNER TO cron;

--
-- TOC entry 393 (class 1255 OID 16970)
-- Name: change(integer, text); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.change(ajobid integer, acommand text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Pozwala zmienić polecenie SQL w istniejącym zadaniu.
 * 
 * @param ajobid Identyfikator zadania
 * @param acommand Nowe polecenie SQL
 * 
 * @summary Zmiana polecenia
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  acommand = _prepare_command(ajobid, acommand, case when (select autoremove from pg_list where jobid = ajobid) = 'Y' then true else false end, (select role from pg_list where jobid = ajobid));
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active, minute, hour, dayofmonth, month, dayofweek, case when pgjobid = ajobid then acommand else command end),
           e'\n')||e'\n'
    into l_ct
    from _list();
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return 1;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$$;


ALTER FUNCTION cron.change(ajobid integer, acommand text) OWNER TO cron;

--
-- TOC entry 295 (class 1255 OID 16540)
-- Name: clear_log(); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.clear_log() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
/**
 * Pozwala wyczyścić log zgodnie z opcją log.interval (domyślnie 1 miesiąc).
 * 
 * Można dodać wywołanie tej funkcji jako codzienne zadanie CRON by log-i nie przyrastały zbytnio.
 * 
 * @summary Czyszczenie log-a
 * 
 * @example
 * -- Poniższy przykład demonstruje jak dodać zadanie z czyszczeniem log-a. Zadanie to będzie wykonywane codziennie o godzinie 0:15.
 * do $$
 * begin
 *   perform add('perform clear_log()', '15', '0');
 * end; $$
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
begin
  delete from log
   where coalesce(stop, start) < now() -_get_ctrl('log.interval', '1 month')::interval;
end;
$_$;


ALTER FUNCTION cron.clear_log() OWNER TO cron;

--
-- TOC entry 379 (class 1255 OID 16976)
-- Name: frequence(integer, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying DEFAULT NULL::character varying, adayofmonth character varying DEFAULT NULL::character varying, amonth character varying DEFAULT NULL::character varying, adayofweek character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Pozwala zmienić częstototliwość wykonywania zadania.
 * 
 * @param ajobid Identyfikator zadania
 * @param aminute Minuta wykonania (0-59)
 * @param ahour Godzina wykonania (0-23)
 * @param adayofmonth Dzień miesiąca wykonania (1-31)
 * @param amonth Miesiąc wykonania (1-12) lub (JAN, FEB, MAR, etc.)
 * @param adayofweek Dzień tygodnia wykonania (0-6) lub (MON, TUE, WED, etc.)
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active,
             case when pgjobid = ajobid then aminute else minute end,
             case when pgjobid = ajobid then ahour else hour end,
             case when pgjobid = ajobid then adayofmonth else dayofmonth end,
             case when pgjobid = ajobid then amonth else month end,
             case when pgjobid = ajobid then adayofweek else dayofweek end,
             command),
           e'\n')||e'\n'
    into l_ct
    from _list();
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return 1;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
end;
$$;


ALTER FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) OWNER TO cron;

--
-- TOC entry 296 (class 1255 OID 16546)
-- Name: isexists(integer); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.isexists(ajobid integer) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
begin
  perform * from pg_list where jobid = ajobid;
  return found::integer;
end;
$$;


ALTER FUNCTION cron.isexists(ajobid integer) OWNER TO cron;

--
-- TOC entry 297 (class 1255 OID 16550)
-- Name: pg_list(); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.pg_list() RETURNS TABLE(jobid bigint, database character varying, role character varying, minute character varying, hour character varying, dayofmonth character varying, month character varying, dayofweek character varying, last_start timestamp without time zone, this_start timestamp without time zone, total_time bigint, failures bigint, times bigint, command text, active character varying, autoremove character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$
begin
  return query
    select c.jobid, c.database, c.role, c.minute, c.hour, c.dayofmonth, c.month, c.dayofweek, c.last_start, c.this_start, c.total_time, c.failures, c.times, c.command, c.active, c.autoremove
      from (select cl.pgjobid as jobid, coalesce(_get_psql_opt('-d', cl.command), _get_psql_opt(1, cl.command))::varchar as database, 
                   substring(cl.command from 'set role "?([#$\w]+)"?;')::varchar as role, 
                   cl.minute, cl.hour, cl.dayofmonth, cl.month, cl.dayofweek, l.last_start,
                   (select l.start
                      from (select log.start, log.stop
                              from log
                             where log.jobid = cl.pgjobid
                             order by log.start desc
                             limit 1) l
                     where l.stop is null) as this_start,
                   l.total_time, l.failures, l.times,
                   substring(cl.command from 'set role "?[#$\w]+"?; (.*); reset role;') as command,
                   cl.active, 
                   case
                       when "position"(cl.command, ('perform remove(' || cl.pgjobid::text) || ');') > 0 then 'Y'
                       else 'N'
                   end::varchar as autoremove
              from _list() cl
         left join ( select log.jobid, count(
                           case
                               when not log.success then 1
                               else null::integer
                           end) as failures, max(
                           case
                               when log.stop is not null then log.start
                               else null::timestamp without time zone
                           end) as last_start, round(date_part('epoch', sum(log.stop - log.start))::numeric, 0)::bigint as total_time, count(0) as times
                      from log
                     group by log.jobid) l on cl.pgjobid::numeric = l.jobid
        where cl.pgjobid is not null) c
     where c.database = current_database() or
           (select pg_roles.rolsuper
              from pg_roles
             where pg_roles.rolname = session_user);
end;
$_$;


ALTER FUNCTION cron.pg_list() OWNER TO cron;

--
-- TOC entry 323 (class 1255 OID 16552)
-- Name: remove(integer); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.remove(ajobid integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Usuwa zadanie z CRON-a
 * 
 * @param ajobid Identyfikator zadania
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_ct text;
begin
  if isexists(ajobid) = 0 then
    return null;
  end if;
  --
  perform pg_advisory_lock(_keylock());
  --
  select string_agg(
           _create_cron_line(
             pgjobid, active, minute, hour, dayofmonth, month, dayofweek, command),
           e'\n')||e'\n'
    into l_ct
    from _list()
   where coalesce(pgjobid, 0) <> ajobid;
  --
  perform _sys_crontab(l_ct);
  --
  perform pg_advisory_unlock(_keylock());
  return ajobid;
exception
  when others then
    perform pg_advisory_unlock(_keylock());
    raise;
END;
$$;


ALTER FUNCTION cron.remove(ajobid integer) OWNER TO cron;

--
-- TOC entry 298 (class 1255 OID 16553)
-- Name: run(integer); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.run(ajobid integer) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Pozwala natychmiast wykonać polecenie z zadania
 * 
 * @param ajobid Identyfikator zadania
 * @return rezultat wykonania polecenia
 * 
 * @author Andrzej Kałuża
 * @public
 * 
 * @package core
 */
declare
  l_command text;
begin
  if isexists(ajobid) = 0 then
    return 0;
  end if;
  --
  select command into l_command
    from list
   where pgjobid = ajobid;
  --
  return _run(l_command);
end;
$$;


ALTER FUNCTION cron.run(ajobid integer) OWNER TO cron;

--
-- TOC entry 290 (class 1255 OID 16646)
-- Name: run(character varying, character varying); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.run(acommand character varying, arole character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/**
 * Dodaje nowe zadanie do crona. Wykonane zostanie natychmiast i zostanie usunięte z lity
 * 
 * @param acommand Polecenie SQL która zostanie wykonana
 * @param arole (NULL) Rola w ramach której zadanie ma zostać uruchomione
 * 
 * @author Andrzej Kałuża
 * @version 2.0
 * @since 1.0.8
 * @public
 * 
 * @package core
 * 
 * @changelog 2024-12-05 <Andrzej Kałuża> teraz wykona się na pewno zawsze
 */
begin
  return cron.add(acommand, '*', '*', '*', '*', aautoremove := true, arole := arole);
end;
$$;


ALTER FUNCTION cron.run(acommand character varying, arole character varying) OWNER TO cron;

--
-- TOC entry 289 (class 1255 OID 16556)
-- Name: version(); Type: FUNCTION; Schema: cron; Owner: cron
--

CREATE FUNCTION cron.version() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
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
$_$;


ALTER FUNCTION cron.version() OWNER TO cron;

--
-- TOC entry 223 (class 1259 OID 16557)
-- Name: _crontab_l; Type: VIEW; Schema: cron; Owner: cron
--

CREATE VIEW cron._crontab_l AS
 SELECT l.pg_line,
    l.line
   FROM ( SELECT c.pg_line,
                CASE
                    WHEN (c.pg_line IS NOT NULL) THEN c.pg_cmd_line
                    ELSE c.line
                END AS line
           FROM ( SELECT
                        CASE
                            WHEN (substr(line.line, 1, 11) = '#PG_CRONTAB'::text) THEN line.line
                            ELSE NULL::text
                        END AS pg_line,
                        CASE
                            WHEN (substr(line.line, 1, 11) = '#PG_CRONTAB'::text) THEN lead(line.line) OVER ()
                            ELSE NULL::text
                        END AS pg_cmd_line,
                        CASE
                            WHEN (btrim(
                            CASE
                                WHEN (((substr(lag(line.line) OVER (), 1, 11) <> '#PG_CRONTAB'::text) AND (substr(line.line, 1, 11) <> '#PG_CRONTAB'::text)) OR (lag(line.line) OVER () IS NULL)) THEN line.line
                                ELSE NULL::text
                            END) <> ''::text) THEN line.line
                            ELSE NULL::text
                        END AS line
                   FROM unnest(string_to_array((cron._sys_crontab_l())::text, '
'::text)) line(line)) c) l
  WHERE (l.line IS NOT NULL);


ALTER VIEW cron._crontab_l OWNER TO cron;

--
-- TOC entry 3597 (class 0 OID 0)
-- Dependencies: 223
-- Name: VIEW _crontab_l; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON VIEW cron._crontab_l IS 'cron native line with id if exists
@package core';


--
-- TOC entry 224 (class 1259 OID 16562)
-- Name: ctrl; Type: TABLE; Schema: cron; Owner: cron
--

CREATE TABLE cron.ctrl (
    name name NOT NULL,
    value text
);


ALTER TABLE cron.ctrl OWNER TO cron;

--
-- TOC entry 3598 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE ctrl; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON TABLE cron.ctrl IS 'Tablica ctrl zawiera wartości parametrów konfiguracji mechanizmu CRON po stronie bazy danych.
Takie jak użytkownik i hasło. Tabela ctrl jest dostępna tylko dla użytkownika CRON.
@summary Parametry konfiguracji
@package core';


--
-- TOC entry 3599 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN ctrl.name; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.ctrl.name IS 'Nazwa parametru';


--
-- TOC entry 3600 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN ctrl.value; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.ctrl.value IS 'Wartość parametru';


--
-- TOC entry 225 (class 1259 OID 16567)
-- Name: job_seq; Type: SEQUENCE; Schema: cron; Owner: cron
--

CREATE SEQUENCE cron.job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cron.job_seq OWNER TO cron;

--
-- TOC entry 226 (class 1259 OID 16572)
-- Name: log; Type: TABLE; Schema: cron; Owner: cron
--

CREATE TABLE cron.log (
    ilog bigint NOT NULL,
    start timestamp without time zone,
    stop timestamp without time zone,
    minute character varying,
    hour character varying,
    dayofmonth character varying,
    month character varying,
    dayofweek character varying,
    command text,
    jobid numeric,
    success boolean DEFAULT true,
    exception text
);


ALTER TABLE cron.log OWNER TO cron;

--
-- TOC entry 3602 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE log; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON TABLE cron.log IS 'Tablica logująca zawiera informacje o czasie wykonania, godzinie rozpoczęcia oraz godzinie zakończenia, informacje czy zadanie zakończyło się sukcesem oraz jeśli zadanie zakończyło się wyjątkiem – jego treść.
Rekord do tablicy dodawany jest w chwili rozpoczęcia zadania. Gdy zadanie się zakończy uaktualniana jest tylko informacja o czasie jego zakończenia. 
@summary Tabela z logiem
@package core';


--
-- TOC entry 3603 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.ilog; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.ilog IS 'Identyfikator rekordu';


--
-- TOC entry 3604 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.start; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.start IS 'Data i godzina rozpoczęcia zadania';


--
-- TOC entry 3605 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.stop; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.stop IS 'Data i godzina zakończenia zadania';


--
-- TOC entry 3606 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.minute; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.minute IS 'Wartość kolumny minute z crona';


--
-- TOC entry 3607 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.hour; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.hour IS 'Wartość kolumny hour z crona';


--
-- TOC entry 3608 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.dayofmonth; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.dayofmonth IS 'Wartość kolumny dayofmonth z crona';


--
-- TOC entry 3609 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.month; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.month IS 'Wartość kolumny month z crona';


--
-- TOC entry 3610 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.dayofweek; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.dayofweek IS 'Wartość kolumny dayofweek z crona';


--
-- TOC entry 3611 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.command; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.command IS 'Wykonywana komenda SQL';


--
-- TOC entry 3612 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.jobid; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.jobid IS 'Wartość parametru abrokenflag';


--
-- TOC entry 3613 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.success; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.success IS 'Czy zadanie zakończyło się sukcesem';


--
-- TOC entry 3614 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN log.exception; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.log.exception IS 'Treść wyjątku jeśli nastąpi';


--
-- TOC entry 227 (class 1259 OID 16578)
-- Name: log_ilog_seq; Type: SEQUENCE; Schema: cron; Owner: cron
--

CREATE SEQUENCE cron.log_ilog_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cron.log_ilog_seq OWNER TO cron;

--
-- TOC entry 3616 (class 0 OID 0)
-- Dependencies: 227
-- Name: log_ilog_seq; Type: SEQUENCE OWNED BY; Schema: cron; Owner: cron
--

ALTER SEQUENCE cron.log_ilog_seq OWNED BY cron.log.ilog;


--
-- TOC entry 231 (class 1259 OID 27675)
-- Name: pg_list; Type: VIEW; Schema: cron; Owner: cron
--

CREATE VIEW cron.pg_list AS
 SELECT pg_list.jobid,
    pg_list.database,
    pg_list.role,
    pg_list.minute,
    pg_list.hour,
    pg_list.dayofmonth,
    pg_list.month,
    pg_list.dayofweek,
    pg_list.last_start,
    pg_list.this_start,
    pg_list.total_time,
    pg_list.failures,
    pg_list.times,
    pg_list.command,
    pg_list.active,
    pg_list.autoremove
   FROM cron.pg_list() pg_list(jobid, database, role, minute, hour, dayofmonth, month, dayofweek, last_start, this_start, total_time, failures, times, command, active, autoremove);


ALTER VIEW cron.pg_list OWNER TO cron;

--
-- TOC entry 3618 (class 0 OID 0)
-- Dependencies: 231
-- Name: VIEW pg_list; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON VIEW cron.pg_list IS 'Lista aktualnych zadań CRON dla aktualnej bazy danych.
Superuser widzi zadania z wszystkich baz danych.
@summary Lista aktualnych zadań
@package core';


--
-- TOC entry 3619 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.jobid; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.jobid IS 'Id zadania z sekwencji lokalnej lub globalnej.';


--
-- TOC entry 3620 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.database; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.database IS 'Baza danych dla której utworzono zadanie.';


--
-- TOC entry 3621 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.role; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.role IS 'Rola/Użytkownik w ramach której zadanie będzie wykonane.';


--
-- TOC entry 3622 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.minute; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.minute IS 'Minuta w której zadanie będzie wykonane.';


--
-- TOC entry 3623 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.hour; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.hour IS 'Godzina w której zadanie będzie wykonane.';


--
-- TOC entry 3624 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.dayofmonth; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.dayofmonth IS 'Dzień miesiąca w którym zadanie zostanie wykonane.';


--
-- TOC entry 3625 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.month; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.month IS 'Miesiąc wykonania zadania.';


--
-- TOC entry 3626 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.dayofweek; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.dayofweek IS 'Dzień tygodnia w którym zadanie będzie wykonane.';


--
-- TOC entry 3627 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.last_start; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.last_start IS 'Ostatnia data i godzina wykonania zadania (z tabeli log)';


--
-- TOC entry 3628 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.this_start; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.this_start IS 'Data i godzina w której rozpoczęto wykonanie tego zadania (z tabeli log)';


--
-- TOC entry 3629 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.total_time; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.total_time IS 'Całkowity czas wykonania zadania (z tabeli log)';


--
-- TOC entry 3630 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.failures; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.failures IS 'Informacja o ilości wykonań zadania, które zakończyły sie błędem (z tabeli log).';


--
-- TOC entry 3631 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.times; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.times IS 'Ilość wykonań zadania (z tabeli log)';


--
-- TOC entry 3632 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.command; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.command IS 'Polecenie PostgreSQL, które zostanie wykonane.';


--
-- TOC entry 3633 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.active; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.active IS 'Czy zadanie jest aktywne.';


--
-- TOC entry 3634 (class 0 OID 0)
-- Dependencies: 231
-- Name: COLUMN pg_list.autoremove; Type: COMMENT; Schema: cron; Owner: cron
--

COMMENT ON COLUMN cron.pg_list.autoremove IS 'Czy zadanie jest jednorazowe, zostanie automatycznie usunięte po wykonaniu.';


--
-- TOC entry 3406 (class 2604 OID 16583)
-- Name: log ilog; Type: DEFAULT; Schema: cron; Owner: cron
--

ALTER TABLE ONLY cron.log ALTER COLUMN ilog SET DEFAULT nextval('cron.log_ilog_seq'::regclass);


--
-- TOC entry 3557 (class 0 OID 16562)
-- Dependencies: 224
-- Data for Name: ctrl; Type: TABLE DATA; Schema: cron; Owner: cron
--

COPY cron.ctrl (name, value) FROM stdin;
user	cron
password	cron
\.


--
-- TOC entry 3636 (class 0 OID 0)
-- Dependencies: 225
-- Name: job_seq; Type: SEQUENCE SET; Schema: cron; Owner: cron
--

SELECT pg_catalog.setval('cron.job_seq', 44, true);


--
-- TOC entry 3409 (class 2606 OID 16585)
-- Name: ctrl ctrl_pkey; Type: CONSTRAINT; Schema: cron; Owner: cron
--

ALTER TABLE ONLY cron.ctrl
    ADD CONSTRAINT ctrl_pkey PRIMARY KEY (name);


--
-- TOC entry 3411 (class 2606 OID 16587)
-- Name: log log_pkey; Type: CONSTRAINT; Schema: cron; Owner: cron
--

ALTER TABLE ONLY cron.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (ilog);


--
-- TOC entry 3412 (class 1259 OID 16588)
-- Name: log_stop_start_i; Type: INDEX; Schema: cron; Owner: cron
--

CREATE INDEX log_stop_start_i ON cron.log USING btree (COALESCE(stop, start));


--
-- TOC entry 3565 (class 0 OID 0)
-- Dependencies: 13
-- Name: SCHEMA cron; Type: ACL; Schema: -; Owner: cron
--

GRANT USAGE ON SCHEMA cron TO cron_role;
GRANT ALL ON SCHEMA cron TO postgres;
GRANT USAGE ON SCHEMA cron TO gendoc_role;


--
-- TOC entry 3566 (class 0 OID 0)
-- Dependencies: 311
-- Name: FUNCTION _catch_exception(aerrm text, ailog bigint); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._catch_exception(aerrm text, ailog bigint) FROM PUBLIC;


--
-- TOC entry 3567 (class 0 OID 0)
-- Dependencies: 380
-- Name: FUNCTION _create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._create_cron_line(apgjobid bigint, aactive character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, acommand text) FROM PUBLIC;


--
-- TOC entry 3568 (class 0 OID 0)
-- Dependencies: 320
-- Name: FUNCTION _get_ctrl(aname name, adefaultvalue text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._get_ctrl(aname name, adefaultvalue text) FROM PUBLIC;


--
-- TOC entry 3569 (class 0 OID 0)
-- Dependencies: 321
-- Name: FUNCTION _get_psql_opt(aopt integer, acommand text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._get_psql_opt(aopt integer, acommand text) FROM PUBLIC;


--
-- TOC entry 3570 (class 0 OID 0)
-- Dependencies: 319
-- Name: FUNCTION _get_psql_opt(aopt text, acommand text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._get_psql_opt(aopt text, acommand text) FROM PUBLIC;


--
-- TOC entry 3571 (class 0 OID 0)
-- Dependencies: 317
-- Name: FUNCTION _keylock(); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._keylock() FROM PUBLIC;


--
-- TOC entry 3572 (class 0 OID 0)
-- Dependencies: 322
-- Name: FUNCTION _list(); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._list() FROM PUBLIC;


--
-- TOC entry 3573 (class 0 OID 0)
-- Dependencies: 391
-- Name: FUNCTION _parse_cron_line(aline text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._parse_cron_line(aline text) FROM PUBLIC;


--
-- TOC entry 3574 (class 0 OID 0)
-- Dependencies: 390
-- Name: FUNCTION _prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._prepare_command(ajobid bigint, acommand text, aautoremove boolean, arole character varying) FROM PUBLIC;


--
-- TOC entry 3576 (class 0 OID 0)
-- Dependencies: 284
-- Name: FUNCTION _r_cron_id_seq(); Type: ACL; Schema: cron; Owner: postgres
--

REVOKE ALL ON FUNCTION cron._r_cron_id_seq() FROM PUBLIC;
REVOKE ALL ON FUNCTION cron._r_cron_id_seq() FROM postgres;
GRANT ALL ON FUNCTION cron._r_cron_id_seq() TO cron;


--
-- TOC entry 3578 (class 0 OID 0)
-- Dependencies: 288
-- Name: FUNCTION _run(acommand text); Type: ACL; Schema: cron; Owner: postgres
--

REVOKE ALL ON FUNCTION cron._run(acommand text) FROM PUBLIC;
GRANT ALL ON FUNCTION cron._run(acommand text) TO cron;


--
-- TOC entry 3579 (class 0 OID 0)
-- Dependencies: 414
-- Name: FUNCTION _start(ajobid bigint); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._start(ajobid bigint) FROM PUBLIC;


--
-- TOC entry 3580 (class 0 OID 0)
-- Dependencies: 318
-- Name: FUNCTION _stop(ailog bigint); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron._stop(ailog bigint) FROM PUBLIC;


--
-- TOC entry 3582 (class 0 OID 0)
-- Dependencies: 285
-- Name: FUNCTION _sys_crontab(adata text); Type: ACL; Schema: cron; Owner: postgres
--

REVOKE ALL ON FUNCTION cron._sys_crontab(adata text) FROM PUBLIC;
GRANT ALL ON FUNCTION cron._sys_crontab(adata text) TO cron;


--
-- TOC entry 3584 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION _sys_crontab_l(); Type: ACL; Schema: cron; Owner: postgres
--

REVOKE ALL ON FUNCTION cron._sys_crontab_l() FROM PUBLIC;
GRANT ALL ON FUNCTION cron._sys_crontab_l() TO cron;


--
-- TOC entry 3586 (class 0 OID 0)
-- Dependencies: 287
-- Name: FUNCTION _w_cron_id_seq(adata text); Type: ACL; Schema: cron; Owner: postgres
--

REVOKE ALL ON FUNCTION cron._w_cron_id_seq(adata text) FROM PUBLIC;
GRANT ALL ON FUNCTION cron._w_cron_id_seq(adata text) TO cron;


--
-- TOC entry 3587 (class 0 OID 0)
-- Dependencies: 415
-- Name: FUNCTION active(ajobid integer, aactive character varying); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.active(ajobid integer, aactive character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.active(ajobid integer, aactive character varying) TO cron_role;


--
-- TOC entry 3588 (class 0 OID 0)
-- Dependencies: 385
-- Name: FUNCTION add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.add(acommand character varying, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying, ajobid integer, aactive character varying, aautoremove boolean, arole character varying) TO cron_role;


--
-- TOC entry 3589 (class 0 OID 0)
-- Dependencies: 393
-- Name: FUNCTION change(ajobid integer, acommand text); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.change(ajobid integer, acommand text) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.change(ajobid integer, acommand text) TO cron_role;


--
-- TOC entry 3590 (class 0 OID 0)
-- Dependencies: 295
-- Name: FUNCTION clear_log(); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.clear_log() FROM PUBLIC;
GRANT ALL ON FUNCTION cron.clear_log() TO cron_role;


--
-- TOC entry 3591 (class 0 OID 0)
-- Dependencies: 379
-- Name: FUNCTION frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.frequence(ajobid integer, aminute character varying, ahour character varying, adayofmonth character varying, amonth character varying, adayofweek character varying) TO cron_role;


--
-- TOC entry 3592 (class 0 OID 0)
-- Dependencies: 296
-- Name: FUNCTION isexists(ajobid integer); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.isexists(ajobid integer) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.isexists(ajobid integer) TO cron_role;


--
-- TOC entry 3593 (class 0 OID 0)
-- Dependencies: 297
-- Name: FUNCTION pg_list(); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.pg_list() FROM PUBLIC;
GRANT ALL ON FUNCTION cron.pg_list() TO cron_role;


--
-- TOC entry 3594 (class 0 OID 0)
-- Dependencies: 323
-- Name: FUNCTION remove(ajobid integer); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.remove(ajobid integer) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.remove(ajobid integer) TO cron_role;


--
-- TOC entry 3595 (class 0 OID 0)
-- Dependencies: 298
-- Name: FUNCTION run(ajobid integer); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.run(ajobid integer) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.run(ajobid integer) TO cron_role;


--
-- TOC entry 3596 (class 0 OID 0)
-- Dependencies: 290
-- Name: FUNCTION run(acommand character varying, arole character varying); Type: ACL; Schema: cron; Owner: cron
--

REVOKE ALL ON FUNCTION cron.run(acommand character varying, arole character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION cron.run(acommand character varying, arole character varying) TO cron_role;


--
-- TOC entry 3601 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE job_seq; Type: ACL; Schema: cron; Owner: cron
--

GRANT ALL ON SEQUENCE cron.job_seq TO cron_role;


--
-- TOC entry 3615 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE log; Type: ACL; Schema: cron; Owner: cron
--

GRANT SELECT ON TABLE cron.log TO cron_role;


--
-- TOC entry 3617 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE log_ilog_seq; Type: ACL; Schema: cron; Owner: cron
--

GRANT SELECT ON SEQUENCE cron.log_ilog_seq TO cron_role;


--
-- TOC entry 3635 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE pg_list; Type: ACL; Schema: cron; Owner: cron
--

GRANT SELECT ON TABLE cron.pg_list TO cron_role;


-- Completed on 2025-01-31 20:37:56

--
-- PostgreSQL database dump complete
--

