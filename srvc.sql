--
-- PostgreSQL database dump
--

-- Dumped from database version 15.7 (Ubuntu 15.7-0ubuntu0.23.10.1)
-- Dumped by pg_dump version 15.7 (Ubuntu 15.7-0ubuntu0.23.10.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: srvc; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA srvc;


--
-- Name: analyze_schema_functions(text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.analyze_schema_functions(p_schema_name text) RETURNS TABLE(function_type text, count_functions bigint, total_lines bigint, avg_complexity numeric)
    LANGUAGE sql
    AS $$
    select 
        case p.prokind
            when 'f' then 'function'
            when 'p' then 'procedure'
            when 'a' then 'aggregate'
            when 'w' then 'window'
            else 'unknown'
        end as function_type,
        count(*) as count_functions,
        -- Per le aggregate non possiamo usare pg_get_functiondef, usiamo un valore fisso
        sum(
            case 
                when p.prokind = 'a' then 5  -- Linee approssimative per aggregate
                else array_length(string_to_array(pg_get_functiondef(p.oid), E'\n'), 1)
            end
        ) as total_lines,
        avg(
            case 
                when p.prokind = 'a' then 5  -- Complessità approssimativa per aggregate
                else array_length(string_to_array(pg_get_functiondef(p.oid), E'\n'), 1)
            end
        ) as avg_complexity
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = p_schema_name
    group by p.prokind
    order by count_functions desc;
$$;


--
-- Name: clone_schema(text, text, boolean); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.clone_schema(source_schema text, dest_schema text, include_recs boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$

--  This function will clone all sequences, tables, data, views & functions from any existing schema to a new one
-- SAMPLE CALL:
-- SELECT clone_schema('public', 'new_schema', TRUE);

DECLARE
  src_oid          oid;
  tbl_oid          oid;
  func_oid         oid;
  object           text;
  buffer           text;
  srctbl           text;
  default_         text;
  column_          text;
  qry              text;
  dest_qry         text;
  v_def            text;
  seqval           bigint;
  sq_last_value    bigint;
  sq_max_value     bigint;
  sq_start_value   bigint;
  sq_increment_by  bigint;
  sq_min_value     bigint;
  sq_cache_value   bigint;
  sq_log_cnt       bigint;
  sq_is_called     boolean;
  sq_is_cycled     boolean;
  sq_cycled        char(10);

BEGIN

-- Check that source_schema exists
  SELECT oid INTO src_oid
    FROM pg_namespace
   WHERE nspname = quote_ident(source_schema);
  IF NOT FOUND
    THEN 
    RAISE NOTICE 'source schema % does not exist!', source_schema;
    RETURN ;
  END IF;

  -- Check that dest_schema does not yet exist
  PERFORM nspname 
    FROM pg_namespace
   WHERE nspname = quote_ident(dest_schema);
  IF FOUND
    THEN 
    RAISE NOTICE 'dest schema % already exists!', dest_schema;
    RETURN ;
  END IF;

  EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;

  -- Create sequences
  -- TODO: Find a way to make this sequence's owner is the correct table.
  FOR object IN
    SELECT sequence_name::text 
      FROM information_schema.sequences
     WHERE sequence_schema = quote_ident(source_schema)
  LOOP
    EXECUTE 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object);
    srctbl := quote_ident(source_schema) || '.' || quote_ident(object);

    EXECUTE 'SELECT last_value, max_value, start_value, increment_by, min_value, cache_value, log_cnt, is_cycled, is_called 
              FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';' 
              INTO sq_last_value, sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_log_cnt, sq_is_cycled, sq_is_called ; 

    IF sq_is_cycled 
      THEN 
        sq_cycled := 'CYCLE';
    ELSE
        sq_cycled := 'NO CYCLE';
    END IF;

    EXECUTE 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(object) 
            || ' INCREMENT BY ' || sq_increment_by
            || ' MINVALUE '     || sq_min_value 
            || ' MAXVALUE '     || sq_max_value
            || ' START WITH '   || sq_start_value
            || ' RESTART '      || sq_min_value 
            || ' CACHE '        || sq_cache_value 
            || sq_cycled || ' ;' ;

    buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
    IF include_recs 
        THEN
            EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ; 
    ELSE
            EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
    END IF;

  END LOOP;

-- Create tables 
  FOR object IN
    SELECT TABLE_NAME::text 
      FROM information_schema.tables 
     WHERE table_schema = quote_ident(source_schema)
       AND table_type = 'BASE TABLE'

  LOOP
    buffer := dest_schema || '.' || quote_ident(object);
    EXECUTE 'CREATE TABLE ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(object) 
        || ' INCLUDING ALL)';

    IF include_recs 
      THEN 
      -- Insert records from source table
      EXECUTE 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';';
    END IF;
 
    FOR column_, default_ IN
      SELECT column_name::text, 
             REPLACE(column_default::text, source_schema, dest_schema) 
        FROM information_schema.COLUMNS 
       WHERE table_schema = dest_schema 
         AND TABLE_NAME = object 
         AND column_default LIKE 'nextval(%' || quote_ident(source_schema) || '%::regclass)'
    LOOP
      EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || column_ || ' SET DEFAULT ' || default_;
    END LOOP;

  END LOOP;

--  add FK constraint
  FOR qry IN
    SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname) 
                          || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || pg_get_constraintdef(ct.oid) || ';'
      FROM pg_constraint ct
      JOIN pg_class rn ON rn.oid = ct.conrelid
     WHERE connamespace = src_oid
       AND rn.relkind = 'r'
       AND ct.contype = 'f'
         
    LOOP
      EXECUTE qry;

    END LOOP;


-- Create views 
  FOR object IN
    SELECT table_name::text,
           view_definition 
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)

  LOOP
    buffer := dest_schema || '.' || quote_ident(object);
    SELECT view_definition INTO v_def
      FROM information_schema.views
     WHERE table_schema = quote_ident(source_schema)
       AND table_name = quote_ident(object);
     
    EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def || ';' ;

  END LOOP;

-- Create functions 
  FOR func_oid IN
    SELECT oid
      FROM pg_proc 
     WHERE pronamespace = src_oid

  LOOP      
    SELECT pg_get_functiondef(func_oid) INTO qry;
    SELECT replace(qry, source_schema, dest_schema) INTO dest_qry;
    EXECUTE dest_qry;

  END LOOP;
  
  RETURN; 
 
END;
 
$$;


--
-- Name: create_additional_table(text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.create_additional_table(table_schema text, table_name text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$declare
/*
	IN table_schema text, 
	IN table_name text
*/

	_sqlStr text;
	
begin

	_sqlStr = srvc.ddl_get__history_table(
			table_schema, table_name
		) || srvc.ddl_get__bitemporal_view(
			table_schema, table_name
		);


	raise notice '%', _sqlStr;

	execute _sqlStr;

	return true;

end;
$$;


--
-- Name: ddl_get__bitemporal_view(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.ddl_get__bitemporal_view(table_schema text, table_name text, full_view_name text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
/*
	IN table_schema text
	, IN table_name text
	, IN full_view_name text DEFAULT null
*/
 	_table_schema alias for table_schema;
	_table_name alias for table_name;
	_view_name text;
	_view_schema text;
	_colName text;
	_ret text='';
	_trigger_name text;
	_array	text[];
	_i		integer;
begin
	if full_view_name is null then
		_view_schema=_table_schema;
		
		_i= strpos ( _table_name, '_current' );
		
		if _i >0 then
			_view_name = substr ( _table_name, 1, _i -1  );
		else
			_view_name=_table_name||'_current';		
		end if;


	else
		_array=string_to_array(full_view_name,'.');
		
		if array_length(_array,1)<>2 then
			raise exception 'full_view_name must be in the format _SCHEMA_._VIEW_NAME_, given: <%>', full_view_name;
		end if;
		_view_schema=_array[1];
		_view_name=_array[2];
	end if;
	
	full_view_name=format('%I.%I', _view_schema, _view_name);
	
	_trigger_name='trg_'|| _view_name;
	
	for _colName in 
		SELECT s.column_name
  		FROM information_schema.columns as s
 		WHERE s.table_schema = _table_schema
   		AND s.table_name   = _table_name
		and s.column_name <> 'bt_info'
   		order by s.ordinal_position
	loop
		_ret=_ret || format( E'\ts.%I\n\t,', _colName ) ;
	end loop;

	_ret=format($$
--drop view %1$s;

create or replace view %1$s as
select%2$s	false AS is_closed
	,	NULL::text AS modify_user_id
	,	NULL::timestamp with time zone AS modify_ts
	,   NULL::jsonb AS action_hints
from only %3$I.%4$I as s;
				
CREATE OR REPLACE TRIGGER %5$I
    INSTEAD OF INSERT OR DELETE OR UPDATE 
    ON %1$s
    FOR EACH ROW
    EXECUTE FUNCTION vrsn.trigger_handler();$$
	, full_view_name
	, _ret
	, _table_schema
	, _table_name
	, _trigger_name);
	
	
	return _ret;
end;$_$;


--
-- Name: FUNCTION ddl_get__bitemporal_view(table_schema text, table_name text, full_view_name text); Type: COMMENT; Schema: srvc; Owner: -
--

COMMENT ON FUNCTION srvc.ddl_get__bitemporal_view(table_schema text, table_name text, full_view_name text) IS 'Get the standard defintion of view ready for manage bitemporal storage.';


--
-- Name: ddl_get__history_table(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.ddl_get__history_table(table_schema text, table_name text, full_history_table_name text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
/*
	IN table_schema text
	, IN table_name text
	, IN full_history_table_name text DEFAULT null
*/
 	_table_schema alias for table_schema;
	_table_name alias for table_name;
	_full_current_table_name text = _table_schema || '.' ||_table_name;
	
	_history_table_name text;
	_history_table_schema text;
	
	_pkey_name text;
	_pkey_def text;

	_ret text=$retValue$
		CREATE TABLE %1$I.%2$I (
    		CONSTRAINT %3$s %4$s
		) INHERITS (%5$I.%6$I);
		$retValue$;
	
	_array	text[];
	_i		integer;
begin
	-- se il nome non è passato
	if full_history_table_name is null then	
		
		_history_table_schema=_table_schema;
		
		-- cerco il suffiso _current per rimuoverlo
		_i= strpos ( _table_name, '_current' );
		
		if _i >0 then
			_history_table_name = substr ( _table_name, 1, _i -1  );
		else 
			_history_table_name=_table_name;
		end if;
		
		_history_table_name=_history_table_name ||'_history';
	else
		_array=string_to_array(full_history_table_name,'.');
		
		
		_i=array_length(_array,1);
		
		if _i= 1 then
			_history_table_schema=_table_schema;
			_history_table_name= full_history_table_name;
		elseif _i=2 then
			_history_table_schema=_array[1];
			_history_table_name=_array[2];
		else
			raise exception 'full_history_table_name must be in the format [_SCHEMA_NAME_.]_TABLE_NAME_, given: <%>', full_history_table_name;
		end if;
	end if;
	
	
	-- ricompatto il nome
	--full_history_table_name=format('%I.%I', _history_table_schema, _history_table_name);
	
	-- recupero primary key e definizione
	SELECT conname, pg_get_constraintdef(oid) as def_text into _pkey_name,_pkey_def
	FROM pg_constraint
	WHERE contype = 'p' -- p = primary key constraint
    AND conrelid = to_regclass(_full_current_table_name); -- regclass will type the name of the object to its internal oid
	
	
	_pkey_name = replace(_pkey_name, _table_name, _history_table_name);
	_pkey_def = replace(_pkey_def, ')', ',bt_info)');
	
	_ret=format(_ret
		,	_history_table_schema
		,	_history_table_name
		,	_pkey_name
		,	_pkey_def
		,	_table_schema
		,	_table_name
	);

	
	return _ret;
end;$_$;


--
-- Name: find_table_dependencies(text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.find_table_dependencies(p_schema_name text, p_table_name text) RETURNS TABLE(function_name name, function_schema name, parameters text, return_type text, found_in text)
    LANGUAGE sql STABLE
    AS $$
WITH target_table AS (
    SELECT 
        p_schema_name AS schema_name,
        p_table_name AS table_name
),
search_patterns AS (
    SELECT 
        t.schema_name,
        t.table_name,
        t.schema_name || '.' || t.table_name AS qualified_name,
        -- Array di pattern diversi
        ARRAY[
            t.schema_name || '\.' || t.table_name,  -- schema.tabella
            t.table_name,                           -- solo tabella
            t.table_name || '%ROWTYPE',             -- per tipi %ROWTYPE
            'SETOF ' || t.schema_name || '\.' || t.table_name,  -- SETOF schema.tabella
            'SETOF ' || t.table_name                -- SETOF tabella
        ] AS patterns
    FROM target_table t
)
SELECT DISTINCT
    p.proname AS function_name,
    n.nspname AS function_schema,
    pg_get_function_identity_arguments(p.oid) AS parameters,
    pg_get_function_result(p.oid) AS return_type,
    STRING_AGG(
        CASE 
            WHEN pg_get_function_identity_arguments(p.oid) ~* pattern THEN 'Parameter'
            WHEN pg_get_function_result(p.oid) ~* pattern THEN 'Return Type'
            WHEN p.prosrc ~* pattern THEN 'Function Body'
        END, ', '
    ) AS found_in
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
CROSS JOIN search_patterns sp
CROSS JOIN UNNEST(sp.patterns) AS pattern
WHERE 
    pg_get_function_identity_arguments(p.oid) ~* pattern
    OR pg_get_function_result(p.oid) ~* pattern
    OR p.prosrc ~* pattern
GROUP BY p.proname, n.nspname, pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid)
ORDER BY p.proname;
$$;


--
-- Name: generate_coalesce_update(text, text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.generate_coalesce_update(p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text, p_target_type text DEFAULT 'table'::text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    column_info RECORD;
    param_declarations TEXT[] := ARRAY[]::TEXT[];
    set_clauses TEXT[] := ARRAY[]::TEXT[];
    function_name TEXT;
    function_sql TEXT;
    target_exists BOOLEAN := FALSE;
BEGIN
    function_name := format('update_%s_coalesce', p_table_name);
    
    -- Verifica che il target esista (tabella o vista)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = p_schema_name 
          AND table_name = p_table_name
          AND table_type IN ('BASE TABLE', 'VIEW')
    ) INTO target_exists;
    
    IF NOT target_exists THEN
        RAISE EXCEPTION 'Tabella o vista %.% non trovata', p_schema_name, p_table_name;
    END IF;
    
    -- Aggiungi sempre il parametro per la chiave primaria
    param_declarations := array_append(param_declarations, 
        format('p_%s INTEGER', p_primary_key));
    
    -- Costruisci dinamicamente parametri e clausole SET
    FOR column_info IN 
        SELECT 
            c.column_name,
            c.data_type,
            c.udt_name,
            c.udt_schema,
            CASE 
                -- Tipi standard PostgreSQL
                WHEN c.data_type = 'integer' THEN 'INTEGER'
                WHEN c.data_type = 'bigint' THEN 'BIGINT' 
                WHEN c.data_type = 'smallint' THEN 'SMALLINT'
                WHEN c.data_type = 'character varying' THEN 'TEXT'
                WHEN c.data_type = 'text' THEN 'TEXT'
                WHEN c.data_type = 'timestamp without time zone' THEN 'TIMESTAMP'
                WHEN c.data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
                WHEN c.data_type = 'boolean' THEN 'BOOLEAN'
                WHEN c.data_type = 'numeric' THEN 'NUMERIC'
                WHEN c.data_type = 'decimal' THEN 'DECIMAL'
                WHEN c.data_type = 'real' THEN 'REAL'
                WHEN c.data_type = 'double precision' THEN 'DOUBLE PRECISION'
                WHEN c.data_type = 'date' THEN 'DATE'
                WHEN c.data_type = 'time without time zone' THEN 'TIME'
                WHEN c.data_type = 'uuid' THEN 'UUID'
                WHEN c.data_type = 'jsonb' THEN 'JSONB'
                WHEN c.data_type = 'json' THEN 'JSON'
                WHEN c.data_type = 'bytea' THEN 'BYTEA'
                WHEN c.data_type = 'inet' THEN 'INET'
                WHEN c.data_type = 'cidr' THEN 'CIDR'
                WHEN c.data_type = 'macaddr' THEN 'MACADDR'
                WHEN c.data_type = 'money' THEN 'MONEY'
                WHEN c.data_type = 'point' THEN 'POINT'
                WHEN c.data_type = 'line' THEN 'LINE'
                WHEN c.data_type = 'lseg' THEN 'LSEG'
                WHEN c.data_type = 'box' THEN 'BOX'
                WHEN c.data_type = 'path' THEN 'PATH'
                WHEN c.data_type = 'polygon' THEN 'POLYGON'
                WHEN c.data_type = 'circle' THEN 'CIRCLE'
                WHEN c.data_type = 'interval' THEN 'INTERVAL'
                WHEN c.data_type = 'bit' THEN 'BIT'
                WHEN c.data_type = 'bit varying' THEN 'VARBIT'
                -- Tipi array
                WHEN c.data_type = 'ARRAY' THEN 
                    CASE c.udt_name
                        WHEN '_int4' THEN 'INTEGER[]'
                        WHEN '_int8' THEN 'BIGINT[]'
                        WHEN '_text' THEN 'TEXT[]'
                        WHEN '_varchar' THEN 'TEXT[]'
                        WHEN '_bool' THEN 'BOOLEAN[]'
                        WHEN '_numeric' THEN 'NUMERIC[]'
                        WHEN '_timestamp' THEN 'TIMESTAMP[]'
                        WHEN '_timestamptz' THEN 'TIMESTAMPTZ[]'
                        WHEN '_date' THEN 'DATE[]'
                        WHEN '_uuid' THEN 'UUID[]'
                        WHEN '_jsonb' THEN 'JSONB[]'
                        ELSE c.udt_name
                    END
                -- Tipi enumerati e definiti dall'utente
                WHEN c.data_type = 'USER-DEFINED' THEN
                    CASE 
                        WHEN c.udt_schema = 'public' THEN c.udt_name
                        ELSE format('%s.%s', c.udt_schema, c.udt_name)
                    END
                -- Fallback per tipi non riconosciuti
                ELSE 
                    CASE 
                        WHEN c.udt_schema = 'pg_catalog' THEN c.udt_name
                        WHEN c.udt_schema = 'public' THEN c.udt_name
                        ELSE format('%s.%s', c.udt_schema, c.udt_name)
                    END
            END as pg_type
        FROM information_schema.columns c
        WHERE c.table_schema = p_schema_name 
          AND c.table_name = p_table_name
          AND c.column_name != p_primary_key
        ORDER BY c.ordinal_position
    LOOP
        -- Dichiarazione parametro con prefisso p_ e DEFAULT NULL
        param_declarations := array_append(param_declarations, 
            format('p_%s %s DEFAULT NULL', column_info.column_name, column_info.pg_type));
        
        -- Clausola SET con COALESCE
        set_clauses := array_append(set_clauses,
            format('%I = COALESCE(p_%s, %I)', 
                   column_info.column_name, 
                   column_info.column_name,
                   column_info.column_name));
    END LOOP;
    
    -- Genera la funzione completa
    function_sql := format($func$
CREATE OR REPLACE FUNCTION %s(
    %s
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $body1$
DECLARE
    affected_rows INTEGER;
BEGIN
    UPDATE %I.%I 
    SET %s
    WHERE %I = p_%s;
    
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows > 0;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Errore durante l''update di %%.%%: %%', p_schema_name, p_table_name, SQLERRM;
        RETURN FALSE;
END;
$body1$;$func$,
        function_name,
        array_to_string(param_declarations, E',\n    '),
        p_schema_name,
        p_table_name,
        array_to_string(set_clauses, E',\n        '),
        p_primary_key,
        p_primary_key
    );
    
    RETURN function_sql;
END;
$_$;


--
-- Name: generate_function_parameters(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.generate_function_parameters(p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    column_info RECORD;
    param_declarations TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Parametro chiave primaria
    param_declarations := array_append(param_declarations, 
        format('p_%s INTEGER', p_primary_key));
    
    -- Altri parametri con gestione UDT migliorata
    FOR column_info IN 
        SELECT 
            c.column_name,
            c.data_type,
            c.udt_name,
            c.udt_schema,
            CASE 
                -- Tipi standard PostgreSQL
                WHEN c.data_type = 'integer' THEN 'INTEGER'
                WHEN c.data_type = 'bigint' THEN 'BIGINT'
                WHEN c.data_type = 'smallint' THEN 'SMALLINT'
                WHEN c.data_type = 'character varying' THEN 'TEXT'
                WHEN c.data_type = 'text' THEN 'TEXT'
                WHEN c.data_type = 'timestamp without time zone' THEN 'TIMESTAMP'
                WHEN c.data_type = 'timestamp with time zone' THEN 'TIMESTAMPTZ'
                WHEN c.data_type = 'boolean' THEN 'BOOLEAN'
                WHEN c.data_type = 'numeric' THEN 'NUMERIC'
                WHEN c.data_type = 'decimal' THEN 'DECIMAL'
                WHEN c.data_type = 'real' THEN 'REAL'
                WHEN c.data_type = 'double precision' THEN 'DOUBLE PRECISION'
                WHEN c.data_type = 'date' THEN 'DATE'
                WHEN c.data_type = 'time without time zone' THEN 'TIME'
                WHEN c.data_type = 'uuid' THEN 'UUID'
                WHEN c.data_type = 'jsonb' THEN 'JSONB'
                WHEN c.data_type = 'json' THEN 'JSON'
                WHEN c.data_type = 'bytea' THEN 'BYTEA'
                WHEN c.data_type = 'inet' THEN 'INET'
                WHEN c.data_type = 'cidr' THEN 'CIDR'
                WHEN c.data_type = 'macaddr' THEN 'MACADDR'
                WHEN c.data_type = 'money' THEN 'MONEY'
                WHEN c.data_type = 'interval' THEN 'INTERVAL'
                -- Tipi array
                WHEN c.data_type = 'ARRAY' THEN 
                    CASE c.udt_name
                        WHEN '_int4' THEN 'INTEGER[]'
                        WHEN '_int8' THEN 'BIGINT[]'
                        WHEN '_text' THEN 'TEXT[]'
                        WHEN '_varchar' THEN 'TEXT[]'
                        WHEN '_bool' THEN 'BOOLEAN[]'
                        WHEN '_numeric' THEN 'NUMERIC[]'
                        WHEN '_timestamp' THEN 'TIMESTAMP[]'
                        WHEN '_timestamptz' THEN 'TIMESTAMPTZ[]'
                        WHEN '_date' THEN 'DATE[]'
                        WHEN '_uuid' THEN 'UUID[]'
                        WHEN '_jsonb' THEN 'JSONB[]'
                        ELSE c.udt_name
                    END
                -- Tipi enumerati e definiti dall'utente
                WHEN c.data_type = 'USER-DEFINED' THEN
                    CASE 
                        WHEN c.udt_schema = 'public' THEN c.udt_name
                        ELSE format('%s.%s', c.udt_schema, c.udt_name)
                    END
                -- Fallback
                ELSE 
                    CASE 
                        WHEN c.udt_schema = 'pg_catalog' THEN c.udt_name
                        WHEN c.udt_schema = 'public' THEN c.udt_name
                        ELSE format('%s.%s', c.udt_schema, c.udt_name)
                    END
            END as pg_type
        FROM information_schema.columns c
        WHERE c.table_schema = p_schema_name 
          AND c.table_name = p_table_name
          AND c.column_name != p_primary_key
        ORDER BY c.ordinal_position
    LOOP
        param_declarations := array_append(param_declarations, 
            format('p_%s %s DEFAULT NULL', column_info.column_name, column_info.pg_type));
    END LOOP;
    
    RETURN array_to_string(param_declarations, E',\n    ');
END;
$$;


--
-- Name: generate_set_clauses(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.generate_set_clauses(p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    column_info RECORD;
    set_clauses TEXT[] := ARRAY[]::TEXT[];
BEGIN
    FOR column_info IN 
        SELECT column_name
        FROM information_schema.columns 
        WHERE table_schema = p_schema_name 
          AND table_name = p_table_name
          AND column_name != p_primary_key
        ORDER BY ordinal_position
    LOOP
        set_clauses := array_append(set_clauses,
            format('%I = COALESCE(p_%s, %I)', 
                   column_info.column_name, 
                   column_info.column_name,
                   column_info.column_name));
    END LOOP;
    
    RETURN array_to_string(set_clauses, E',\n        ');
END;
$$;


--
-- Name: get_aggregate_ddl(text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_aggregate_ddl(p_schema_name text, p_aggregate_name text DEFAULT NULL::text) RETURNS TABLE(aggregate_name text, drop_script text, create_script text)
    LANGUAGE sql
    AS $$
    select 
        p.proname as aggregate_name,
        format('drop aggregate if exists %I.%I(%s);',
            n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
        ) as drop_script,
        
        -- Script di creazione COMPLETO (solo campi esistenti in tutte le versioni)
        format('create aggregate %I.%I(%s) (%s%s%s%s%s%s%s%s%s);',
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid),
            
            -- State function (obbligatorio)
            format('sfunc = %s', 
                case 
                    when sf_ns.nspname != n.nspname then
                        quote_ident(sf_ns.nspname) || '.' || quote_ident(sf.proname)
                    else quote_ident(sf.proname)
                end
            ),
            
            -- State type (obbligatorio)
            format(', stype = %s', 
                format_type(a.aggtranstype, null)
            ),
            
            -- State size (se diverso da default e colonna esiste)
            case 
                when exists (
                    select 1 from information_schema.columns 
                    where table_name = 'pg_aggregate' and column_name = 'aggtransspace'
                ) and a.aggtransspace != 0 then 
                    format(', sspace = %s', a.aggtransspace)
                else ''
            end,
            
            -- Final function (opzionale)
            case 
                when a.aggfinalfn != 0 then
                    format(', finalfunc = %s',
                        case 
                            when ff_ns.nspname != n.nspname then
                                quote_ident(ff_ns.nspname) || '.' || quote_ident(ff.proname)
                            else quote_ident(ff.proname)
                        end
                    )
                else ''
            end,
            
            -- Final function extra args (se colonna esiste)
            case 
                when exists (
                    select 1 from information_schema.columns 
                    where table_name = 'pg_aggregate' and column_name = 'aggfinalextra'
                ) and a.aggfinalextra then ', finalfunc_extra'
                else ''
            end,
            
            -- Combine function (per parallel aggregates)
            case 
                when a.aggcombinefn != 0 then
                    format(', combinefunc = %s',
                        case 
                            when cf_ns.nspname != n.nspname then
                                quote_ident(cf_ns.nspname) || '.' || quote_ident(cf.proname)
                            else quote_ident(cf.proname)
                        end
                    )
                else ''
            end,
            
            -- Serial/Deserial functions (per parallel aggregates)
            case 
                when a.aggserialfn != 0 then
                    format(', serialfunc = %s, deserialfunc = %s',
                        case 
                            when serf_ns.nspname != n.nspname then
                                quote_ident(serf_ns.nspname) || '.' || quote_ident(serf.proname)
                            else quote_ident(serf.proname)
                        end,
                        case 
                            when deserf_ns.nspname != n.nspname then
                                quote_ident(deserf_ns.nspname) || '.' || quote_ident(deserf.proname)
                            else quote_ident(deserf.proname)
                        end
                    )
                else ''
            end,
            
            -- Initial condition
            case 
                when a.agginitval is not null then 
                    format(', initcond = %L', a.agginitval)
                else ''
            end,
            
            -- Sort operator (opzionale) - se colonna esiste
            case 
                when exists (
                    select 1 from information_schema.columns 
                    where table_name = 'pg_aggregate' and column_name = 'aggsortop'
                ) and a.aggsortop != 0 then
                    format(', sortop = %s', op.oprname)
                else ''
            end,
            
            -- Parallel safety
            case 
                when p.proparallel = 's' then ', parallel = safe'
                when p.proparallel = 'r' then ', parallel = restricted'
                when p.proparallel = 'u' then ', parallel = unsafe'
                else ''
            end
        ) as create_script
        
    from pg_aggregate a
    join pg_proc p on p.oid = a.aggfnoid
    join pg_namespace n on n.oid = p.pronamespace
    
    -- State function (obbligatorio)
    join pg_proc sf on sf.oid = a.aggtransfn
    join pg_namespace sf_ns on sf_ns.oid = sf.pronamespace
    
    -- Final function (opzionale)
    left join pg_proc ff on ff.oid = a.aggfinalfn
    left join pg_namespace ff_ns on ff_ns.oid = ff.pronamespace
    
    -- Combine function (opzionale)
    left join pg_proc cf on cf.oid = a.aggcombinefn
    left join pg_namespace cf_ns on cf_ns.oid = cf.pronamespace
    
    -- Serial functions (opzionali)
    left join pg_proc serf on serf.oid = a.aggserialfn
    left join pg_namespace serf_ns on serf_ns.oid = serf.pronamespace
    left join pg_proc deserf on deserf.oid = a.aggdeserialfn
    left join pg_namespace deserf_ns on deserf_ns.oid = deserf.pronamespace
    
    -- Sort operator (opzionale)
    left join pg_operator op on op.oid = a.aggsortop
    
    where n.nspname = p_schema_name
        and (p_aggregate_name is null or p.proname = p_aggregate_name)
    order by p.proname;
$$;


--
-- Name: get_all_functions_ddl(text, text, boolean); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_all_functions_ddl(p_schema_name text, p_function_name text DEFAULT NULL::text, p_include_aggregates boolean DEFAULT true) RETURNS TABLE(function_name text, function_type text, drop_script text, create_script text)
    LANGUAGE sql
    AS $$
    -- Functions, Procedures, Window Functions
    select * from srvc.get_function_ddl(p_schema_name, p_function_name)
    
    union all
    
    -- Aggregates (se richiesti)
    select 
        aggregate_name as function_name,
        'aggregate' as function_type,
        drop_script,
        create_script
    from srvc.get_aggregate_ddl(p_schema_name, p_function_name)
    where p_include_aggregates
    
    order by function_type, function_name;
$$;


--
-- Name: get_custom_types_info(text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_custom_types_info(p_schema_name text DEFAULT NULL::text) RETURNS TABLE(type_schema text, type_name text, type_category character, type_description text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.nspname::TEXT as type_schema,
        t.typname::TEXT as type_name,
        t.typcategory as type_category,
        CASE t.typcategory
            WHEN 'A' THEN 'Array type'
            WHEN 'B' THEN 'Boolean type'
            WHEN 'C' THEN 'Composite type'
            WHEN 'D' THEN 'Date/time type'
            WHEN 'E' THEN 'Enum type'
            WHEN 'G' THEN 'Geometric type'
            WHEN 'I' THEN 'Network address type'
            WHEN 'N' THEN 'Numeric type'
            WHEN 'P' THEN 'Pseudo-type'
            WHEN 'R' THEN 'Range type'
            WHEN 'S' THEN 'String type'
            WHEN 'T' THEN 'Timespan type'
            WHEN 'U' THEN 'User-defined type'
            WHEN 'V' THEN 'Bit-string type'
            WHEN 'X' THEN 'Unknown type'
            ELSE 'Other'
        END::TEXT as type_description
    FROM pg_type t
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE (p_schema_name IS NULL OR n.nspname = p_schema_name)
      AND t.typtype IN ('e', 'c', 'd', 'r') -- enum, composite, domain, range
    ORDER BY n.nspname, t.typname;
END;
$$;


--
-- Name: get_function_ddl(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_function_ddl(p_schema_name text, p_function_name text DEFAULT NULL::text, p_function_type text DEFAULT NULL::text) RETURNS TABLE(function_name text, function_type text, drop_script text, create_script text)
    LANGUAGE plpgsql
    AS $_$
declare
    rec record;
    func_args text;
    func_returns text;
    func_body text;
    func_props text;
    prop text;
    create_stmt text;
    drop_stmt text;
    func_type_label text;
begin
    for rec in
        select 
            p.oid,
            n.nspname as schema_name,
            p.proname as proc_name,
            case p.prokind
                when 'f' then 'function'
                when 'p' then 'procedure'
                when 'a' then 'aggregate'
                when 'w' then 'window'
                else 'unknown'
            end as proc_type,
            p.prokind,
            p.prorettype,
            p.proretset,
            p.provolatile,
            p.proisstrict,
            p.prosecdef,
            p.proleakproof,
            p.proparallel,
            p.procost,
            p.prorows,
            l.lanname as language_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            pg_get_functiondef(p.oid) as function_definition
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        join pg_language l on l.oid = p.prolang
        where n.nspname = p_schema_name
            and (p_function_name is null or p.proname = p_function_name)
            and (p_function_type is null or 
                 case p.prokind
                     when 'f' then 'function'
                     when 'p' then 'procedure'
                     when 'a' then 'aggregate'
                     when 'w' then 'window'
                     else 'unknown'
                 end = p_function_type)
            and p.prokind != 'a'  -- Gli aggregates hanno logica separata
        order by p.proname, p.oid
    loop
        -- Genera DROP statement
        if rec.proc_type = 'procedure' then
            drop_stmt := format('drop procedure if exists %I.%I(%s);',
                rec.schema_name, rec.proc_name, rec.arguments);
        else
            drop_stmt := format('drop function if exists %I.%I(%s);',
                rec.schema_name, rec.proc_name, rec.arguments);
        end if;
        
        -- Per aggregates e window functions, usa la funzione specifica
        if rec.prokind = 'a' then
            -- Salta gli aggregates, gestiti dalla funzione dedicata
            continue;
        elsif rec.prokind = 'w' then
            -- Window functions - usa pg_get_functiondef che include tutto
            create_stmt := rec.function_definition;
        else
            -- Functions e Procedures - costruisci manualmente per maggior controllo
            func_args := rec.arguments;
            
            -- Costruisci le proprietà della funzione
            func_props := '';
            
            -- Language
            func_props := func_props || e'\n' || format('language %s', quote_ident(rec.language_name));
            
            -- Volatility
            case rec.provolatile
                when 'i' then func_props := func_props || e'\nimmutable';
                when 's' then func_props := func_props || e'\nstable';
                -- 'v' (volatile) è il default, non serve specificarlo
                else null;
            end case;
            
            -- Strictness
            if rec.proisstrict then
                func_props := func_props || e'\nstrict';
            end if;
            
            -- Security
            if rec.prosecdef then
                func_props := func_props || e'\nsecurity definer';
            end if;
            
            -- Leak proof
            if rec.proleakproof then
                func_props := func_props || e'\nleakproof';
            end if;
            
            -- Parallel safety
            case rec.proparallel
                when 's' then func_props := func_props || e'\nparallel safe';
                when 'r' then func_props := func_props || e'\nparallel restricted';
                when 'u' then func_props := func_props || e'\nparallel unsafe';
                else null;
            end case;
            
            -- Cost (se diverso dal default)
            if (rec.language_name = 'sql' and rec.procost != 1) or
               (rec.language_name != 'sql' and rec.procost != 100) then
                func_props := func_props || e'\n'|| format('cost %s', rec.procost);
            end if;
            
            -- Rows (per functions che ritornano set)
            if rec.proretset and rec.prorows != 1000 then
                func_props := func_props || e'\n'|| format('rows %s', rec.prorows);
            end if;
            
            -- Estrai il corpo della funzione dal definition completo
            func_body := substring(rec.function_definition from 'AS\s+(.*)$');
            if func_body is null then
                -- Fallback: usa la definizione completa
                create_stmt := rec.function_definition;
            else
                -- Costruisci il CREATE statement
                if rec.proc_type = 'procedure' then
                    create_stmt := format(e'create or replace procedure %I.%I(%s)\n%s\nas %s',
                        rec.schema_name,
                        rec.proc_name,
                        coalesce(func_args, ''),                        
                        func_props,
                        func_body
                    );
                else
                    func_returns := rec.return_type;
                    create_stmt := format(e'create or replace function %I.%I(%s) returns %s\n%s\nas %s',
                        rec.schema_name,
                        rec.proc_name,
                        coalesce(func_args, ''),
                        func_returns,
                        func_props,
                        func_body
                    );
                end if;
            end if;
        end if;
        
        return query select
            rec.proc_name,
            rec.proc_type,
            drop_stmt,
            create_stmt;
            
    end loop;
    
    return;
end $_$;


--
-- Name: get_schema_funciton_definition(text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_schema_funciton_definition(schamas_where_search text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
declare
/*
	IN schamas_where_search text DEFAULT null,

*/
	_jb	jsonb='{"status":"KO"}'::jsonb;
	_schema_list  text[];
	_i 		integer;

	_rec	record;

	_found text[];

begin


	if schamas_where_search is null then
		SELECT array_agg(quote_ident(s.schema_name)) into _schema_list
		FROM srvc.schema_to_refact as s
		where s.search_actived;
		
		_jb['schemasFromTable']=to_jsonb(true);
		
	else
		_schema_list = regexp_split_to_array(schamas_where_search,'\s*,\s*');
		
		for _i in 1..array_length(_schema_list,1) loop
			_schema_list[_i]=quote_ident(_schema_list[_i]);		
		end loop;
		
	end if;
	
	_jb['schemas']=to_jsonb(_schema_list);

	for _rec in 
		with schema_list as(
			select * 
			from unnest(_schema_list) as x(sn)
		), schema_id as(
		  SELECT oid as s_oid, nspname			
			FROM pg_namespace as n
			inner join schema_list as s on nspname= s.sn
		)
		SELECT s.s_oid, p.oid as f_oid
		,s.nspname, p.proname, (s.nspname|| '.' || p.proname)::text as f_fullname
		, CASE p.prokind
			  WHEN 'f' THEN 'function'
			  WHEN 'a' THEN 'aggregate'
			  WHEN 'p' THEN 'procedure'
			  WHEN 'w' THEN 'function'  -- window function (rarely applicable)
			  -- ELSE NULL              -- not possible in pg 11
			END as f_type
		FROM schema_id as s
		inner join pg_proc as p on  p.pronamespace = s.s_oid
	loop
		
				
		_jb['workingOn']= to_jsonb(_rec.f_fullname);

		if _rec.f_type ='aggregate' then
			raise notice e'\n%',
				srvc.get_aggregate_ddl(
    			_rec.nspname,
    			_rec.proname
			);
		else
			raise notice E'\n--DROP % IF EXISTS % ;\n%'
					, _rec.f_type
					, _rec.f_oid::regprocedure
					, pg_get_functiondef(_rec.f_oid);
		end if;				
		
		_found =array_append(_found,_rec.f_fullname);
	
	end loop;
	
	
	_jb['found']=to_jsonb(_found);
	_jb['foundCount']=to_jsonb(array_length(_found,1));
	_jb['status']=to_jsonb('OK'::text);
	
	return _jb - 'workingOn';
	
exception
	when others then
		declare
			v_state   TEXT;
			v_msg     TEXT;
			v_detail  TEXT;
			v_hint    TEXT;
			v_context TEXT;		
			_j	jsonb=$$
			{
				"state"  :  null
				,"message": null
				,"detail" : null
				,"hint"   : null
				,"context": null
			}$$::jsonb;
		begin

			get stacked diagnostics
				v_state   = returned_sqlstate,				
				v_msg     = message_text,
				v_detail  = pg_exception_detail,
				v_hint    = pg_exception_hint,
				v_context = pg_exception_context;
				
			_j['state']  =to_jsonb(v_state);
			_j['message']=to_jsonb(v_msg);
			_j['detail'] =to_jsonb(v_detail);
			_j['hint']   =to_jsonb(v_hint);
			_j['context']=to_jsonb(v_context);
			
			_jb['error']=_j;
			
		end;
		return _jb;
	

end;
$_$;


--
-- Name: get_schema_package(text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_schema_package(schemas_where_search text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
declare
/*
	IN schemas_where_search text DEFAULT null,

*/
	_jb	jsonb='{"status":"KO"}'::jsonb;
	_schema_list  text[];
	_i 		integer;
	_function text='';
	_currentName text;
	_package text='';
	_schema text='';
	_method text='';
	_function_struct text[];
	

	_rec	record;

	_functionStruct text[];
	_fn	integer;
	_pn	integer=0;
	_t	text;

/*
	L'Er identifica 4 array:
	1) inizia con __ --> private
	2) inizia con _d_ --> deprecated
	3) nome packate
	4) nome metodo
*/
	_er	text ='^(?:(__)|(_d_))?(?:(\w+?)__)?(.*)$';

begin

	if schemas_where_search is null then
		SELECT array_agg(quote_ident(s.schema_name)) into _schema_list
		FROM srvc.schema_to_refact as s
		where s.search_actived;
		
		_jb['schemasFromTable']=to_jsonb(true);
		
	else
		_schema_list = regexp_split_to_array(schemas_where_search,'\s*,\s*');
		
		for _i in 1..array_length(_schema_list,1) loop
			_schema_list[_i]=quote_ident(_schema_list[_i]);		
		end loop;
		
	end if;
	
	_jb['schemas']=to_jsonb(_schema_list);

	_i=0;
	
	<<func_list>>
	for _rec in 
		with schema_list as(
			select *
			from unnest(_schema_list) as x(sn)
		), schema_id as(
		  SELECT oid as s_oid, nspname			
			FROM pg_namespace as n
			inner join schema_list as s on nspname= s.sn
		)
		SELECT s.s_oid, p.oid as f_oid
		,s.nspname, p.proname, (s.nspname|| '.' || p.proname)::text as f_fullname
		, CASE p.prokind		
			  WHEN 'f' THEN 'function'
			  WHEN 'a' THEN 'aggregate'
			  WHEN 'p' THEN 'procedure'
			  WHEN 'w' THEN 'function'  -- window function (rarely applicable)
			  -- ELSE NULL              -- not possible in pg 11
			END as f_type
			,d.description			
			
		FROM schema_id as s
		inner join pg_proc as p on  p.pronamespace = s.s_oid
		LEFT JOIN pg_description d
                 ON d.objoid = p.oid
		--where proname like '%\_\_%' and proname not like '\_d\_%' --deprecated
--		where proname='get_resolved_default_value'
		order by s.nspname, p.proname
	loop
		
		_function_struct=regexp_match(_rec.proname, _er) ;
		
		-- Se null non è una funzione di un package
/*		if _function_struct is null then
			continue func_list;
		end if;
*/
		if _function_struct[3] ='' or _function_struct[3] is null then
			_function_struct[3]='__Without Package__';
		end if;
		-- Se cambia lo schema azzero i contatori e forzo il cambio di package
		if _schema <> _rec.nspname then
			_fn=0;
			_pn=0;
			_schema = _rec.nspname;
			_package='';
		end if;
		
		-- Se cambia il package azzero i contatori e forzo il cambio di funzione
		if _package<>_function_struct[3] then
			_fn=0;
			_pn=_pn+1;
			_package=_function_struct[3];
			_function='';
		end if;

		-- Se cambia il nome di funzione azzero i contatori
		if _function <> _rec.proname then
			_i=0;
			_jb['workingOn']= to_jsonb(_rec.f_fullname);
		else
			_i=_i+1;
			_jb['workingOn']= to_jsonb(_rec.f_fullname || ' ('|| _i ||')' );
			_function_struct[4]=_function_struct[4] || ' ('|| _i ||')' ;

		end if;
		
		_function = _rec.proname;
		
		_fn=_fn+1;

		if _function_struct[2] is not null then
			_method= 'deprecated';
		elseif _function_struct[1] is not null then
			_method= 'private';
		else
			_method= 'public';
		end if;

		
		if _function_struct[4] = 'readme' then
			execute format('select %s()', _rec.f_fullname) into _t;
			--raise notice '%', _t;
			_jb [_schema][ _package ]['description']=to_jsonb(_t);
		end if;
		
		if _rec.description is not null then
			_jb [_schema][ _package ][_method][ _function_struct[4] ]['description']=to_jsonb(_rec.description);
		end if;
		
		_jb [_schema][ _package ][_method][ _function_struct[4] ]['args']=to_jsonb( pg_get_function_arguments(_rec.f_oid ) );
		_jb [_schema][ _package ][_method][ _function_struct[4] ]['return']=to_jsonb( pg_get_function_result(_rec.f_oid ) );
		
		_jb [_schema][ _package ][_method][ _function_struct[4] ]['full_identifier']=to_jsonb( _rec.f_fullname);
		
		_jb [_schema][ _package ]['methodCount']=_fn;
		_jb [_schema]['packageCount']=to_jsonb(_pn);
	end loop;
	
	
	_jb['status']=to_jsonb('OK'::text);
--	_jb['packageCount']=to_jsonb(_pn);
	
	return _jb - 'workingOn';
	
exception
	when others then
		declare
			v_state   TEXT;
			v_msg     TEXT;
			v_detail  TEXT;
			v_hint    TEXT;
			v_context TEXT;		
			_j	jsonb=$$
			{
				"state"  :  null
				,"message": null
				,"detail" : null
				,"hint"   : null
				,"context": null
			}$$::jsonb;
		begin

			get stacked diagnostics
				v_state   = returned_sqlstate,				
				v_msg     = message_text,
				v_detail  = pg_exception_detail,
				v_hint    = pg_exception_hint,
				v_context = pg_exception_context;
				
			_j['state']  =to_jsonb(v_state);
			_j['message']=to_jsonb(v_msg);
			_j['detail'] =to_jsonb(v_detail);
			_j['hint']   =to_jsonb(v_hint);
			_j['context']=to_jsonb(v_context);
			
			_jb['error']=_j;
			
		end;
		return _jb;
	

end;
$_$;


--
-- Name: get_schema_package_md(text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_schema_package_md(schemas_where_search text) RETURNS text
    LANGUAGE plpgsql
    AS $$



declare
	v_schema_info jsonb;
	v_result text := '# PostgreSQL Bitemporal Solution: Funciton references
	
[main](main.md) - [readme](../README.md)
';
	v_result_packages text := '';
	v_result_functions text := '';
	v_temp_package text := '';
	v_schema_name text;
	v_package_name text;
	v_visibility text;
	v_function_name text;
	v_function_info jsonb;
	v_package_info jsonb;
	v_visibility_info jsonb;
	v_description text;
	v_args text;
	v_return_type text;
	v_full_identifier text;
	v_method_count integer;
	v_package_count integer;
begin

	-- Recupero il jsonb
	v_schema_info=srvc.get_schema_package(schemas_where_search);
	
	-- Estrai informazioni generali
--	v_package_count := (v_schema_info->>'packageCount')::integer;
	
	-- Itera sui schemi
	for v_schema_name in 
		select chiave 
		from jsonb_object_keys(v_schema_info) as l(chiave)
		where chiave not in ('status', 'schemas', 'packageCount')
		order by chiave
	loop

		v_package_count := (v_schema_info->v_schema_name->>'packageCount')::integer;
	
		v_result := v_result || e'\n\n## Schema: ' || v_schema_name 
			|| e'\n\nPackage Count: ' || v_package_count ;
		
		v_result_packages := '';
		v_result_functions := '';
/*		
raise notice 'v_schema_name: %', v_schema_name;
if v_result is null then
raise exception 'cazzo: %, %', v_schema_name, v_package_count ;
end if;
*/
		-- Itera su tutti i packages
		for v_package_name in 
			select chiave 
			from jsonb_object_keys(v_schema_info->v_schema_name) as l(chiave)
			where chiave not in ('packageCount')
			order by chiave
		loop

--raise notice 'v_package_name: %',v_package_name;
			v_package_info := v_schema_info->v_schema_name->v_package_name;
			v_method_count := (v_package_info->>'methodCount')::integer;
			v_temp_package := '';
			
--raise notice 'v_package_info: %',v_package_info;
			v_temp_package := v_temp_package || e'\n\nMethod Count: ' || v_method_count;
			
			-- Itera sulle visibilità (public, private, deprecated)
			for v_visibility in 
				select chiave 
				from jsonb_object_keys(v_package_info) as l(chiave)
				where chiave not in ('methodCount', 'description')
				order by chiave

			loop
				v_visibility_info := v_package_info->v_visibility;
				
				if jsonb_typeof(v_visibility_info) = 'object' and (select count(*) from jsonb_object_keys(v_visibility_info)) >0  then
				
					v_temp_package := v_temp_package || e'\n\n#### ' || upper(left(v_visibility, 1)) || substring(v_visibility from 2) || ' Functions';
					
					-- Itera sulle funzioni
					for v_function_name in 					
						select chiave 
						from jsonb_object_keys(v_visibility_info) as l(chiave)
						order by chiave						
					loop
						v_function_info := v_visibility_info->v_function_name;
						
						v_args := coalesce(v_function_info->>'args', '');
						v_return_type := coalesce(v_function_info->>'return', 'void');
						v_full_identifier := coalesce(v_function_info->>'full_identifier', '');
						v_description := coalesce(v_function_info->>'description', '');
						
						v_temp_package := v_temp_package || e'\n\n##### ' || v_function_name
							|| case when v_description != '' then
								e'\n' || v_description
								else '' end
							|| e'\n- *Full Identifier*: `' || v_full_identifier
							|| e'`\n- *Arguments*: `' || v_args 
							|| e'`\n- *Returns*: `' || v_return_type							
							|| '`';
						


						
--raise notice 'v_temp_package: %',v_temp_package;						
						
					end loop;
				end if;
			end loop;
			
			-- Inizializza il contenuto del package
			-- Accoda alla variabile appropriata basandosi sul nome del package
			if v_package_name = '__Without Package__' then
				v_result_functions :=  e'\n\n---\n\n### Functions Without Package\n\n'
				|| v_temp_package
				;
			else
				v_result_packages := v_result_packages
					||	e'\n\n### Package: ' || v_package_name 
					||	case when v_package_info ? 'description' then
						e'\n\n' || (v_package_info->>'description') 
						else '' end
					|| v_temp_package;
				
			end if;

			
		end loop;
/*
if v_result is null then
raise exception 'v_result is null';
elsif  v_result_packages is null then
raise exception 'v_result_packages is null';
elsif v_result_functions is null then
raise exception 'v_result_functions is null';
else
raise notice 'fin qui tutto bene';
end if;
*/		
		
		-- Combina i risultati per questo schema: prima i packages, poi le funzioni senza package
		v_result := v_result || v_result_packages || v_result_functions|| e'\n\n---\n[main](main.md) - [readme](../README.md)';
	end loop;
	
	return v_result;
end;
$$;


--
-- Name: get_window_function_ddl(text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.get_window_function_ddl(p_schema_name text, p_function_name text DEFAULT NULL::text) RETURNS TABLE(function_name text, function_type text, drop_script text, create_script text)
    LANGUAGE sql
    AS $$
    select 
        p.proname as function_name,
        'window' as function_type,
        format('drop function if exists %I.%I(%s);',
            n.nspname, p.proname, pg_get_function_arguments(p.oid)
        ) as drop_script,
        pg_get_functiondef(p.oid) as create_script
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = p_schema_name
        and p.prokind = 'w'
        and (p_function_name is null or p.proname = p_function_name)
    order by p.proname;
$$;


--
-- Name: is_updatable_view(text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.is_updatable_view(p_schema_name text, p_view_name text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_updatable BOOLEAN := FALSE;
BEGIN
    SELECT CASE 
        WHEN is_updatable = 'YES' THEN TRUE 
        ELSE FALSE 
    END
    INTO is_updatable
    FROM information_schema.views
    WHERE table_schema = p_schema_name 
      AND table_name = p_view_name;
    
    RETURN COALESCE(is_updatable, FALSE);
END;
$$;


--
-- Name: refact_function_call(text, text, text, boolean, boolean); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.refact_function_call(text_to_search text, text_to_replace text, schamas_where_search text DEFAULT NULL::text, simulation boolean DEFAULT true, print_query boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
declare
/*
	IN text_to_search text,
	IN text_to_replace text,
	IN schamas_where_search text DEFAULT null,
	IN simulation boolean DEFAULT false
	in print_query  boolean DEFAULT false
*/
	_print	alias for print_query;
	_execute	boolean;

	_replace	boolean=true;
	_jb	jsonb='{"status":"KO"}'::jsonb;
	_schema_list  text[];
	_i 		integer;
	_funcDrop	text;
	_funcDef	text;
	_funcArg	text;
	_funcRet	text;
	_rec	record;
	
	_found text[];
	_notFound text[];
begin

	if text_to_search is null then
		raise exception 'Impossibile eseguire una ricerca senza parametri';
	end if;
	
	if simulation then
		_execute=false;
	else		
		_execute=true;
	end if;
	
	if _print is null then
		_print=false;
	end if;
	
	if text_to_replace is null then
		_execute = false;
		_replace = false;
	end if;
	
	if not _print and not _execute then
		_replace = false;
	end if;

	if schamas_where_search is null then
		SELECT array_agg(quote_ident(s.schema_name)) into _schema_list
		FROM srvc.schema_to_refact as s
		where s.search_actived;
		
		_jb['schemasFromTable']=to_jsonb(true);
		
	else
		_schema_list = regexp_split_to_array(schamas_where_search,'\s*,\s*');
		
		raise notice '%', _schema_list;
		
		for _i in 1..array_length(_schema_list,1) loop
			_schema_list[_i]=quote_ident(_schema_list[_i]);		
		end loop;
		
	end if;
	
	_jb['schemas']=to_jsonb(_schema_list);

	for _rec in 
		with schema_list as(
			select * 
			from unnest(_schema_list) as x(sn)
		), schema_id as(
		  SELECT oid as s_oid, nspname			
			FROM pg_namespace as n
			inner join schema_list as s on nspname= s.sn
		)
		SELECT s.s_oid, p.oid as f_oid
		,s.nspname, p.proname, (s.nspname|| '.' || p.proname)::text as f_fullname
		, CASE p.prokind
			  WHEN 'f' THEN 'function'
			  WHEN 'a' THEN 'aggregate'
			  WHEN 'p' THEN 'procedure'
			  WHEN 'w' THEN 'function'  -- window function (rarely applicable)
			  -- ELSE NULL              -- not possible in pg 11
			END as f_type
		FROM schema_id as s
		inner join pg_proc as p on  p.pronamespace = s.s_oid
		where p.prokind<>'a' -- how to rigenerate aggregate function?
	loop
		_jb['workingOn']= to_jsonb(_rec.f_fullname);


		raise notice 'foid: %', _rec.f_oid;
		_funcDef = pg_get_functiondef(_rec.f_oid);
		
		_i=position ( text_to_search IN _funcDef );	
	
		if _i = 0 then
			--> non c'è nulla da fare				
			_notFound =array_append(_notFound,_rec.f_fullname);
			continue;
		end if;
				
		_funcArg=_rec.f_oid::regprocedure;
		_funcRet=pg_get_function_result(_rec.f_oid);			
			
		if	position ( text_to_search IN _funcArg ) >0 or
			position ( text_to_search IN _funcRet ) >0 then

			_funcDrop=format( E'drop %s IF EXISTS %s ;\n'
					, _rec.f_type
					, _rec.f_oid::regprocedure
					);
		else
			_funcDrop='';
		end if;
		
		
		if _replace then
			_funcDef = replace(_funcDef, text_to_search, text_to_replace);
		end if;
		
		if _print then
			raise notice E'\n%\n%;',_funcDrop,_funcDef;
		end if;
		
		if 	_execute then
		
				execute _funcDrop || _funcDef;

--				when invalid_function_definition then
		end if;

		_found =array_append(_found,_rec.f_fullname);

	
	end loop;
	
	
	_jb['notFound']=to_jsonb(_notFound);
	_jb['found']=to_jsonb(_found);
	_jb['foundCount']=to_jsonb(array_length(_found,1));
	_jb['status']=to_jsonb('OK'::text);
	
	return _jb - 'workingOn';
	
exception
	when others then
		declare
			v_state   TEXT;
			v_msg     TEXT;
			v_detail  TEXT;
			v_hint    TEXT;
			v_context TEXT;		
			_j	jsonb=$$
			{
				"state"  :  null
				,"message": null
				,"detail" : null
				,"hint"   : null
				,"context": null
			}$$::jsonb;
		begin

			get stacked diagnostics
				v_state   = returned_sqlstate,				
				v_msg     = message_text,
				v_detail  = pg_exception_detail,
				v_hint    = pg_exception_hint,
				v_context = pg_exception_context;
				
			_j['state']  =to_jsonb(v_state);
			_j['message']=to_jsonb(v_msg);
			_j['detail'] =to_jsonb(v_detail);
			_j['hint']   =to_jsonb(v_hint);
			_j['context']=to_jsonb(v_context);
			
			_jb['error']=_j;
			
		end;
		return _jb;
	

end;
$_$;


--
-- Name: search_func_ddl(text, text, text); Type: FUNCTION; Schema: srvc; Owner: -
--

CREATE FUNCTION srvc.search_func_ddl(p_current_schema text, p_func_er text DEFAULT '.+'::text, p_target_schema text DEFAULT NULL::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    BEGIN ATOMIC
 WITH config AS (
          SELECT search_func_ddl.p_func_er AS function_name_er,
             search_func_ddl.p_current_schema AS "current_schema",
             search_func_ddl.p_target_schema AS target_schema
         ), function_list AS (
          SELECT n.nspname AS "current_schema",
             p.proname AS function_name,
             p.oid AS function_oid,
             pg_get_function_identity_arguments(p.oid) AS function_args,
             pg_get_functiondef(p.oid) AS function_def,
             obj_description(p.oid, 'pg_proc'::name) AS function_comment,
             COALESCE(c.target_schema, (n.nspname)::text) AS target_schema
            FROM ((config c
              JOIN pg_namespace n ON ((n.nspname = c."current_schema")))
              JOIN pg_proc p ON (((p.pronamespace = n.oid) AND (p.proname ~ c.function_name_er))))
         )
  SELECT string_agg(((((((((((((((((((((((((((((((('-- Function: '::text || (fl."current_schema")::text) || '.'::text) || (fl.function_name)::text) || '
'::text) || '-- Target Schema: '::text) || fl.target_schema) || '
'::text) || '-- Backup: '::text) || CURRENT_TIMESTAMP) || '
'::text) || '-- '::text) || repeat('-'::text, 50)) || '
'::text) || '-- To remove function uncomment when ready:'::text) || '
'::text) || 'DROP FUNCTION IF EXISTS '::text) || (fl."current_schema")::text) || '.'::text) || (fl.function_name)::text) || '('::text) || fl.function_args) || ');'::text) || '

'::text) || '-- Function definition for new schema:'::text) || '
'::text) || replace(fl.function_def, (('CREATE OR REPLACE FUNCTION '::text || (fl."current_schema")::text) || '.'::text), (('CREATE OR REPLACE FUNCTION '::text || fl.target_schema) || '.'::text))) || ';

'::text) ||
         CASE
             WHEN (fl.function_comment IS NOT NULL) THEN ((((((((((('-- Function comment for new schema:'::text || '
'::text) || 'COMMENT ON FUNCTION '::text) || fl.target_schema) || '.'::text) || (fl.function_name)::text) || '('::text) || fl.function_args) || ') IS '::text) || quote_literal(fl.function_comment)) || ';'::text) || '

'::text)
             ELSE ''::text
         END) || '-- '::text) || repeat('-'::text, 50)) || '

'::text), ''::text ORDER BY fl.function_name) AS complete_backup
    FROM function_list fl;
END;


SET default_table_access_method = heap;

--
-- Name: schema_to_refact; Type: TABLE; Schema: srvc; Owner: -
--

CREATE TABLE srvc.schema_to_refact (
    schema_name text NOT NULL,
    search_actived boolean DEFAULT true NOT NULL
);


--
-- Name: mismatched_call; Type: VIEW; Schema: srvc; Owner: -
--

CREATE VIEW srvc.mismatched_call AS
 WITH search_func AS (
         SELECT r.routine_schema,
            r.routine_name,
            regexp_matches((r.routine_definition)::text, '((my_catalog|common|my_feat)\.([a-zA-Z0-9_]+))(?:\s*\()'::text, 'g'::text) AS mtch
           FROM (srvc.schema_to_refact s_1
             JOIN information_schema.routines r ON (((r.specific_schema)::name = s_1.schema_name)))
        )
 SELECT s.routine_schema,
    s.routine_name,
    s.mtch[2] AS call_schema,
    s.mtch[3] AS call_func,
    s.mtch[1] AS called_instruction
   FROM (search_func s
     LEFT JOIN information_schema.routines a ON ((((a.routine_schema)::name = s.mtch[2]) AND ((a.routine_name)::name = s.mtch[3]))))
  WHERE (a.routine_name IS NULL);


--
-- Name: schema_to_refact schema_to_refact_pk; Type: CONSTRAINT; Schema: srvc; Owner: -
--

ALTER TABLE ONLY srvc.schema_to_refact
    ADD CONSTRAINT schema_to_refact_pk PRIMARY KEY (schema_name);


--
-- PostgreSQL database dump complete
--

