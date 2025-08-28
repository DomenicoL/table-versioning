-- Disable check on function's body
SET check_function_bodies = off;

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
-- Name: vrsn; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vrsn;


--
-- Name: bitemporal_record; Type: TYPE; Schema: vrsn; Owner: -
--

CREATE TYPE vrsn.bitemporal_record AS (
	user_ts_range tstzrange,
	db_ts_range tstzrange,
	audit_record jsonb
);


--
-- Name: TYPE bitemporal_record; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON TYPE vrsn.bitemporal_record IS 'type to manage bitemporal information and audit record';


--
-- Name: boolean_true_domain; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.boolean_true_domain AS boolean NOT NULL DEFAULT true;


--
-- Name: bt_audit_record; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.bt_audit_record AS jsonb NOT NULL;


--
-- Name: bt_db_ts_range; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.bt_db_ts_range AS tstzrange NOT NULL;


--
-- Name: bt_user_ts_range; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.bt_user_ts_range AS tstzrange NOT NULL;


--
-- Name: cached_attribute; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.cached_attribute AS jsonb;


--
-- Name: entity_fullname_type; Type: TYPE; Schema: vrsn; Owner: -
--

CREATE TYPE vrsn.entity_fullname_type AS (
	schema_name text,
	table_name text
);


--
-- Name: __entity_fullname_type__validate(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__validate(st vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT (((st).schema_name ~ '^[a-zA-Z_][a-zA-Z0-9_]*$'::text) AND ((st).table_name ~ '^[a-zA-Z_][a-zA-Z0-9_]*$'::text));
END;


--
-- Name: entity_fullname_dmn; Type: DOMAIN; Schema: vrsn; Owner: -
--

CREATE DOMAIN vrsn.entity_fullname_dmn AS vrsn.entity_fullname_type
	CONSTRAINT entity_fullname_dmn_check CHECK (vrsn.__entity_fullname_type__validate(VALUE));


--
-- Name: historice_entity_behaviour; Type: TYPE; Schema: vrsn; Owner: -
--

CREATE TYPE vrsn.historice_entity_behaviour AS ENUM (
    'always',
    'never',
    'on_main_fields'
);


--
-- Name: TYPE historice_entity_behaviour; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON TYPE vrsn.historice_entity_behaviour IS 'define the behaviour';


--
-- Name: table_field_details; Type: TYPE; Schema: vrsn; Owner: -
--

CREATE TYPE vrsn.table_field_details AS (
	field_name text,
	data_type text,
	default_value text,
	is_nullable boolean,
	is_pk boolean,
	pk_order integer,
	table_order integer,
	generation_type text,
	complete_definition text
);


--
-- Name: tar_state_variables; Type: TYPE; Schema: vrsn; Owner: -
--

CREATE TYPE vrsn.tar_state_variables AS (
	mitigate_conflicts boolean,
	ignore_unchanged_values boolean,
	versioning_active boolean,
	allow_full_deactivation_by_past_close_ts boolean,
	action_close boolean,
	action_new boolean,
	action_mod boolean,
	deactivate_all boolean,
	found_changed_value boolean,
	past_time boolean,
	near_past_time boolean,
	on_dup_key_update boolean,
	on_dup_key_exit boolean,
	ignore_null_on_update boolean,
	lock_main_table boolean,
	enable_version_only_on_main_change boolean,
	enable_history_attributes boolean,
	enable_attribute_to_fields_replacement boolean,
	is_ready boolean,
	trace_call_stack boolean,
	tar_changelog boolean
);


--
-- Name: __entity_fullname_type__to_hstore(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__to_hstore(st vrsn.entity_fullname_type) RETURNS extensions.hstore
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::hstore
        ELSE hstore(ARRAY['schema_name', 'table_name'], 
                   ARRAY[COALESCE(st.schema_name, 'public'), COALESCE(st.table_name, '')])
    END;
$$;


--
-- Name: __entity_fullname_type__to_json(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__to_json(st vrsn.entity_fullname_type) RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::json
        ELSE json_build_object(
            'schema_name', COALESCE(st.schema_name, 'public'),
            'table_name', COALESCE(st.table_name, '')
        )
    END;
$$;


--
-- Name: __entity_fullname_type__to_jsonb(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__to_jsonb(st vrsn.entity_fullname_type) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::jsonb
        ELSE jsonb_build_object(
            'schema_name', COALESCE(st.schema_name, 'public'),
            'table_name', COALESCE(st.table_name, '')
        )
    END;
$$;


--
-- Name: __entity_fullname_type__to_string(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__to_string(st vrsn.entity_fullname_type) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN st IS NULL THEN NULL
        WHEN st.schema_name IS NULL AND st.table_name IS NULL THEN NULL
        ELSE COALESCE(st.schema_name, 'public') || '.' || COALESCE(st.table_name, '')
    END;
$$;


--
-- Name: __entity_fullname_type__from_hstore(extensions.hstore); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__from_hstore(hs extensions.hstore) RETURNS vrsn.entity_fullname_type
    LANGUAGE plpgsql
    AS $$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF hs IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(hs->'schema_name', hs->'schema', 'public');
    result.table_name := COALESCE(hs->'table_name', hs->'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in hstore';
    END IF;
    
    RETURN result;
END;
$$;


--
-- Name: __entity_fullname_type__from_json(json); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__from_json(js json) RETURNS vrsn.entity_fullname_type
    LANGUAGE plpgsql
    AS $$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF js IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(js->>'schema_name', js->>'schema', 'public');
    result.table_name := COALESCE(js->>'table_name', js->>'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in JSON';
    END IF;
    
    RETURN result;
END;
$$;


--
-- Name: __entity_fullname_type__from_jsonb(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__from_jsonb(js jsonb) RETURNS vrsn.entity_fullname_type
    LANGUAGE plpgsql
    AS $$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF js IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(js->>'schema_name', js->>'schema', 'public');
    result.table_name := COALESCE(js->>'table_name', js->>'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in JSONB';
    END IF;
    
    RETURN result;
END;
$$;


--
-- Name: __entity_fullname_type__from_string(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__from_string(input_string text) RETURNS vrsn.entity_fullname_type
    LANGUAGE plpgsql
    AS $$
DECLARE
    result vrsn.entity_fullname_type;
    parts text[];
BEGIN
    IF input_string IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Dividi la stringa per il punto
    parts := string_to_array(input_string, '.');
    
    IF array_length(parts, 1) = 2 THEN
        result.schema_name := parts[1];
        result.table_name := parts[2];
    ELSIF array_length(parts, 1) = 1 THEN
        -- Se non c'è schema, assume 'public'
        result.schema_name := 'public';
        result.table_name := parts[1];
    ELSE
        RAISE EXCEPTION 'Invalid schema.table format: %', input_string;
    END IF;
    
    RETURN result;
END;
$$;


--
-- Name: __bitemporal_entity__build_ddl(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__build_ddl(p_conf jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN p_conf jsonb)
    RETURNS text
*/
	v_sqlStr text;

	v_conf	jsonb;

	v_key		text;
	v_jb		jsonb;
	v_i			integer;

	v_valid		boolean;
	v_errors	text[];
begin

	--------------------------------------------------------------------
    -- Fase 0: Verifico input
    -- 
	select is_valid, errors into v_valid, v_errors 
	from common.jsonb_schema__validate (	p_conf
			,	vrsn.parameters__get('bitemporal_entity','json_schema')
		) 
	;
	
	if not v_valid then
		raise exception e'Json not valid:\n%', v_errors;
    end if;


	--------------------------------------------------------------------
    --	Recupera parametro vuoto
	v_conf=vrsn.parameters__get('bitemporal_entity','inner_conf');


	--------------------------------------------------------------------
    -- Fase 1: Applica p_conf a v_conf usando common.jsonb_recursive_left_merge.
    -- Questo riempie la struttura di default di v_conf con i valori non-null forniti in p_conf.
    v_conf := common.jsonb_recursive_left_merge(v_conf, p_conf, true);

	--------------------------------------------------------------------
    -- Completa i parametri
	v_conf=vrsn.__bitemporal_entity__complete_conf_param(v_conf);

	--------------------------------------------------------------------
    -- Recupero la strutura dei campi

	v_conf['structure']=vrsn.jsonb_table_structure__build(
		(v_conf->'current_table'->>'table_name')
	,	(v_conf->'current_table'->>'schema_name')
	);

	--------------------------------------------------------------------
    -- Verifico se eredita dalla tabella bitemporale

	SELECT count(*) into v_i	
	from vrsn.__get_table_inheritance_ancestors(
			(v_conf->'current_table'->>'schema_name')
		,	(v_conf->'current_table'->>'table_name')
		) 
	WHERE	ancestor_schema='vrsn'
		and ancestor_table='bitemporal_parent_table'
	;

	if v_i>0 then
		v_conf['version']=to_jsonb(2::int);
	else
		v_conf['version']=to_jsonb(1::int);
	end if;
	

	--------------------------------------------------------------------
    -- Recupero la strutura

	for v_key, v_jb in 
		select key, value
		from jsonb_each(v_conf->'structure') 
	loop
		
		if (v_jb->>'pk')::boolean then
			
			v_conf['current_pk'][ (v_jb->>'pk_order')::int -1] = to_jsonb(v_key);
		end if;

		case v_jb->>'type'
			when 'vrsn.bitemporal_record' then
				v_conf['bt_info_name']= to_jsonb(v_key);
				v_conf['history_pk'][0]=to_jsonb(v_key);
				v_conf['bitemporal_fields']=v_conf->'bitemporal_fields' || to_jsonb(v_key);
			when 'vrsn.bt_user_ts_range' then
				if v_key='user_ts_range' then
					v_conf['history_pk'][0]=to_jsonb(v_key);
					v_conf['bitemporal_fields']=v_conf->'bitemporal_fields' || to_jsonb(v_key);
				end if;
			when 'vrsn.bt_db_ts_range' then
				if v_key='db_ts_range' then
					v_conf['history_pk'][1]=to_jsonb(v_key);
					v_conf['bitemporal_fields']=v_conf->'bitemporal_fields' || to_jsonb(v_key);
				end if;
			when 'vrsn.bt_audit_record' then
				if v_key='_audit_record' then					
					v_conf['bitemporal_fields']=v_conf->'bitemporal_fields' || to_jsonb(v_key);
				end if;
			else
				null;
		end case;

	end loop;

	v_conf['history_pk']=v_conf['current_pk'] || v_conf['history_pk'];



--raise notice e'\n%', jsonb_pretty(v_conf);

	v_sqlStr= vrsn.__bitemporal_entity__get_ddl_complete(v_conf);


	--------------------------------------------------------------------
	--	Manage attribute handling
	if v_conf->>'historice_entity' <> 'never' and (v_conf->>'enable_history_attributes')::boolean then
	
		v_sqlStr=v_sqlStr
			|| vrsn.__bitemporal_entity__get_ddl_complete_attribute(v_conf);

			
	end if;
	


	return v_sqlStr;

end;
$$;


--
-- Name: __bitemporal_entity__complete_conf_param(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__complete_conf_param(p_conf jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN p_conf jsonb
    RETURNS jsonb
*/

begin
--raise notice '1 %',jsonb_pretty(p_conf);
	--------------------------------------------------------------------
    -- Recupera lo schema se assente
	p_conf['current_table']['schema_name'] = to_jsonb(coalesce ( 
		(p_conf->'current_table'->>'schema_name')
		,(p_conf->'entity'->>'schema_name')
		,(p_conf->'current_view'->>'schema_name')
	));

	p_conf['current_view']['schema_name'] = to_jsonb(coalesce ( 
		(p_conf->'current_view'->>'schema_name')
		,(p_conf->'entity'->>'schema_name')
		,(p_conf->'current_table'->>'schema_name')
	));

	p_conf['entity']['schema_name'] = to_jsonb(coalesce ( 
		(p_conf->'entity'->>'schema_name')
		,(p_conf->'current_table'->>'schema_name')
	));

	p_conf['history_table']['schema_name'] = to_jsonb(coalesce ( 
		(p_conf->'history_table'->>'schema_name')
		,(p_conf->'current_table'->>'schema_name')
	));

	p_conf['attribute_entity']['schema_name'] = to_jsonb(coalesce ( 
		(p_conf->'attribute_entity'->>'schema_name')
		,(p_conf->'current_table'->>'schema_name')
	));

	--------------------------------------------------------------------
    -- Recupera il nome della tabella
--raise notice '2%',jsonb_pretty(p_conf);
	p_conf['current_table']['table_name'] = to_jsonb(coalesce ( 
		(p_conf->'current_table'->>'table_name')
	,	vrsn.__bitemporal_entity__get_current_table_name(
			(p_conf->'current_view'->>'table_name')
		)
	,	(p_conf->'entity'->>'table_name') || '_current'
	));

	p_conf['entity']['table_name'] = to_jsonb(coalesce ( 
		(p_conf->'entity'->>'table_name')
	,	vrsn.__bitemporal_entity__get_entity_name (
			(p_conf->'current_table'->>'table_name')
		)
	));

	p_conf['current_view']['table_name'] = to_jsonb(coalesce ( 
		(p_conf->'current_view'->>'table_name')
	,	vrsn.__bitemporal_entity__get_view_name (
			(p_conf->'current_table'->>'table_name')
		)
	));

	p_conf['history_table']['table_name'] = to_jsonb(coalesce ( 
		(p_conf->'history_table'->>'table_name')
	,	vrsn.__bitemporal_entity__get_history_table_name(
			(p_conf->'current_table'->>'table_name')
		)
	));

	p_conf['attribute_entity']['table_name'] = to_jsonb(coalesce ( 
		(p_conf->'attribute_entity'->>'table_name')
	,	vrsn.__bitemporal_entity__get_attribute_entity_name(
			(p_conf->'current_table'->>'table_name')
		)
	));

--raise notice '3%',jsonb_pretty(p_conf);
	--------------------------------------------------------------------
    -- Controlli di coerenza

	if ((p_conf->'current_view'->>'schema_name') is null
		or (p_conf->'current_view'->>'table_name') is null)
	then
	
        raise exception 'Missing information: You must provide at least "current_view.table_name" or "current_table.table_name".';
		
	elsif (p_conf->'current_view'->>'schema_name') = (p_conf->'current_table'->>'schema_name')
		and (p_conf->'current_view'->>'table_name') = (p_conf->'current_table'->>'table_name')
	then

		raise exception e'View and Table must be distinguishable.\n%',jsonb_pretty(p_conf);
	
	end if;

	if not (p_conf->>'enable_history_attributes')::boolean then
		p_conf['attribute_entity']['schema_name']=to_jsonb(null::text);
		p_conf['attribute_entity']['table_name']=to_jsonb(null::text);
	end if;


	return p_conf;

end;
$$;


--
-- Name: FUNCTION __bitemporal_entity__complete_conf_param(p_conf jsonb); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__complete_conf_param(p_conf jsonb) IS 'Complete missing value of conf parameter';


--
-- Name: __bitemporal_entity__get_attribute_entity_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_attribute_entity_name(object_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT regexp_replace(object_name, '(\_current|\_history|\_view|\_entity)?$'::text, '_attribute'::text) AS entity_name;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_attribute_entity_name(object_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_attribute_entity_name(object_name text) IS 'return name for the attribute entity starting from a bitemporal table or view';


--
-- Name: __bitemporal_entity__get_attribute_table_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_attribute_table_name(table_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT replace(table_name, '_current'::text, '_attribute_current'::text) AS tname;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_attribute_table_name(table_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_attribute_table_name(table_name text) IS 'return name for the attribute table';


--
-- Name: __bitemporal_entity__get_current_table_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_current_table_name(object_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT regexp_replace(object_name, '(\_current|\_history|\_view|\_entity)?$'::text, '_current'::text) AS entity_name;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_current_table_name(object_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_current_table_name(object_name text) IS 'return name for the current table starting from a bitemporal table or view';


--
-- Name: __bitemporal_entity__get_ddl_attribute_table(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_attribute_table(p_conf jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
/*
	IN p_conf jsonb)
    RETURNS text
*/

    v_pk_fields    			text;
	v_fields_definition		text;
    v_ddl         			text;

	v_sql_v1	constant	text=$$
		create table if not exists %1$I.%2$I (
            ::bt_info::        vrsn.bitemporal_record NOT NULL
         ,	%3$s
            constraint %2$I_pk primary key(%4$s)
        );
	$$;
	v_sql_v2	constant	text=$$
		create table if not exists %1$I.%2$I (            
            %3$s
            constraint %2$I_pk primary key(%4$s)
        )	INHERITS (vrsn.bitemporal_parent_table) ;
	$$;


BEGIN
	---------------------------------------------------------------------
	--	compute fields definiton
	--	and pk composition
	with fields_list as (
		select field_name, pk_order, table_order, complete_definition
		from vrsn.table__get_fields_details( 
				(p_conf->'parent_table'->>'schema_name')
			,	(p_conf->'parent_table'->>'table_name')
		)
		where is_pk
		union all
		select field_name, pk_order+100, table_order+100, complete_definition
		from vrsn.table__get_fields_details('vrsn'
				, 'bitemporal_parent_attribute_table')
	), pk_fields as (
		select string_agg( field_name 
					, ', ' order by pk_order
				) as pk_text		
		from fields_list
		where pk_order is not null
	), fields_def as  (
		select string_agg(	complete_definition	
					, e'\n\t\t,\t'	order by table_order
				) as fields_definition		
		from fields_list
	)
	select a.pk_text, b.fields_definition
	INTO v_pk_fields, v_fields_definition
	from pk_fields a, fields_def b;

raise notice '%', v_fields_definition;
	---------------------------------------------------------------------
	--	Determine the type of table creazione
	if (p_conf->>'version')::integer= 2 then
		v_ddl= v_sql_v2;
	else 
		v_ddl=replace(v_sql_v1, '::bt_info::', (p_conf->>'bt_info_name') );
	end if;
	
	---------------------------------------------------------------------
	--	substitute parameters
    v_ddl =e'\n\n'||format(v_ddl
		,	(p_conf->'current_table'->>'schema_name')
		,	(p_conf->'current_table'->>'table_name')
		,	v_fields_definition
		,	v_pk_fields
    );

    RETURN v_ddl;
END;
$_$;


--
-- Name: __bitemporal_entity__get_ddl_complete(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_complete(p_conf jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
	
	v_sqlStr text;

	t_username	 text;

begin
	--------------------------------------------------------------------
	--	get/set user name text
	t_username =coalesce(
			vrsn.parameters__get_value('tar', 'params.t_username') #>>'{}'
		,	'modify_user_id'
	);


	--------------------------------------------------------------------
	--	get Idex for historical search
	--	for current  table
	v_sqlStr = e'\n\n' ||
			vrsn.__bitemporal_entity__get_ddl_tsrange_idx(
			p_conf, 'current_table'
		);

	--------------------------------------------------------------------
	--	Get ddl for history table 
	v_sqlStr = v_sqlStr || e'\n\n' || vrsn.__bitemporal_entity__get_ddl_history_table(p_conf);

	--------------------------------------------------------------------
	--	get Idex for historical search
	--	for  history table
	v_sqlStr  = v_sqlStr ||e'\n\n' ||
			vrsn.__bitemporal_entity__get_ddl_tsrange_idx(
			p_conf, 'history_table'
		);

	--------------------------------------------------------------------
	--	Get ddl for history table 
	v_sqlStr = v_sqlStr || e'\n\n' || vrsn.__bitemporal_entity__get_ddl_view(p_conf);

--------------------------------------------------------------------
	--	Insert def entity behaviour record

	v_sqlStr = v_sqlStr || 
		format($$

		
		INSERT INTO vrsn.def_entity_behavior(
		 		entity_full_name.schema_name
			,	entity_full_name.table_name
		 	,	current_view_full_name.schema_name
			,	current_view_full_name.table_name
		 	,	current_table_full_name.schema_name
			,	current_table_full_name.table_name
		 	,	history_table_full_name.schema_name
			,	history_table_full_name.table_name
		 	,	attribute_entity_full_name.schema_name
			,	attribute_entity_full_name.table_name

		 	,	historice_entity, enable_history_attributes
			,	main_fields_list, cached_fields_list
			,	enable_attribute_to_fields_replacement, %16$I
			,	action_hints)
		VALUES(	%1$s, %2$s
			,	%3$s, %4$s
			,	%5$s, %6$s
			,	%7$s, %8$s
			,	%9$s, %10$s
			,	%11$s, %12$s
			,	%13$s, %14$s
			,	%15$s, 'process:vrsn.register'
			,	'{"onDupKey":"update"}'::jsonb);$$
		,	quote_nullable((p_conf->'entity'->>'schema_name'))
		,	quote_nullable((p_conf->'entity'->>'table_name'))
		,	quote_nullable((p_conf->'current_view'->>'schema_name'))
		,	quote_nullable((p_conf->'current_view'->>'table_name'))
		,	quote_nullable((p_conf->'current_table'->>'schema_name'))
		,	quote_nullable((p_conf->'current_table'->>'table_name'))
		,	quote_nullable((p_conf->'history_table'->>'schema_name'))
		,	quote_nullable((p_conf->'history_table'->>'table_name'))
		,	quote_nullable((p_conf->'attribute_entity'->>'schema_name'))
		,	quote_nullable((p_conf->'attribute_entity'->>'table_name'))
		,	quote_nullable(p_conf->>'historice_entity')
		,	p_conf->>'enable_history_attributes'
		,	quote_nullable(p_conf->>'main_fields_list')
		,	quote_nullable(p_conf->>'cached_fields_list')
		,	p_conf->>'enable_attribute_to_fields_replacement'
		,	t_username
		);
	
	return v_sqlStr;

end;
$_$;


--
-- Name: __bitemporal_entity__get_ddl_complete_attribute(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_complete_attribute(p_conf jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
	
	v_sqlStr text;	
	v_conf	jsonb;

	v_key		text;
	v_jb		jsonb;
	v_i			integer;

begin

	--------------------------------------------------------------------
    --	Recupera parametro vuoto
	v_conf=vrsn.parameters__get('bitemporal_entity','inner_conf');

	--------------------------------------------------------------------
	-- Fase 1: Riempie v_conf con i parametri opportuni di p_cong
	-- Questo riempie la struttura di default di v_conf con i valori non-null forniti in p_conf.
	v_conf := common.jsonb_recursive_left_merge(v_conf
		,	format(
				$${
					"entity": {
						"table_name": "%2$I",
						"schema_name": "%1$I"
					},
					"historice_entity": "always",
					"enable_history_attributes": false,
					"enable_attribute_to_fields_replacement": false,
					"bt_info_name":"%3$I"
				}$$
			,	(p_conf->'attribute_entity'->>'schema_name')
			,	(p_conf->'attribute_entity'->>'table_name')
			,	(p_conf->>'bt_info_name')
			
			)::jsonb
		,	true);

	v_conf['version']=p_conf->'version';
	v_conf['bitemporal_fields']=p_conf->'bitemporal_fields';
--raise notice e'\n%', jsonb_pretty(v_conf);	
	--------------------------------------------------------------------
	-- Completa i parametri
	v_conf=vrsn.__bitemporal_entity__complete_conf_param(v_conf);

	--------------------------------------------------------------------
	-- Add special reference to parent curren table
	v_conf['parent_table']=p_conf->'current_table';
	
	--------------------------------------------------------------------
    -- Recupero la strutura dalla tabella padre (bt_fields e pk)
	-- più i campi specifici per gli attributi
	-- 

	with fields_list as (
		select field_name,	data_type,	default_value,	is_nullable,
		is_pk ,	pk_order ,	table_order, generation_type,
		complete_definition
		from vrsn.table__get_fields_details(
				(p_conf->'current_table'->>'schema_name')
			,	(p_conf->'current_table'->>'table_name')
		)
		where is_pk
		or (v_conf['bitemporal_fields']) ? field_name
		union all
		select field_name,	data_type,	default_value,	is_nullable,
		is_pk ,	pk_order +100,	table_order +100,	generation_type,
		complete_definition
		from vrsn.table__get_fields_details('vrsn'
				, 'bitemporal_parent_attribute_table')
	), pk_list as (
		select jsonb_agg( field_name
				 order by pk_order
			) as pk_jb_list
		from fields_list
		where is_pk
	), jts as (
		select vrsn.table_field_details_to_jts_agg(t) as jb_struct
		from fields_list as t
	)
	select  v_conf ||
		jsonb_build_object(
	    'current_pk', pk_list.pk_jb_list,
	    'structure', jts.jb_struct)
	into v_conf	
	from pk_list, jts;
	
	-------------------------------------------------------------------------------
	-- Sottrae current_pk da history_pk e accoda a v_conf->current_pk
	v_conf['history_pk']=
		(v_conf->'current_pk') || 
		(
			select coalesce(jsonb_agg(value), '[]'::jsonb)
			from jsonb_array_elements_text(p_conf->'history_pk') as value
			where not ((p_conf->'current_pk') ? value)
		)
	;

	

raise notice e'\n%', jsonb_pretty(v_conf);

	v_sqlStr=vrsn.__bitemporal_entity__get_ddl_attribute_table(v_conf);

	return v_sqlStr 
		|| vrsn.__bitemporal_entity__get_ddl_complete(v_conf);
end;
$_$;


--
-- Name: __bitemporal_entity__get_ddl_history_table(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_history_table(p_conf jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT format('
		CREATE TABLE if not exists %1$I.%2$I (
    		CONSTRAINT %2$I_pk primary key (%5$s)
		) INHERITS (%3$I.%4$I);'::text, ((p_conf -> 'history_table'::text) ->> 'schema_name'::text), ((p_conf -> 'history_table'::text) ->> 'table_name'::text), ((p_conf -> 'current_table'::text) ->> 'schema_name'::text), ((p_conf -> 'current_table'::text) ->> 'table_name'::text), common.jsonb_array_to_string((p_conf -> 'history_pk'::text))) AS ddl_text;
END;


--
-- Name: __bitemporal_entity__get_ddl_tsrange_idx(jsonb, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_tsrange_idx(p_conf jsonb, p_entity text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
/*
	IN	p_conf jsonb
	IN	p_entity	text default null
    RETURNS text
*/

    v_sql		text;	
BEGIN
	if p_entity is null then
		if p_conf->>'working_on' is not null then
			p_entity=p_conf->>'working_on';
		else
			raise exception 'No working entity';
		end if;
	end if;
		

	case (p_conf->>'version')::int
	when 1 then
	    v_sql := e'\n-- indice gist composto (user_ts_range, db_ts_range)\n\n'
			|| 'create index if not exists ' 
			|| (p_conf->p_entity->>'table_name') 
			|| '_user_db_tsr_ix on ' 
			|| (p_conf->p_entity->>'schema_name') || '.' || (p_conf->p_entity->>'table_name') 
			|| ' using gist (((' || (p_conf->>'bt_info_name') 
			|| ').user_ts_range), ((' || (p_conf->>'bt_info_name') 
			|| e').db_ts_range));\n\n-- indice gist solo su db_ts_range\n\n'	
			|| 'create index if not exists ' || (p_conf->p_entity->>'table_name') 
			|| '_db_tsr_ix on ' 
			|| (p_conf->p_entity->>'schema_name') || '.' || (p_conf->p_entity->>'table_name') 
			|| ' using gist (((' || (p_conf->>'bt_info_name') || e').db_ts_range));\n\n';
	when 2 then
		    v_sql := e'\n-- indice gist composto (user_ts_range, db_ts_range)\n\n'
			|| 'create index if not exists ' 
			|| (p_conf->p_entity->>'table_name') 
			|| '_user_db_tsr_ix on ' 
			|| (p_conf->p_entity->>'schema_name') || '.' || (p_conf->p_entity->>'table_name') 
			|| e' using gist (user_ts_range, db_ts_range);\n\n'
			|| e'-- indice gist solo su db_ts_range\n\n'	
			|| 'create index if not exists ' || (p_conf->p_entity->>'table_name') 
			|| '_db_tsr_ix on ' 
			|| (p_conf->p_entity->>'schema_name') || '.' || (p_conf->p_entity->>'table_name') 
			|| e' using gist (db_ts_range);\n\n';

	else
		raise exception 'Version not recognized.';
	end case;
	
    RETURN v_sql;

	-- Valutazione per le chiavi primarie
    -- Non è strettamente necessario aggiungere qui le chiavi primarie,
    -- in quanto sono già indicizzate automaticamente.
    -- Tuttavia, se ci fossero chiavi secondarie o altre colonne
    -- che beneficiano di indici B-tree (es. ID numerici per JOIN),
    -- si potrebbero aggiungere istruzioni simili.
    -- Per questo specifico caso, ci concentriamo sui tstzrange.
	
END;
$$;


--
-- Name: __bitemporal_entity__get_ddl_view(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_view(p_conf jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	IN p_conf jsonb
	RETURNS text
*/
	v_ret text='';
	c_ddl_text	constant	text=$$
--drop view %1$I.%2$I;

create or replace view %1$I.%2$I as
select s.%5$s
	,	false::boolean AS is_closed
	,	NULL::text AS modify_user_id
	,	NULL::timestamp with time zone AS modify_ts
	,	NULL::jsonb AS action_hints
from only %3$I.%4$I as s;
				
create or replace trigger %6$I
    instead of insert or delete or update 
    on %1$I.%2$I
    for each row
    execute function vrsn.trigger_handler();$$;

	
begin	
	----------------------------------------------------------------------
	-- Genero l'elenco campi
	select string_agg(
		entry.key, 
		e'\n\t,\ts.' 
		order by coalesce((entry.value->>'field_order')::integer, 999999)
	) into v_ret
	from jsonb_each(p_conf->'structure') as entry(key, value)
	where not (p_conf->'bitemporal_fields' ? entry.key);
	

	----------------------------------------------------------------------
	-- Genero DDL
	v_ret=format(c_ddl_text
	,	(p_conf->'current_view'->>'schema_name')
	,	(p_conf->'current_view'->>'table_name')
	,	(p_conf->'current_table'->>'schema_name')
	,	(p_conf->'current_table'->>'table_name')
	,	v_ret
	,	'trg_'|| (p_conf->'current_view'->>'table_name')
	);
	
	
	return v_ret;
end;
$_$;


--
-- Name: FUNCTION __bitemporal_entity__get_ddl_view(p_conf jsonb); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_ddl_view(p_conf jsonb) IS 'Get the standard defintion of view ready for manage bitemporal storage.';


--
-- Name: __bitemporal_entity__get_ddl_view(text, text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_ddl_view(table_schema text, table_name text, full_view_name text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
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
		
		_view_name = vrsn.__bitemporal_entity__get_view_name(_table_name);	

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
end;
$_$;


--
-- Name: FUNCTION __bitemporal_entity__get_ddl_view(table_schema text, table_name text, full_view_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_ddl_view(table_schema text, table_name text, full_view_name text) IS 'Get the standard defintion of view ready for manage bitemporal storage.';


--
-- Name: __bitemporal_entity__get_entity_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_entity_name(object_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT regexp_replace(object_name, '(\_current|\_history|\_view|\_entity)?$'::text, ''::text) AS entity_name;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_entity_name(object_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_entity_name(object_name text) IS 'return  name for the entity starting from a bitemporal table or view';


--
-- Name: __bitemporal_entity__get_history_table_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_history_table_name(object_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT regexp_replace(object_name, '(\_current|\_history|\_view|\_entity)?$'::text, '_history'::text) AS entity_name;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_history_table_name(object_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_history_table_name(object_name text) IS 'return name for the history table starting from a bitemporal table or view';


--
-- Name: __bitemporal_entity__get_view_name(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_view_name(object_name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT regexp_replace(object_name, '(\_current|\_history|\_view|\_entity)?$'::text, ''::text) AS entity_name;
END;


--
-- Name: FUNCTION __bitemporal_entity__get_view_name(object_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_view_name(object_name text) IS 'return name for the view starting from a bitemporal table or view';


--
-- Name: __bitemporal_entity__get_view_name_from_current_table(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__bitemporal_entity__get_view_name_from_current_table(table_name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare

	--	IN table_name text,
	--	RETURNS text
	_table_name alias for table_name;
	_view_name text;
	_i	integer;
begin
	_i= strpos ( _table_name, '_current' );
	
	if _i >0 then
		_view_name = substr ( _table_name, 1, _i -1  );
	else
		_view_name=_table_name||'_entity';		
	end if;
	return _view_name;
end;
$$;


--
-- Name: FUNCTION __bitemporal_entity__get_view_name_from_current_table(table_name text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.__bitemporal_entity__get_view_name_from_current_table(table_name text) IS 'return name for the view';


--
-- Name: __entity_fullname_type__array_agg_finalfn(vrsn.entity_fullname_type[]); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__array_agg_finalfn(state vrsn.entity_fullname_type[]) RETURNS vrsn.entity_fullname_type[]
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(state, ARRAY[]::vrsn.entity_fullname_type[]);
$$;


--
-- Name: __entity_fullname_type__array_agg_transfn(vrsn.entity_fullname_type[], vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__array_agg_transfn(state vrsn.entity_fullname_type[], elem vrsn.entity_fullname_type) RETURNS vrsn.entity_fullname_type[]
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN state IS NULL THEN ARRAY[elem]
        ELSE state || elem
    END;
$$;


--
-- Name: __entity_fullname_type__cmp(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__cmp(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN (COALESCE(a.schema_name, 'public') || '.' || COALESCE(a.table_name, '')) < 
             (COALESCE(b.schema_name, 'public') || '.' || COALESCE(b.table_name, '')) THEN -1
        WHEN (COALESCE(a.schema_name, 'public') || '.' || COALESCE(a.table_name, '')) > 
             (COALESCE(b.schema_name, 'public') || '.' || COALESCE(b.table_name, '')) THEN 1
        ELSE 0
    END;
$$;


--
-- Name: __entity_fullname_type__eq(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__eq(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(a.schema_name, 'public') = COALESCE(b.schema_name, 'public')
       AND COALESCE(a.table_name, '') = COALESCE(b.table_name, '');
$$;


--
-- Name: __entity_fullname_type__ge(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__ge(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) >= 0;
$$;


--
-- Name: __entity_fullname_type__gt(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__gt(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) > 0;
$$;


--
-- Name: __entity_fullname_type__hash(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__hash(st vrsn.entity_fullname_type) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT hashtext(COALESCE(st.schema_name, 'public') || '.' || COALESCE(st.table_name, ''));
$$;


--
-- Name: __entity_fullname_type__le(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__le(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) <= 0;
$$;


--
-- Name: __entity_fullname_type__lt(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__lt(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) < 0;
$$;


--
-- Name: __entity_fullname_type__ne(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__ne(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT NOT vrsn.__entity_fullname_type__eq(a, b);
$$;


--
-- Name: __entity_fullname_type__string_agg_transfn(text, vrsn.entity_fullname_type, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__string_agg_transfn(state text, elem vrsn.entity_fullname_type, delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE 
        WHEN state IS NULL OR state = '' THEN elem::text
        ELSE state || delimiter || elem::text
    END;
$$;


--
-- Name: __entity_fullname_type__test_extended(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__test_extended() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    myVar vrsn.entity_fullname_type;
    myVar2 vrsn.entity_fullname_type;
    hs hstore;
    js json;
    jsb jsonb;
    result_array vrsn.entity_fullname_type[];
    result_string text;
BEGIN
    -- Test cast da literal stringa (ora dovrebbe funzionare)
    myVar := 'inventory.products';
    RAISE NOTICE 'Da literal stringa: %', myVar;
    
    -- Test cast da hstore
    hs := 'schema_name=>sales, table_name=>orders';
    myVar := hs::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da hstore: %', myVar;
    
    -- Test cast verso hstore
    hs := myVar::hstore;
    RAISE NOTICE 'Verso hstore: %', hs;
    
    -- Test cast da json
    js := '{"schema_name": "logs", "table_name": "access_log"}';
    myVar := js::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da JSON: %', myVar;
    
    -- Test cast verso json
    js := myVar::json;
    RAISE NOTICE 'Verso JSON: %', js;
    
    -- Test cast da jsonb
    jsb := '{"schema": "public", "table": "users"}';
    myVar := jsb::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da JSONB: %', myVar;
    
    -- Test cast verso jsonb
    jsb := myVar::jsonb;
    RAISE NOTICE 'Verso JSONB: %', jsb;
    
    -- Test operatori di confronto
    myVar2 := 'public.users';
    RAISE NOTICE 'Confronto uguaglianza: % = % -> %', myVar, myVar2, myVar = myVar2;
    RAISE NOTICE 'Confronto ordinamento: % < % -> %', myVar, myVar2, myVar < myVar2;
    
    -- Test aggregazione (simulazione)
    result_array := ARRAY[myVar, myVar2];
    RAISE NOTICE 'Array aggregato: %', result_array;
    
    -- Test validazione
    RAISE NOTICE 'Validazione: %', vrsn.__entity_fullname_type__validate(myVar);
    
END;
$$;


--
-- Name: __entity_fullname_type__to_ident(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__entity_fullname_type__to_ident(st vrsn.entity_fullname_type) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    BEGIN ATOMIC
 SELECT ((quote_ident(COALESCE((st).schema_name, 'public'::text)) || '.'::text) || quote_ident(COALESCE((st).table_name, ''::text)));
END;


--
-- Name: __get_table_inheritance_ancestors(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__get_table_inheritance_ancestors(input_schema text, input_table text) RETURNS TABLE(ancestor_schema text, ancestor_table text, level integer)
    LANGUAGE sql
    AS $$
	with recursive inheritance_ancestors as (
		-- Caso base: la tabella di partenza
		select 
			n.nspname as current_schema,
			c.relname as current_table,
			c.oid as current_oid,
			0 as level
		from pg_class c
		join pg_namespace n on n.oid = c.relnamespace
		where n.nspname = input_schema
			and c.relname = input_table
		
		union all
		
		-- Caso ricorsivo: trova le tabelle padre (inhparent)
		select 
			pn.nspname,
			pc.relname,
			pc.oid,
			ia.level + 1
		from inheritance_ancestors ia
		join pg_inherits i on i.inhrelid = ia.current_oid
		join pg_class pc on pc.oid = i.inhparent
		join pg_namespace pn on pn.oid = pc.relnamespace
	)
	select 
		ia.current_schema::text,
		ia.current_table::text,
		ia.level
	from inheritance_ancestors ia
--	where ia.level > 0
	order by ia.level;
$$;


--
-- Name: __lock__get_advsory(text, text, boolean, boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__lock__get_advsory(p_table_full_name text, p_table_key text, is_shared boolean DEFAULT false, exception_on_fail boolean DEFAULT true) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$declare
/*
	IN p_table_full_name text, 
	IN p_table_key text, 
	IN is_shared boolean DEFAULT false
	IN exception_on_fail boolean DEFAULT true)
	
    RETURNS boolean
*/	
	lock_key 				bigint;
	advisory_xact_ok 		boolean = false;

begin
	--------------------------------------------------------------------
	--	Try to obtain an advisory lock (semaphore) for
	--	for p_table_full_name and p_table_key
	
	lock_key := abs(hashtext(format('%I:%I'
			, 	p_table_full_name
			,	p_table_key
	)));

	if is_shared then
		advisory_xact_ok=  pg_try_advisory_xact_lock_shared(lock_key);	
	else
    	advisory_xact_ok=  pg_try_advisory_xact_lock(lock_key);
	end if;

/*
	raise notice 'lock for: <%>, shared: % => [%]', format('%I:%I'
			, 	p_table_full_name
			,	p_table_key
	), is_shared, advisory_xact_ok ;

*/
	if not advisory_xact_ok and exception_on_fail then
		raise lock_not_available 
			using message=format('Advisory lock unavaiable for key %2$s in %1$s.'
				,	p_table_full_name
				,	p_table_key);
	end if;

	return advisory_xact_ok;
end;$_$;


--
-- Name: __table_field_details__to_jsonb_transfn(jsonb, vrsn.table_field_details); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__table_field_details__to_jsonb_transfn(state jsonb, field_data vrsn.table_field_details) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT state || jsonb_build_object(
        field_data.field_name,
        json_build_object(
            'type', field_data.data_type,
            'generated', field_data.generation_type,
            'pk', field_data.is_pk,
            'pk_order', field_data.pk_order,
            'default_value', field_data.default_value,
            'field_order', field_data.table_order
        )
    );
$$;


SET default_table_access_method = heap;

--
-- Name: trigger_activation_record_base; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.trigger_activation_record_base (
    last_update_ts timestamp with time zone DEFAULT now(),
    entity_full_name vrsn.entity_fullname_type NOT NULL,
    current_view_full_name vrsn.entity_fullname_type,
    current_table_full_name vrsn.entity_fullname_type,
    history_table_full_name vrsn.entity_fullname_type,
    attribute_entity_full_name vrsn.entity_fullname_type,
    current_entity_columns_list jsonb,
    history_entity_columns_list jsonb,
    unique_index_list jsonb,
    history_attributes_info jsonb,
    bt_info_name text DEFAULT 'bt_info'::text NOT NULL,
    func_state_var vrsn.tar_state_variables,
    func_param jsonb,
    actions extensions.hstore,
    table_old_rec extensions.hstore,
    table_new_rec extensions.hstore
)
WITH (autovacuum_enabled='true');


--
-- Name: __tar_h__add_changelog(vrsn.trigger_activation_record_base); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__add_changelog(tar vrsn.trigger_activation_record_base) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
--	in vrsn.trigger_activation_record_base
	
	tar_new			vrsn.trigger_activation_record_base_changelog;

	exclude_fields	text[]=array['active_row','last_update_ts'];
	need_update		boolean=true;
BEGIN

	--------------------------------------------------------------
	--	Seek for current record

	begin
		select t.*
			into strict tar_new
		from only vrsn.trigger_activation_record_base_changelog as t
		where t.entity_full_name = tar.entity_full_name
			and t.active_row=true;

		--> if records are equal NOTHING TO DO
		if (common.records_equal(tar, tar_new,exclude_fields ) )then
			return;
		end if;
	exception
		when NO_DATA_FOUND then
			need_update=false;
		WHEN TOO_MANY_ROWS THEN
			raise exception 'Data refers to many records for <%>'
			, tar.entity_full_name::text;		
	end;

	
	--------------------------------------------------------------
	--	Update eventually current record
	
	if need_update then
		update only vrsn.trigger_activation_record_base_changelog as t
			set active_row=null
		where t.entity_full_name = tar.entity_full_name
			and t.active_row=true;
	end if;


	--------------------------------------------------------------
	--	Add new record

	tar_new=tar;
	tar_new.active_row=true;

	insert into vrsn.trigger_activation_record_base_changelog 
	select tar_new.*;
	
	return;
END;
$$;


--
-- Name: __tar_h__bind_action(text, extensions.hstore); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__bind_action(sqlstr text, hrec extensions.hstore) RETURNS text
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$declare
	_sqlstr		text=sqlstr;
	_k			text;
--	_v			text;
--	_debug		text;
begin
	--_debug= '--Start' || _sqlstr;
	foreach _k in array akeys(hrec) loop

--		_debug =_debug || format($$
--		hstore: %s %s
--			sqlStr:$$, _k,  hrec[_k]);		
		_sqlstr=replace(_sqlstr, ':'||_k||':', quote_nullable(hrec[_k]));
--		_debug =_debug ||  _sqlstr;
	
	end loop;

--	raise notice 'final %',_debug;
	return _sqlstr;
end;$_$;


--
-- Name: trigger_activation_record_stack; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.trigger_activation_record_stack (
    bt_info vrsn.bitemporal_record,
    bt_info_old vrsn.bitemporal_record,
    bt_info_new vrsn.bitemporal_record,
    time_stamp_to_use timestamp with time zone,
    new_valid_ts timestamp with time zone,
    wrkn_new_rec extensions.hstore,
    wrkn_old_rec extensions.hstore,
    status jsonb DEFAULT '{}'::jsonb NOT NULL
)
INHERITS (vrsn.trigger_activation_record_base);


--
-- Name: __tar_h__build(vrsn.entity_fullname_type, boolean, anycompatiblearray); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__build(entity_full_name vrsn.entity_fullname_type, force_rebuild boolean, argv anycompatiblearray) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $_$
declare
/*	IN entity_full_name vrsn.entity_fullname_type,
	
	IN force_rebuild boolean,
	IN argv anycompatiblearray)
	RETURNS vrsn.trigger_activation_record_stack
*/	
	p_entity_full_name 	alias for entity_full_name;
	tar					vrsn.trigger_activation_record_base%rowtype;
	v_last_def_update 	timestamptz;
	v_tar_s				vrsn.trigger_activation_record_stack%rowtype;
	_hs					hstore;
	_argn				integer;
	v_dml_action		integer:=0; -- 0 no, 1 insert, 2 update, 3 skip
	i					integer=0;
	
	advisory_xact_ok	boolean=false;
	
begin


	--------------------------------------------------------------------
	--	Try to obtain an advisory lock (semaphore)
	--
	--	if cannot obtain means a change on def_entity_behavior
	--	is on going.
	--
	--	Hence generate tar without insert at end
	--
 	advisory_xact_ok = vrsn.__lock__get_advsory(
			'vrsn.def_entity_behavior'
		,	p_entity_full_name::text
		,	true
		,	false
	);


	if not advisory_xact_ok then

		raise notice 'shared lock not acquired';
		v_dml_action=3;

	else
		----------------------------------------------------------------------------
		--	search if there already is an activation_record for the view
		
		select t.* into v_tar_s
		from only vrsn.trigger_activation_record_base as t	
		where t.entity_full_name=p_entity_full_name;
	
	--	raise notice '%', v_tar_s;
		if not found then
			--if not, insert
			v_dml_action=1;
		elseif	force_rebuild 
			or	now() >  tar.last_update_ts + INTERVAL '1 week' * coalesce( (tar.func_param->>'tar_week_to_live')::integer,0) 
		then
			--> if yes, but is required a rebuild, or the copy is too old, update
			v_dml_action=2;
		else 
			
			return v_tar_s;
		end if;
	end if;

	----------------------------------------------------------------------------
	-- build new tar
	tar.bt_info_name='bt_info';
	tar.entity_full_name=p_entity_full_name;
	tar.current_view_full_name=tar.entity_full_name;
	tar.last_update_ts=clock_timestamp();


	----------------------------------------------------------------------------
	-- set standard parameter
	tar = vrsn.__tar_h__config_func_build(tar);
--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;

	----------------------------------------------------------------------------
	--> Enrich with information stored in definition table 
	tar= vrsn.__tar_h__get_def_behavior(tar);
--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;


	----------------------------------------------------------------------------
	--> if there are paramenters
	--> Define attibute or set form argv	
	
	_argn=array_length(argv, 1);	
	
	if not common.is_empty(_argn) then
		if pg_typeof(argv[0])='hstore' then
			--> set parameter caming from hstore
			tar= tar #=argv[0];
		elseif pg_typeof(argv[0])='jsonb' then
			--> set parameter caming from jsonb
			tar=json_populate_record(tar,argv[0]);
		end if;
	end if;
	
	----------------------------------------------------------------------------
	--> check if table and schema name are passed
	if tar.current_table_full_name is  null then
		--> la vista deve essere basata su una sola tabella
		--raise notice '<%>', tar.current_view_full_name::text;
		begin
			--
			select	row(u.table_schema,u.table_name)::vrsn.entity_fullname_type
				into strict	tar.current_table_full_name
			from information_schema.view_table_usage u
			join information_schema.views v 
				 on u.view_schema = v.table_schema
				 and u.view_name = v.table_name
			where	u.table_schema not in ('information_schema', 'pg_catalog')
				and	u.view_schema= (tar).current_view_full_name.schema_name
				and	u.view_name= (tar).current_view_full_name.table_name
			order by u.view_schema,
					 u.view_name;

			--raise notice '<%>', tar.current_table_full_name::text;
		exception
			when NO_DATA_FOUND then
				raise exception '<%> seems to isn''t a view',  (tar).current_view_full_name::text;
			WHEN TOO_MANY_ROWS THEN
				raise exception 'Impossible to activate versioning of view based on more than one table' ;
		end;
	end if;
	
	----------------------------------------------------------------------------
	-- set information of history table
	if tar.history_table_full_name is null then
	
		tar.history_table_full_name.schema_name = 
			(tar).current_table_full_name.schema_name;
		
		if (tar).current_table_full_name.table_name like '%current' then
			tar.history_table_full_name.table_name = 
				regexp_replace((tar).current_table_full_name.table_name , 'current$','history');
		else
			tar.history_table_full_name.table_name =
				(tar).current_table_full_name.table_name  || '_history';
		end if;
	end if;
	
	----------------------------------------------------------------------------
	--> Retrieve list of columns 
	
	-- for current table
	tar.current_entity_columns_list=vrsn.jsonb_table_structure__build ( tar.current_table_full_name);

	-- for history table
	tar.history_entity_columns_list=vrsn.jsonb_table_structure__build (tar.history_table_full_name );

	----------------------------------------------------------------------------
	--> Check for tables existance 

	if common.is_empty(tar.current_entity_columns_list) then
		raise exception 'Table <%> not found.', tar.current_table_full_name;
	end if;
	
	if common.is_empty(tar.history_entity_columns_list) then
		raise exception 'Table <%> not found.', tar.history_table_full_name;
	end if;

	if not jsonb_path_exists(tar.current_entity_columns_list, '$.*.pk ? (@ == true)') then	
		raise exception 'Impossible to use trigger without primary key on table <%>.', tar.current_table_full_name;
	end if;
--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;
	----------------------------------------------------------------------------
	--> Retrieve list of unique index (including primary)
	tar.unique_index_list=vrsn.jsonb_table_structure__build_uks ( tar.current_table_full_name);

	
	----------------------------------------------------------------------------
	--> retrive bt_info_name
	begin
		
		select quote_ident(cs.column_name) into strict tar.bt_info_name
		from information_schema.columns as cs
		where cs.table_schema		= (tar).current_table_full_name.schema_name
			and cs.table_name   	= (tar).current_table_full_name.table_name
			and (cs.udt_name		= pg_typof(v_tar_s.bt_info)
				 or cs.domain_name	= pg_typof(v_tar_s.bt_info)
				 );
	exception
		when others then
			null;
	end;
--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;	
	----------------------------------------------------------------------------
	--> set the standard key of record
	with tmp as (
		select  jsonb_object_keys(tar.current_entity_columns_list) as jok, null as val
	)
	select hstore(array_agg(jok), array_agg(val)) into tar.table_old_rec
	from tmp;

	tar.table_new_rec=tar.table_old_rec;

--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;

	----------------------------------------------------------------------------
	--> Build standard actions
	
	tar = vrsn.__tar_h__build_actions(tar);
--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;


	----------------------------------------------------------------
	--	Manage the last action
	--	if v_dml_action is:
	--		0: no action (impossible here),
	--		1: insert record,
	--		2: update: delete old record and inser new,
	--		3: just skip insert (there was a change on going)

	v_tar_s = tar ;
	
	if v_dml_action = 3 then
	
		return v_tar_s;
		
	 end if;

	----------------------------------------------------------------
	--	Try to obtain an exclusive lock
	--	If cannot simply return

    advisory_xact_ok = vrsn.__lock__get_advsory(
			'vrsn.trigger_activation_record_base'
		,	p_entity_full_name::text
		,	false
		,	false
	);


	IF NOT advisory_xact_ok THEN
		--raise notice 'exclusive lock not acquired';
	
		return v_tar_s;
		
	elsif v_dml_action = 2 then
	
		delete 
		from only vrsn.trigger_activation_record_base as t
		where t.entity_full_name=tar.entity_full_name			
		;
		v_dml_action =1;
		
	end if;
	
	insert into vrsn.trigger_activation_record_base
	select tar.*;	
	
/**/

--v_tar_s = tar ;	i=i+1;raise notice e'\nv_tar_s (%):\n<%>', i, v_tar_s;


	-----------------------------------------------------------------------------
	-- Inserisco la forma corrente del TAR nella tabella di changlog
	-- se i dati cambiano
	if (tar).func_state_var.tar_changelog then
		perform vrsn.__tar_h__add_changelog	(tar);
	end if;

	return v_tar_s;
	
end;
$_$;


--
-- Name: __tar_h__build_actions(vrsn.trigger_activation_record_base); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__build_actions(INOUT tar vrsn.trigger_activation_record_base) RETURNS vrsn.trigger_activation_record_base
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	inout inout tar vrsn.trigger_activation_record_base
*/

	c_action_runningTouch				constant	text=	'runningTouch';
	c_action_runningUpdate				constant	text=	'runningUpdate';
	c_action_runningInsert				constant	text=	'runningInsert';
	c_action_runningDelete				constant	text=	'runningDelete';
	c_action_pastDateRunningInsert		constant	text=	'pastDateRunningInsert';
	c_action_historyInsert				constant	text=	'historyInsert';
	c_action_pastDateHistoryReOpen		constant	text=	'pastDateHistoryReOpen';
	c_action_pastDateHistoryDeactivate	constant	text=	'pastDateHistoryDeactivate';
	c_action_historySearchByDate		constant	text=	'historySearchByDate';


	_sqlStr				hstore;
	_insertFieldsList	text[]=array['','','','','',''];
	_selectFieldsList	text[]=array['','','','','',''];
	_whereStr			text[]=array['','','','','',''];
	_k					text;
	_jb					jsonb;
	_jbHistory			jsonb;
begin

/*
1 insert a storico
2 update a regime
3 insert nuovo a regime
4 clona righe a storico per data antergata
5 chiudi periodi a storico per data antergata
6 inserisci riga a storico per data futura
7 modifica riga a regime per data futura

*/
	for _k, _jb in 
		select *
		from jsonb_each(tar.current_entity_columns_list)
	loop

--		raise notice '<%> <%> <%> ',_k, _jb, pg_typeof(_jb);
/*		
		for _rec in select jsonb_object_keys(_value) loop
			raise notice '%', _rec;
		end loop;
*/
		--> add to where
		
		if (_jb->>'pk')::boolean then
			_whereStr[1]= _whereStr[1] || ' and ' || quote_ident(_k) || 
				'=:' || _k
				||':::'|| (_jb->>'type');
		
		end if;

		--> evaluate fields
		if _k=tar.bt_info_name then
--			_insertFieldsList[1]= _insertFieldsList[1] || ', ' || quote_ident(_k);
			_insertFieldsList[2]= _insertFieldsList[2] ||', ' || quote_ident(_k) || '= $1';
			_insertFieldsList[3]= _insertFieldsList[3] || ', ' || quote_ident(_k);
--			_selectFieldsList[1]= _selectFieldsList[1] || ', $1';			
			_selectFieldsList[3]= _selectFieldsList[3] || ', $1';
--			_selectFieldsList[6]= _selectFieldsList[6] || ', $1';
		elseif _jb->>'generated' = 'always' or _jb->>'generated' = 'identity' then
			null;	
		else
			if not (_jb->>'pk')::boolean  then
				_insertFieldsList[2]= _insertFieldsList[2] ||', ' || quote_ident(_k) || '= :' || _k || ':::'|| (_jb->>'type') ;
			end if;
			
			_insertFieldsList[3]= _insertFieldsList[3] || ', ' || quote_ident(_k);			
			if _jb->>'generated' = 'default' then
			/*
				si potrebbe immaginere una pseudo funzione defualtOnNull:
				
				_selectFieldsList[3]= _selectFieldsList[3] || ', defulatOnNull(:' || _k ||':)::'|| (_jb->>'type');
				
				e valutare nella funzione bind_action se il valore passato è null in quel caso sostituirlo con default e togliere la tipizzazione
				ma al momento sembra un inutile sofismo
			*/
				_selectFieldsList[3]= _selectFieldsList[3] || ', DEFAULT';				
			else
				_selectFieldsList[3]= _selectFieldsList[3] || ', :' || _k ||':::'|| (_jb->>'type');
			end if;
			
		end if;

		-- If the key is part of history column list

		if tar.history_entity_columns_list ? _k then
			_jbHistory = tar.history_entity_columns_list->_k;
		
			
			
			--if _jb->>'generated' = 'nullOnHistory' then
			if (_jb->>'null_on_history')::boolean then
			
			
				_insertFieldsList[1]= _insertFieldsList[1] || ', ' || quote_ident(_k);			
				_selectFieldsList[1]= _selectFieldsList[1] || ', null';
				
				_selectFieldsList[6]= _selectFieldsList[6] || ', :' || _k ||':::'|| (_jb->>'type');
			
			elseif _jbHistory->>'generated' = 'always' or _jbHistory->>'generated' = 'identity' then
				null;
/*
			non si può gestire
			elseif _jbHistory->>'generated' ='default' then
			
				_insertFieldsList[1]= _insertFieldsList[1] || ', ' || quote_ident(_k);			
				_selectFieldsList[1]= _selectFieldsList[1] || ', DEFAULT';
				
				_selectFieldsList[6]= _selectFieldsList[6] || ', DEFAULT';
*/				
			else
				if _k=tar.bt_info_name then
					_selectFieldsList[1]= _selectFieldsList[1] || ', $1';
					_selectFieldsList[6]= _selectFieldsList[6] || ', $1';
				else
					_selectFieldsList[1]= _selectFieldsList[1] || ', ' || quote_ident(_k);
					_selectFieldsList[6]= _selectFieldsList[6] || ', :' || _k ||':::'|| (_jb->>'type');
				end if;
				
				_insertFieldsList[1]= _insertFieldsList[1] || ', ' || quote_ident(_k);
				

				
			end if;
		end if;

	end loop;

	--> prepare fields for past date
	for _k, _jb in 
		select *
		from jsonb_each(tar.history_entity_columns_list)
	loop

--		raise notice '<%> <%> <%> ',_k, _jb, pg_typeof(_jb);
		if  _k=tar.bt_info_name or _jb->>'generated' in ('always') then
			continue;
		end if;
				
		_insertFieldsList[4]= _insertFieldsList[4] || ', ' || quote_ident(_k);
		_selectFieldsList[4]= _selectFieldsList[4] || ', :' || _k ||':::'|| (_jb->>'type');
		

	end loop;

	
	_whereStr[1] = substring(_whereStr[1] from 6);

	_sqlStr[c_action_historyInsert]=format($$
		--historyInsert
		--$1 bt_info with user ts close
		insert into %1$s (%2$s)
		select %3$s
		from only %4$s
		where %5$s
--		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.history_table_full_name)
			,	substring(_insertFieldsList[1] from 2)
			,	substring(_selectFieldsList[1] from 2)
			,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	_whereStr[1]
		);

	_sqlStr[c_action_runningUpdate]=format($$
		--historyInsert
		--$1 new bt_info
		update only %1$s
			set %2$s
		where %3$s
		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	substring(_insertFieldsList[2] from 2)
			,	_whereStr[1]
		);

	_sqlStr[c_action_runningDelete]=format($$
		--runningDelete
		delete from only %1$s			
		where %2$s
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	_whereStr[1]
		);

	_sqlStr[c_action_runningInsert]=format($$
		--runningInsert
		--$1 new bt_info
		insert into %1$s (%2$s)
		values ( %3$s)
		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	substring(_insertFieldsList[3] from 2)
			,	substring(_selectFieldsList[3] from 2)
		);

	_sqlStr[c_action_pastDateRunningInsert]=format($$
		--pasteDateRunningInsert
		--$1 new bt_info
		insert into %1$s (%2$s)
		values ( %3$s)
		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	substring(_insertFieldsList[3] from 2)
			,	substring(_selectFieldsList[6] from 2)
		);

/*
	_sqlStr[c_action_futureDateRunningUpdate]=format($$
		--futureDateRunningUpdate
		--$1 new bt_info
		update only %1$s.%2$s
			set %3$s=$1
		where %4$s
		$$	,	quote_ident(tar.name_of_schema)
			,	quote_ident(tar.main_table)
			,	quote_ident(tar.bt_info_name)
			,	_whereStr[1]
		);

	_sqlStr[c_action_futureDateHistoryInsert]=format($$
		--futureDateHistoryInsert
		--$1 new bt_info
		insert into %1$s.%2$s (%3$s)
		values ( %4$s)
		$$	,	quote_ident(tar.name_of_schema)
			,	quote_ident(tar.history_table)
			,	substring(_insertFieldsList[3] from 2)
			,	substring(_selectFieldsList[3] from 2)
		);
*/
	_sqlStr[c_action_pastDateHistoryReOpen]=format($$
		--pastDateHistoryReOpen
		--$1 user_ts_start
		--$2 db_ts_start
		--$3 user_id
		insert into %1$s
			(%3$s, %2$s)
		select %4$s, row(
						tstzrange(lower((%2$s).user_ts_range),'infinity','[)')
					,	tstzrange($2,'infinity','[)')
					,	vrsn.audit_record__reopen($3, (%2$s).audit_record,$2)
					)::vrsn.bitemporal_record 
		from only %6$s
		where %5$s			
			and (%2$s).user_ts_range @> $1
			--and upper((%2$s).db_ts_range) = 'infinity'
			and vrsn.audit_record__is_active( (%2$s).audit_record )
			--and (%2$s).db_ts_range @> $1
		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	quote_ident(tar.bt_info_name)
			,	substring(_insertFieldsList[4] from 2)
			,	substring(_insertFieldsList[4] from 2)
			,	_whereStr[1]
			,	vrsn.__entity_fullname_type__to_ident(tar.history_table_full_name)
		);

	_sqlStr[c_action_pastDateHistoryDeactivate]=format($$
		--pastDateHistoryDeactivate
		--$1 user_ts_end 
		--$2 db_ts_end
		--$3 username
		update only %1$s
		set %2$s=row(
						case when upper((%2$s).user_ts_range) = 'infinity' then tstzrange(lower((%2$s).user_ts_range),$2,'[)')
						else (%2$s).user_ts_range end
			---		,	tstzrange(lower((%2$s).db_ts_range), $2,'[)')
					,	case when upper((%2$s).db_ts_range) = 'infinity' then tstzrange(lower((%2$s).db_ts_range),$2,'[)')
						else (%2$s).db_ts_range end
					,	vrsn.audit_record__deactivate(audit_record=>(%2$s).audit_record, user_id=>$3, when_appens=>$2)
					)::vrsn.bitemporal_record 
		where %3$s
			and ( (%2$s).user_ts_range @> $1 or $1 <= lower((%2$s).user_ts_range) )
			--and upper((%3$s).db_ts_range) = 'infinity'
			and vrsn.audit_record__is_active( (%2$s).audit_record )
			and lower((%2$s).db_ts_range) < $2
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.history_table_full_name)
			,	quote_ident(tar.bt_info_name)
			,	_whereStr[1]
		);

	_sqlStr[c_action_historySearchByDate]=format($$
		--historySearchByDate
		--$1 user_ts_end 
		select count(*) as n
		from only %1$s
		where %3$s
			and (%2$s).user_ts_range @> $1
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.history_table_full_name)
			,	quote_ident(tar.bt_info_name)		  
			,	_whereStr[1]
		);
			--and ((%2$s).user_ts_range @> $1 or lower((%2$s).user_ts_range) > $1)
			--and (%2$s).db_ts_range @> $2

	_sqlStr[c_action_runningTouch]=format($$
		--runningTouch
		update only %1$s
			set %2$s.audit_record['touchTs']=to_jsonb( clock_timestamp() )
		where %3$s
		returning *
		$$	,	vrsn.__entity_fullname_type__to_ident(tar.current_table_full_name)
			,	quote_ident(tar.bt_info_name)
			,	_whereStr[1]
		);

	tar.actions=_sqlStr;
end;
$_$;


--
-- Name: __tar_h__config_func_build(vrsn.trigger_activation_record_base); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__config_func_build(INOUT tar vrsn.trigger_activation_record_base) RETURNS vrsn.trigger_activation_record_base
    LANGUAGE plpgsql
    AS $$
DECLARE
--	inout vrsn.trigger_activation_record_base


	-- Parametri globali sovrascritti da vrsn.parameters__get_list.
	v_global_params_from_func jsonb;

BEGIN
	-------------------------------------------------------------------
	-- Applica i parametri globali da vrsn.parameters__get_list.
	
	v_global_params_from_func := vrsn.parameters__get('tar');

	-- se non torna dati li recupero da vrsn.__tar_h__config_func_init
	-- dovrebbe accadere solo all'inizio
	if v_global_params_from_func is null then
		v_global_params_from_func := vrsn.__tar_h__config_func_init();
	end if;
	
	tar.func_param := v_global_params_from_func->'params';
	

	---------------------------------------------------------------
	-- imposto a false tutte le state_var
	SELECT format('(%s)'
		,	string_agg('f'::text,',')
		)::vrsn.tar_state_variables
		into tar.func_state_var
	/*
		t.oid as t_oid
		,	t.typname as type_name
		,	c.oid as c_oid
		,	a.attrelid as a_oid
		,	a.attname as attribute_name
		,	a.attnum as attribute_name
		,	a.atttypid as attribute_type_oid
	*/
	FROM pg_type t
	JOIN pg_class c ON c.oid = t.typrelid
	JOIN pg_attribute a ON a.attrelid = c.oid
	WHERE t.oid= pg_typeof(tar.func_state_var)
	AND a.attnum > 0 
	AND NOT a.attisdropped;


/*
	if tar.historice_entity ='never' then
		tar.func_state_var.versioning_active=false;
	else
		tar.func_state_var.versioning_active=true;
	end if;

	tar.func_state_var.versioning_active=true;
	tar.func_state_var.ignore_unchanged_values=true;
	tar.func_state_var.mitigate_conflicts=true;
	tar.func_state_var.is_ready=true;
*/
	------------------------------------------------------------
	-- inizializzo i state_var con i parametri di default
	tar.func_state_var=jsonb_populate_record(tar.func_state_var
		, v_global_params_from_func->'state_variables');

	
END;
$$;


--
-- Name: __tar_h__config_func_init(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__config_func_init() RETURNS jsonb
    LANGUAGE sql
    BEGIN ATOMIC
 SELECT '{"params": {"t_closed": "is_closed", "username": null, "extraInfo": null, "t_onDupKey": "onDupKey", "t_onUpdate": "onUpdate", "t_username": "modify_user_id", "t_modify_ts": "modify_ts", "t_versioning": "versioning", "t_action_hints": "action_hints", "tar_week_to_live": 10, "t_onUnchangedValue": "onUnchangedValue", "t_versioning_c_off": "off", "t_onDupKey_c_update": "update", "hours_for_nearPastTime": 3, "t_onDupKey_c_doNothing": "do nothing", "seconds_for_nearRealTime": 5, "t_onUpdate_c_ignoreNulls": "ignore nulls", "t_onUnchangedValue_c_touch": "touch", "t_onUnchangedValue_c_update": "update", "t_onUnchangedValue_c_discard": "discard", "t_allowFullDeactivationByPastCloseTs": "allowFullDeactivationByPastCloseTs"}, "state_variables": {"is_ready": true, "tar_changelog": true, "versioning_active": true, "mitigate_conflicts": true, "ignore_unchanged_values": true}}'::jsonb AS tar_config;
END;


--
-- Name: __tar_h__config_func_update(vrsn.trigger_activation_record_stack); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__config_func_update(INOUT tar vrsn.trigger_activation_record_stack) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $$
DECLARE
--	INOUT tar vrsn.trigger_activation_record_stack,
--	IN tar.wrkn_new_rec hstore)

	-- Action hints forniti dall'utente nel record NEW.
	v_user_action_hints jsonb;

	-- Nome della chiave per gli action_hints (configurabile).
	v_action_hints_key_name text;

BEGIN

	--------------------------------------------------------------------------
	-- Estrai e applica gli action_hints forniti dall'utente (tar.wrkn_new_rec).

	
	-- Ottieni il nome della chiave 'action_hints' dal config_func (potrebbe essere stato sovrascritto).
	v_action_hints_key_name := tar.func_param->>'t_action_hints';

	-- Se tar.wrkn_new_rec nont contiene la chiave per gli action_hints o il suo valore non è vuoto.
	IF not tar.wrkn_new_rec ? v_action_hints_key_name or common.is_empty(tar.wrkn_new_rec[v_action_hints_key_name]) THEN
		return;
	end if;
	
	-- Recupera direttamente il valore jsonb.
	v_user_action_hints := (tar.wrkn_new_rec[v_action_hints_key_name])::jsonb;

	if v_user_action_hints ? (tar.func_param->>'t_onDupKey') then

		if v_user_action_hints->>(tar.func_param->>'t_onDupKey') = tar.func_param->>'t_onDupKey_c_update' then
			tar.func_state_var.on_Dup_Key_Update=true;
		elseif v_user_action_hints->>(tar.func_param->>'t_onDupKey') = tar.func_param->>'t_onDupKey_c_doNothing' then
			tar.func_state_var.on_Dup_Key_Exit =true;
		end if;

	end if;
	

	if v_user_action_hints ? (tar.func_param->>'t_versioning') then

		if v_user_action_hints->>(tar.func_param->>'t_versioning') = tar.func_param->>'t_versioning_c_off' then
			tar.func_state_var.versioning_active=false;
		end if;

	end if;

	if v_user_action_hints ? (tar.func_param->>'t_onUnchangedValue')
		and v_user_action_hints->>(tar.func_param->>'t_onUnchangedValue') = tar.func_param->>'t_onUnchangedValue_c_update' then
			tar.func_state_var.ignore_unchanged_values = false;
	else
			tar.func_state_var.ignore_unchanged_values = true;
	end if;

	if v_user_action_hints ?	(tar.func_param->>'t_onUpdate')
		and v_user_action_hints->>(tar.func_param->>'t_onUpdate') = tar.func_param->>'t_onUpdate_c_ignoreNulls' then
			tar.func_state_var.ignore_null_on_update=true;
	end if;

	if v_user_action_hints ? (tar.func_param->>'t_allowFullDeactivationByPastCloseTs') then
		tar.func_state_var.allow_full_deactivation_by_past_close_ts=(v_user_action_hints->>(tar.func_param->>'t_allowFullDeactivationByPastCloseTs'))::boolean;
	end if;

	if v_user_action_hints ? (tar.func_param->>'t_dbTs') then

		begin
			tar.time_stamp_to_use = (v_user_action_hints->>(tar.func_param->>'t_dbTs'))::timestamptz;
		exception
			when others then
			null;
		end;
		
		
	end if;

	v_user_action_hints= v_user_action_hints - array[
			tar.func_param->>'t_onDupKey'
		,	tar.func_param->>'t_onUnchangedValue'
		,	tar.func_param->>'t_onUpdate'
		,	tar.func_param->>'t_versioning'
		,	tar.func_param->>'t_allowFullDeactivationByPastCloseTs'
		,	tar.func_param->>'t_dbTs'
		];

	if not common.is_empty( v_user_action_hints ) then
		tar.func_param['extraInfo'] =v_user_action_hints;
	end if;
	

	-- 5. Sovrascrivi i campi specifici di _tar direttamente dal config_func consolidato.
	-- Questi campi ora prendono i valori finali che provengono dal config_func.
--	tar.mitigate_conflicts := (tar.func_param ->> 'mitigate_conflicts')::boolean;
--	tar.ignore_unchanged_values := (tar.func_param ->> 'ignoreUnchangedValue')::boolean;
--	tar.historice_entity := (tar.func_param ->> 'historice_entity');
--	tar.enable_history_attributes := (tar.func_param ->> 'enable_history_attributes')::boolean;
--	tar.enable_attribute_to_fields_replacement := (tar.func_param ->> 'enable_attribute_to_fields_replacement')::boolean;

	
END;
$$;


--
-- Name: __tar_h__constant(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__constant() RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT '
	---------------
	-- constant
	c_cached_fields_list				constant	text=	''cached_fields_list'';
	c_t_closed							constant	text=	''t_closed'';
	c_t_username						constant	text=	''t_username'';
	c_t_action_hints					constant	text=	''t_action_hints'';
	c_hOldRec							constant	text=	''hOldRec'';
	c_hNewRec							constant	text=	''hNewRec'';
	c_username							constant	text=	''username'';
	c_extra_info						constant	text=	''extra_info'';
	c_extraInfo							constant	text=	''extraInfo'';
	c_touchTs							constant	text=	''touchTs'';
	c___IS_READY__						constant	text=	''__IS_READY__'';
	c_actualCloseTs						constant	text=	''actualCloseTs'';
	c_actualInsertTs					constant	text=	''actualInsertTs'';

	c_action_runningTouch				constant	text=	''runningTouch'';
	c_action_runningUpdate				constant	text=	''runningUpdate'';
	c_action_runningInsert				constant	text=	''runningInsert'';
	c_action_runningDelete				constant	text=	''runningDelete'';
	c_action_pastDateRunningInsert		constant	text=	''pastDateRunningInsert'';
	c_action_historyInsert				constant	text=	''historyInsert'';
	c_action_pastDateHistoryReOpen		constant	text=	''pastDateHistoryReOpen'';
	c_action_pastDateHistoryDeactivate	constant	text=	''pastDateHistoryDeactivate'';
	c_action_historySearchByDate		constant	text=	''historySearchByDate'';


'::text AS constant_definition;
END;


--
-- Name: __tar_h__get_def_behavior(vrsn.trigger_activation_record_base); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__get_def_behavior(INOUT tar vrsn.trigger_activation_record_base) RETURNS vrsn.trigger_activation_record_base
    LANGUAGE plpgsql
    AS $$
declare
--	INout tar vrsn.trigger_activation_record_base


	
	_rec record;
	_main_fields_list text;
	_cached_fields_list text;
	_final_main_fields_array text[];
	_final_cached_fields_array text[];	
	c_cached_attribute_name text='vrsn.cached_attribute';

begin

	-----------------------------------------------------------------------------
	--> looking for definition
	begin

		SELECT * into strict _rec
		FROM only vrsn.def_entity_behavior
		where entity_full_name = tar.entity_full_name;

		exception
			when no_data_found	 then
				null;
	end;


	-----------------------------------------------------------------------------
	--> Set object full name

	tar.current_view_full_name = _rec.current_view_full_name;
	tar.current_table_full_name = _rec.current_table_full_name;
	tar.history_table_full_name = _rec.history_table_full_name;
	tar.attribute_entity_full_name = _rec.attribute_entity_full_name;


	
	
	case _rec.historice_entity 
	when 'never' then
		tar.func_state_var.func_state_var.versioning_active=false;
		tar.func_state_var.enable_version_only_on_main_change=false;
	when 'always' then
		tar.func_state_var.enable_version_only_on_main_change=false;
		tar.func_state_var.versioning_active=true;
	when 'on_main_fields' then
		tar.func_state_var.enable_version_only_on_main_change=true;
		tar.func_state_var.versioning_active=true;
	else
		raise exception 'Value <%> not recognizable for historice_entity', _rec.historice_entity ;
	end case;
	
	tar.func_state_var.enable_history_attributes = _rec.enable_history_attributes;
	tar.func_state_var.mitigate_conflicts = _rec.mitigate_conflicts;
	tar.func_state_var.ignore_unchanged_values = _rec.ignore_unchanged_values;
	tar.func_state_var.enable_attribute_to_fields_replacement = _rec.enable_attribute_to_fields_replacement;

	_main_fields_list = _rec.main_fields_list;
	_cached_fields_list = _rec.cached_fields_list;



	-----------------------------------------------------------------------------
	-- calcola l'array finale per 'main_fields_list' (unione)
	select array_agg(elem order by elem)
	into _final_main_fields_array
	from (
		-- elementi da jsonb (pk=true)
		select key_name as elem
		from jsonb_each(tar.current_entity_columns_list) as data_entry(key_name, value_obj)
		where (value_obj ->> 'pk')::boolean = true
		union
		-- elementi da _main_fields_list
		select unnest(string_to_array(_main_fields_list, ',')) as elem
		where _main_fields_list is not null and trim(_main_fields_list) <> ''
	) as combined_main_fields;

	-----------------------------------------------------------------------------
	-- calcola l'array finale per 'cached_fields_list' (intersezione)
	select array_agg(elem order by elem)
	into _final_cached_fields_array
	from (
		-- elementi da jsonb (type='text')
		select key_name as elem
		from jsonb_each(tar.current_entity_columns_list) as data_entry(key_name, value_obj)
		where value_obj ->> 'type' = c_cached_attribute_name
		intersect
		-- elementi da _cached_fields_list
		select unnest(string_to_array(_cached_fields_list, ',')) as elem
		where _cached_fields_list is not null and trim(_cached_fields_list) <> ''
	) as intersected_cached_fields;

	-- gestisce il caso in cui i risultati finali siano null (es. nessuna unione/intersezione)
	if _final_main_fields_array is null then
		_final_main_fields_array := '{}';
	end if;
	
	-----------------------------------------------------------------------------	
	-- se non ci sono campi candidati per la storicizzazione degli attributi
	-- disattivo la storicizzazione degli attributi
	if array_length(_final_cached_fields_array,1) is null then
		_final_cached_fields_array := '{}';
		tar.func_state_var.enable_history_attributes=false;
	end if;

	-----------------------------------------------------------------------------
	-- costruisci il jsonb finale
	tar.history_attributes_info= jsonb_build_object(
		'main_fields_list', to_jsonb(_final_main_fields_array),
		'cached_fields_list', to_jsonb(_final_cached_fields_array)
	);


	return;
	
end;
$$;


--
-- Name: __tar_h__handle_attribute_field(vrsn.trigger_activation_record_stack); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__handle_attribute_field(INOUT tar vrsn.trigger_activation_record_stack) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $_$
declare
--	INOUT tar vrsn.trigger_activation_record_stack)

	--	save new attribute created because
	--	the query could return null many times for an attribute 
	--	for example in case of array
	--		attribut1.__ARRAY__	-	1	- some value
	--		attribut1.__ARRAY__	-	2	- some other value
	v_new_attribute				jsonb;

	v_cached_field				text;	
	v_last_attribute_name_idx	text;
	v_new_attribute_name_idx	text;
	v_rec						record;	
	v_key						text;
	v_jb						jsonb;
	v_sqlStr					text;

	v_hrec_attribute			hstore;

	v_attribute_field_list		jsonb=$${	
			"attribute_id": {
				"pk": true,
				"type": "bigint",
				"generated": "",
				"default_value": null
			}
		,	"attribute_value": {
				"pk": false,
				"type": "text",
				"generated": "",
				"default_value": null
			}
		,	"idx": {
				"pk": true,
				"type": "text",
				"generated": "",
				"default_value": null
			}
	}$$::jsonb;

	compareAttribute_sql		text= $$
		with elenco_campi as (
			select coalesce(a.attribute_name, b.attribute_name) as attribute_name
			,	coalesce(a.idx,b.idx,' ') as idx
			, 	coalesce(a.attribute_type,'unknown') as old_type
			, 	coalesce(b.attribute_type,'unknown') as new_type
			,	a.attribute_value as old_value
			,	b.attribute_value as new_value
			,	case when b.attribute_name is null then 'Delete'
					when  a.attribute_name is null then 'Insert'
					else 'Update'
				end as action_type
			from common.jsonb_linearize_to_key_value($1) a
			full outer join common.jsonb_linearize_to_key_value( $2 ) b
				on a.attribute_name=b.attribute_name and a.idx=b.idx
			where a.attribute_value<>b.attribute_value
				or a.attribute_type<>b.attribute_type
				or a.attribute_name is null
				or b.attribute_name is null
		)
		select	a.attribute_name
			,	a.idx
			, 	a.old_type
			, 	a.new_type
			,	a.old_value
			,	a.new_value
			,	a.action_type
			,	b.attribute_id
			,	c.attribute_type as default_type
		from elenco_campi as a
		left join vrsn.attribute_lineage as b
			on	a.attribute_name=b.attribute_name
			and	coalesce(b.schema_name,'') in ('', $3)
			and	coalesce(b.entity_name,'') in ('', $4)
		left join vrsn.attribute_mapping_to_entity as c
			on	b.attribute_id = c.attribute_id
			and	c.schema_name = $3
			and	c.entity_name = $4
			and c.field_name = $5
		order by a.attribute_name, a.idx,
			(	case when b.schema_name = $3 then 1 else 0 end
			+	case when b.entity_name = $4 then 1 else 0 end
			) desc	
	$$;

	
begin
--	$1	(tar.wrkn_new_rec[v_cached_field]::jsonb)
--	$2	(tar.wrkn_old_rec[v_cached_field]::jsonb)
--	$3	tar.view_schema_name
--	$4	tar.view_table_name
--	$5	v_cached_field
	----------------------------------------------------------------------------
	-- Create main_field_list and hrecord for attribute table

	
	-- Build standard fields from PK of main entity
	
	for v_key, v_jb in 
		select l->>'key', l->'value'
		from (select jsonb_path_query(tar.current_entity_columns_list, '$.keyvalue() ? (@.value.pk == true)')) sub(l)
	loop

		v_attribute_field_list[v_key]=v_jb;
		
		if (tar).func_state_var.action_close then
			v_hrec_attribute[v_key]=tar.wrkn_old_rec[v_key];
		else
			v_hrec_attribute[v_key]=tar.wrkn_new_rec[v_key];
		end if;		

	end loop;

	
	--	Add standard value
	
	v_key=tar.func_param->>'t_username';
	v_attribute_field_list[v_key] = v_attribute_field_list['attribute_value'];
	v_attribute_field_list[v_key]['type'] = to_jsonb('text'::text);
	v_hrec_attribute[v_key] = tar.wrkn_new_rec[v_key];

	v_key=tar.func_param->>'t_closed';
	v_attribute_field_list[v_key] = v_attribute_field_list['attribute_value'];
	v_attribute_field_list[v_key]['type'] = to_jsonb('boolean'::text);
	v_hrec_attribute[v_key] = tar.wrkn_new_rec[v_key];
	
	v_key=tar.func_param->>'t_modify_ts';
	v_attribute_field_list[v_key] = v_attribute_field_list['attribute_value'];
	v_attribute_field_list[v_key]['type'] = to_jsonb('timestamptz'::text);
	v_hrec_attribute[v_key] = tar.new_valid_ts;

	v_key=tar.func_param->>'t_action_hints';
	v_attribute_field_list[v_key] = v_attribute_field_list['attribute_value'];
	v_attribute_field_list[v_key]['type'] = to_jsonb('jsonb'::text);

	v_new_attribute=(tar.wrkn_new_rec[v_key])::jsonb;
	v_new_attribute[(tar.func_param->>'t_dbTs')] = to_jsonb(tar.time_stamp_to_use);
	
	v_hrec_attribute[v_key] = v_new_attribute::text;

	v_new_attribute='{}'::jsonb;
	
--	v_attribute_field_list['attribute_value']['convertion_func']=to_jsonb('to_jsonb'::text);


--raise notice 'cached_fields_list %', tar.history_attributes_info->'cached_fields_list';

	----------------------------------------------------------------------------
	-- Iterate over the fields for with enable historicizaion
	for v_cached_field in 
	
		SELECT jsonb_array_elements_text(
				tar.history_attributes_info->'cached_fields_list') AS elemento
	loop

		----------------------------------------------------------------------------
		-- looking for 
		--		difference between old and new record
		--		exising attribute_id, if not will be created
		--		existing mapping, if not will be created
		
		for v_rec in
			execute compareAttribute_sql 
			using
				tar.wrkn_old_rec[v_cached_field]::jsonb
			,	case when (tar).func_state_var.action_close 
					then '{}'::jsonb 
					else tar.wrkn_new_rec[v_cached_field]::jsonb
				end
			,	(tar).entity_full_name.schema_name
			,	(tar).entity_full_name.table_name
			,	v_cached_field
			
		loop
			----------------------------------------------------------------------------

--raise notice '%', hstore(v_rec);
			
			-- Use only the most rilevant attribute_id
			
			v_new_attribute_name_idx= v_rec.attribute_name || '-' || v_rec.idx;
			
			if v_new_attribute_name_idx=v_last_attribute_name_idx then
				continue;
			else
				v_last_attribute_name_idx=v_new_attribute_name_idx;
			end if;

			----------------------------------------------------------------------------
			-- If attribute_id is missing, create a new one
			
			if v_rec.attribute_id is null then

				if v_new_attribute ? v_rec.attribute_name then
				
					v_rec.attribute_id = ((v_new_attribute->v_rec.attribute_name)->>'id')::bigint;
				else
					INSERT INTO vrsn.attribute_lineage (attribute_name,	 modify_user_id)
					VALUES (v_rec.attribute_name, 'process:vrsn.new_attribute')
					returning attribute_id into v_rec.attribute_id;

					v_new_attribute = common.jsonb_set_building_path(
							v_new_attribute
						,	(v_rec.attribute_name||'.id')::ltree
						,	to_jsonb(v_rec.attribute_id)
						,	true
					);
			
				end if;

			end if;

			----------------------------------------------------------------------------
			-- If attribute_mapping is missing, create a new one

			if v_rec.default_type  is null then
				if v_new_attribute ? v_rec.attribute_name then
				
					v_rec.default_type = (v_new_attribute->v_rec.attribute_name)->>'type';
				else
					INSERT INTO vrsn.attribute_mapping_to_entity(
							attribute_id, attribute_name, schema_name
							, entity_name, field_name
							, attribute_type, modify_user_id)
					VALUES (v_rec.attribute_id, v_rec.attribute_name, (tar).entity_full_name.schema_name
						,	(tar).entity_full_name.table_name, v_cached_field
						,	v_rec.new_type, 'process:vrsn.new_attribute');
						
					v_rec.default_type=v_rec.new_type;

					v_new_attribute = common.jsonb_set_building_path(
							v_new_attribute
						,	(v_rec.attribute_name||'.type')::ltree
						,	to_jsonb(v_rec.default_type)
						,	true
					);
			
				end if;
			end if;

			----------------------------------------------------------------------------
			-- Update default attribute type if different
	
			if v_rec.default_type <> v_rec.new_type then
			
					v_rec.new_type = common.type__get_wider(v_rec.default_type, v_rec.new_type);
			
					update  vrsn.attribute_mapping_to_entity as a
						set	attribute_type = v_rec.new_type
						,	modify_user_id = 'process:vrsn.new_attribute'
					where	attribute_id	=	v_rec.attribute_id
						and	schema_name 	=	(tar).entity_full_name.schema_name
						and	entity_name		=	(tar).entity_full_name.table_name
						and	field_name		=	v_cached_field
					;
			end if;

			----------------------------------------------------------------------------
			-- Set current values

			
			v_hrec_attribute['idx']=coalesce(v_rec.idx,'');			
			v_hrec_attribute['attribute_id'] = v_rec.attribute_id;
			v_hrec_attribute['attribute_value']= v_rec.new_value;
--raise notice '<%>',to_jsonb(v_hrec_attribute);
			----------------------------------------------------------------------------
			-- Process current attribute
			case v_rec.action_type
			when	'Insert'	then
				v_sqlStr = 'insert into ' 
					||	tar.attribute_entity_full_name::text
					||	vrsn.jsonb_table_structure__get_insert(
								v_hrec_attribute
							,	v_attribute_field_list
					);
				
			when	'Delete'	then
				v_sqlStr = 'update only ' 
					||	tar.attribute_entity_full_name::text
					||	vrsn.jsonb_table_structure__get_update(
								v_hrec_attribute
							,	v_attribute_field_list
					);
			when	'Update'	then
				v_sqlStr = 'update only ' 
					||	tar.attribute_entity_full_name::text
					||	vrsn.jsonb_table_structure__get_update(
								v_hrec_attribute
							,	v_attribute_field_list
					);
			else
				raise exception 'Attribute % cannot be processed', v_rec.attribute_name;
			end case;

			--raise notice 'Sql for attribute: %', v_sqlStr;

			execute v_sqlStr;
			
		end loop; -- compareAttribute_sql
	
	end loop; --cached_fields_list

	----------------------------------------------------------------------------
	--	if tar.historice_entity='on_main_fields'
	--	and there are no update on main fields
	--	disable versioning
	
	if not (tar).func_state_var.action_new
		and (tar).func_state_var.enable_version_only_on_main_change
		and not (tar).func_state_var.past_time
		and not (tar).func_state_var.near_past_time
		and not (
			-- boolean diretto
			select bool_or(
					coalesce(tar.wrkn_new_rec -> field_name::text, '') 
				!= coalesce(tar.wrkn_old_rec -> field_name::text, ''))
			from jsonb_array_elements_text(
					tar.history_attributes_info->'main_fields_list'
				) as field_name
			)
	then
			tar.func_state_var.versioning_active=false;
	end if;

	return;

end;
$_$;


--
-- Name: __tar_h__handle_trigger(vrsn.entity_fullname_type, text, record, record, anycompatiblearray); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__handle_trigger(entity_full_name vrsn.entity_fullname_type, trigger_operation text, oldrec record, newrec record, argv anycompatiblearray DEFAULT ARRAY[]::text[]) RETURNS extensions.hstore
    LANGUAGE plpgsql
    AS $_$
DECLARE
/**
	Starting from
	
	From https://github.com/nearform/temporal_tables/blob/master/versioning_function_nochecks.sql
	temporal tables under The MIT License (MIT)
	Copyright (c) 2016-2017 Nearform and contributors
	Contributors listed at https://github.com/nearform/temporal_tables#the-team and in the README file.
*/	
/*
	vrsn.bitemporal_record
		user_ts_range tstzrange,
		db_ts_range tstzrange,
		audit_record vrsn.audit_record_jsonb_domain

		
	vrsn.trigger_activation_record_stack
		last_update_ts timestamp with time zone DEFAULT now(),
		view_schema_name text COLLATE pg_catalog."default" NOT NULL,
		view_table_name text COLLATE pg_catalog."default" NOT NULL,
		name_of_schema text COLLATE pg_catalog."default" NOT NULL,
		main_table text COLLATE pg_catalog."default" NOT NULL,
		history_table text COLLATE pg_catalog."default" NOT NULL,
		bt_info_name text COLLATE pg_catalog."default" NOT NULL DEFAULT 'bt_info'::text,
		mitigate_conflicts boolean DEFAULT true,
		ignore_unchanged_values boolean DEFAULT true,
		current_entity_columns_list jsonb,
		history_entity_columns_list jsonb,
		old_rec hstore,
		new_rec hstore,
		bt_info vrsn.bitemporal_record,
			actions	hstore
			historyInsert
				--$1 bt_info with user ts close
			runningUpdate
				--$1 new bt_info
			runningDelete
				-- no bind
			runningInsert
				--$1 new bt_info
			futureDateRunningUpdate
				--$1 new bt_info
			futureDateHistoryInsert
				--$1 new bt_info
			pastDateHistoryClone
				--$1 user_ts_start
				--$2 db_ts_start
				--$3 audit_record
			pastDateHistoryClose
				--$1 user_ts_end and db_ts_end
				--$2 username			
			historySearchByDate
				-- no bind
			pasteDateRunningInsert
				--$1 new bt_info
*/

--	IN view_schema_name text,
--	IN view_table_name text,
--	IN trigger_operation text,
--	IN oldrec record,
--	IN newrec record,
--	IN argv anycompatiblearray DEFAULT ARRAY[]::text[],
--	OUT updated_oldrec hstore,
--	OUT updated_newrec hstore)

	---------------
	-- constant
	c_cached_fields_list				constant	text=	'cached_fields_list';
	c_t_closed							constant	text=	't_closed';
	c_t_username						constant	text=	't_username';
	c_t_action_hints					constant	text=	't_action_hints';
	c_hOldRec							constant	text=	'hOldRec';
	c_hNewRec							constant	text=	'hNewRec';
	c_username							constant	text=	'username';
	c_extra_info						constant	text=	'extra_info';
	c_extraInfo							constant	text=	'extraInfo';
	c_touchTs							constant	text=	'touchTs';
	c___IS_READY__						constant	text=	'__IS_READY__';

	c_action_runningTouch				constant	text=	'runningTouch';
	c_action_runningUpdate				constant	text=	'runningUpdate';
	c_action_runningInsert				constant	text=	'runningInsert';
	c_action_runningDelete				constant	text=	'runningDelete';
	c_action_pastDateRunningInsert		constant	text=	'pastDateRunningInsert';
	c_action_historyInsert				constant	text=	'historyInsert';



	tar								vrsn.trigger_activation_record_stack;	

	--> hstore('') avoid null assignment

	_rec								record;
--	_updated_oldrec						record;
	_updated_newrec						record;
	updated_newrec 						hstore;
	
	_k									text;
	_v									text;
	_jb									jsonb;
	_n									integer;
	
	_sqlStr								text;

BEGIN

	----------------------------------------------------------------------------
	--> Build tar
	----------------------------------------------------------------------------
	tar = vrsn.tar_h__get(entity_full_name, argv);

	tar.time_stamp_to_use = clock_timestamp();
	tar.new_valid_ts = tar.time_stamp_to_use;
	tar.wrkn_new_rec=hstore(newrec);
	tar.status ='{}'::jsonb;

/*
raise notice e'\nu:<%>\n%' ,tar.func_param->>c_t_username, tar.wrkn_new_rec;
raise notice e'\nv:<%>' ,tar.wrkn_new_rec[tar.func_param->>c_t_username];
tar.func_param[c_username] = 'process:vrsn.register';
*/	
	
	----------------------------------------------------------------------------
	--> define which action to perform
	----------------------------------------------------------------------------
	case trigger_operation
	
	when 'DELETE'  then	
		raise exception using message='Delete not allowed'
			, hint='Use update with is_closed=true instead';
			
	when 'INSERT' then
	
		tar.func_state_var.action_new=true;
		tar.wrkn_old_rec=hstore('');

	when 'UPDATE' then
	
		tar.wrkn_old_rec = hstore(oldrec);
		
		if tar.wrkn_new_rec ? (tar.func_param->>c_t_closed )
			and tar.wrkn_new_rec[ tar.func_param->>c_t_closed ]::boolean 
		then
			tar.func_state_var.action_close=true;
		else
			tar.func_state_var.action_mod =true;
		end if;
		
	else
		raise exception  'Operation <%> not recognized ',trigger_operation using hint='Use insert or update';		
	end case;

--raise notice e'\nw_old:\n%\nw_new:\n\n%', tar.wrkn_old_rec,tar.wrkn_new_rec;


	----------------------------------------------------------------------------
	--> If is enable_attribute_to_fields_replacement=true
	--> merge information 	
	if (tar).func_state_var.enable_attribute_to_fields_replacement 
			and not (tar).func_state_var.action_close then
			
		-- Supponiamo:
		-- hstore_var = 'jb1=>{"name":"John","jb2":"skip"}, jb2=>{"age":"30","jb1":"skip"}, name=>old, age=>old'
		-- cached_fields_list = ["jb1", "jb2"]
		
		-- Dalla jb1 prende: "name":"John" (scarta "jb2":"skip")
		-- Dalla jb2 prende: "age":"30" (scarta "jb1":"skip")
		-- Risultato: name viene aggiornato a "John", age a "30"
		tar.wrkn_new_rec := tar.wrkn_new_rec || coalesce((
			with cached_fields as (
				select value::text as field_name
				from jsonb_array_elements_text(tar.history_attributes_info->c_cached_fields_list)
			)
			select hstore(array_agg(key), array_agg(value))
			from cached_fields cf
			cross join jsonb_each_text((tar.wrkn_new_rec -> cf.field_name)::jsonb) as j(key, value)
			where	tar.wrkn_new_rec ? j.key
				and	j.key not in (
					select field_name from cached_fields
				)
			), ''::hstore);

		
	end if;

	----------------------------------------------------------------------------
	--  Check if exist of username	
	if 	 common.is_empty(tar.wrkn_new_rec[(tar.func_param->>c_t_username)]) 	then
	
		raise exception using message='Impossible to update without USER information'
			, hint=format('Try adding <%s> field.', tar.func_param->>c_t_username);
			
	end if;		
	
	tar.func_param[c_username] =to_jsonb( tar.wrkn_new_rec[tar.func_param->>c_t_username]);
		
		

	----------------------------------------------------------------------------
	-- Recupero i parametri dagli action_hints se presenti
	----------------------------------------------------------------------------
	--> Se tar.wrkn_new_rec non contiene la chiave per gli action_hints o il suo valore non è vuoto.
	if tar.wrkn_new_rec ? (tar.func_param->>c_t_action_hints )
		and not common.is_empty(tar.wrkn_new_rec[tar.func_param->>c_t_action_hints]) THEN
		
		tar = vrsn.__tar_h__config_func_update(tar);
		
	end if;

--raise notice e'\ntar configuration\n%', jsonb_pretty(to_jsonb(tar));

/*
--raise notice '%', tar.wrkn_old_rec;
--raise notice '%',  akeys(tar.wrkn_old_rec);
--raise notice '%', array_length(akeys(tar.wrkn_old_rec), 1);

*/

--raise notice e'base\nw_new:\n%\nt_new:\n%',tar.wrkn_new_rec, tar.table_new_rec;


	----------------------------------------------------------------------------
	--> load data into tar
	----------------------------------------------------------------------------
	tar = vrsn.__tar_h__prepare_record(tar);
--raise notice e'after prepare\nw_new:\n%\nt_new:\n%',tar.wrkn_new_rec, tar.table_new_rec;
--raise notice e'\ntar configuration\n%', jsonb_pretty(to_jsonb(tar));
/*
raise notice e'\nstatus: %\nw_old:\n%\nw_new:\n\n%\nt_old:\n%\nt_new:\n\n%'
, tar.status, tar.wrkn_old_rec,tar.wrkn_new_rec,tar.table_old_rec,tar.table_new_rec;
*/
/*
raise notice e'after prepare\n%\n%\n%', tar.entity_full_name::text
		, jsonb_pretty(to_jsonb(tar.func_state_var))
		, tar.history_attributes_info;
*/
	----------------------------------------------------------------------------
	-->	check coherence and
	-->	manage on dup key 
	----------------------------------------------------------------------------
	if (tar.status->>c_hOldRec)::bool then
		if (tar).func_state_var.action_new then
			if 	(tar).func_state_var.on_dup_key_update then
				--> if old record found and on dup key update active
				--> swith to mod mode
				tar.func_state_var.action_mod=true;
				tar.func_state_var.action_new =false;
				tar.wrkn_old_rec=hstore(newrec) || tar.table_old_rec;
			elseif (tar).func_state_var.on_dup_key_exit  then
				--> if old record found and on dup key exit active
				--> exit
--				updated_oldrec=hstore(newrec) || tar.table_old_rec;
				updated_newrec=updated_oldrec;
				return updated_newrec;
			else
				RAISE unique_violation;
			end if;
		end if;
	elseif not (tar).func_state_var.action_new then
		raise exception 'UPDATE not allowed. There are no records. Try with INSERT instead.';		
	end if;

	if not (tar.status->>c_hNewRec)::bool 
		and (
				(tar).func_state_var.action_new
			or	(tar).func_state_var.action_mod
		)
	then
		raise exception 'INSERT or UPDATE require NEW record.';		
	end if;

	
	
	--> Check if command is coherent with data
	--> manage also merge behaviour
	if (tar).func_state_var.action_new and tar.bt_info_old is not null then
		raise exception 'INSERT not allowed. Record already inserted. Try with UPDATE instead.';
	elseif ((tar).func_state_var.action_mod or (tar).func_state_var.action_close) and tar.bt_info_old is  null then
		raise exception 'UPDATE not allowed. There are no records. Try with INSERT instead.';
	end if;
/*
raise notice 'For <%> userTs is <%>, dbTs is <%>', tar.entity_full_name::text
		, tar.new_valid_ts, tar.time_stamp_to_use;
*/		
	----------------------------------------------------------------------------
	-- gestione storicizzazione attributi qui
	----------------------------------------------------------------------------
	if (tar).func_state_var.enable_history_attributes then
	
		tar = vrsn.__tar_h__handle_attribute_field(tar);
/*
		raise notice e'after attribute handling\n%\n%\n%', tar.entity_full_name::text
		, jsonb_pretty(to_jsonb(tar.func_state_var))
		, tar.history_attributes_info;
*/
	end if;

	----------------------------------------------------------------------------
	--> If the are no change and is enabled ignore unchanged value
	--> touches record and exit
	----------------------------------------------------------------------------
	if (tar).func_state_var.action_mod 
		and (tar).func_state_var.ignore_unchanged_values
		and not (tar).func_state_var.found_changed_value
	then
	
		_sqlStr=vrsn.__tar_h__bind_action( 
					tar.actions[c_action_runningTouch]
				,	tar.table_new_rec
		);
			--raise notice '%', _sqlStr;
		execute _sqlStr into _updated_newrec;
			
		updated_newrec=tar.wrkn_old_rec || hstore(_updated_newrec);
			
		return updated_newrec;
		
	end if;
	

	
	--raise notice 'pastDate: % nearPastDate: %', (tar).func_state_var.past_time,(tar).func_state_var.near_past_time;

	
	----------------------------------------------------------------------------
	--> create new audit record with username and touchTs
	
	----------------------------------------------------------------------------
	tar.bt_info_new.audit_record=vrsn.audit_record__set( tar.func_param->>c_username );

	--> add extra info on audit record if any
	if 	tar.func_param->>c_extra_info is not null then
	
		tar.bt_info_new.audit_record=vrsn.audit_record__set(
				tar.func_param->c_extra_info
			,	c_extraInfo
			,	(tar).bt_info_new.audit_record
		);
	
	end if;
	
			
	----------------------------------------------------------------------------
	--> manage new user date in the far and near past
	----------------------------------------------------------------------------
	if (tar).func_state_var.past_time then
	
		tar=vrsn.__tar_h__user_far_past_handling(tar);
		
	elseif  (tar).func_state_var.near_past_time then

		tar=vrsn.__tar_h__user_near_past_handling(tar);
	
	end if;

	----------------------------------------------------------------------------
	--> Generete new ts range
	----------------------------------------------------------------------------

	tar.bt_info_new.user_ts_range = 
			vrsn.bitemporal_tsrange__create(tar.new_valid_ts);
	tar.bt_info_new.db_ts_range = 
			vrsn.bitemporal_tsrange__create(tar.time_stamp_to_use);

	
	tar.bt_info_old.user_ts_range =
			vrsn.bitemporal_tsrange__close(
					(tar).bt_info_old.user_ts_range
				,	tar.new_valid_ts
			);
	tar.bt_info_old.db_ts_range =
			vrsn.bitemporal_tsrange__close(
					(tar).bt_info_old.db_ts_range
				,	tar.time_stamp_to_use
			);

	----------------------------------------------------------------------------
	--> In same case the record insert isn't ready.
	--> 	Something like a draft version
	--> 	in this case versioning isn't reasonable
	----------------------------------------------------------------------------
	--> if the current record isn't READY versioning is wrong
	if not ((tar).bt_info_old.audit_record->c_extraInfo->>c___IS_READY__)::bool then
		tar.func_state_var.versioning_active=false;
	end if;

	----------------------------------------------------------------------------
	--> Perform data manipulation
	----------------------------------------------------------------------------
	case

	----------------------------------------------------------------------------
	-- Deactivate all
	when (tar).func_state_var.deactivate_all then
		--> nothing to do
		--_updated_oldrec=null;
		updated_newrec=null;
		--updated_oldrec=null;
		return updated_newrec;

	----------------------------------------------------------------------------
	-- Close record	
	when (tar).func_state_var.action_close  then
		--> set closing information
		tar.bt_info_old.audit_record= vrsn.audit_record__close(
				tar.func_param->>c_username
			,	(tar).bt_info_old.audit_record
			,	tar.time_stamp_to_use
			);
		
		--> insert into history table current record
		_sqlStr=vrsn.__tar_h__bind_action(
				tar.actions[c_action_historyInsert]
			,	tar.table_old_rec
		);
		
		execute _sqlStr --into _updated_oldrec 
		using tar.bt_info_old;
		
		--> Delete current record
		_sqlStr=vrsn.__tar_h__bind_action(tar.actions[c_action_runningDelete],tar.table_old_rec);
		execute _sqlStr;

	----------------------------------------------------------------------------
	-- Insert new record with past date
	-- 		it's a particular case
	when (tar).func_state_var.action_mod and (tar).func_state_var.action_new then
	
		--> case past date when user_start_date is previous all existing records
		_sqlStr=vrsn.__tar_h__bind_action(
				tar.actions[c_action_pastDateRunningInsert]
			,	tar.table_new_rec);
		
		--raise notice '%', _sqlStr;
		execute _sqlStr into _updated_newrec using tar.bt_info_new;

	----------------------------------------------------------------------------
	-- Update current record
	-- 	in case of verscioning deactivate, just add touchTs
	when (tar).func_state_var.action_mod then

		if (tar).func_state_var.versioning_active then
			--> insert into history table current record
			_sqlStr=vrsn.__tar_h__bind_action(
					tar.actions[c_action_historyInsert]
				,	tar.table_old_rec
				);
			--raise notice '%', _sqlStr;
			execute _sqlStr --into _updated_oldrec 
			using tar.bt_info_old;
		else
			--> Add last touchTS
			tar.bt_info_new.audit_record= vrsn.audit_record__set(
					tar.time_stamp_to_use
				,	c_touchTs
				,	(tar).bt_info_new.audit_record
				);
				
			--> reuse old TS
			tar.bt_info_new.user_ts_range = (tar).bt_info.user_ts_range;
			tar.bt_info_new.db_ts_range = (tar).bt_info.user_ts_range;
		end if;

		--> update current record
		_sqlStr=vrsn.__tar_h__bind_action(tar.actions[c_action_runningUpdate],tar.table_new_rec);
		--raise notice '%', _sqlStr;
		execute _sqlStr into _updated_newrec using tar.bt_info_new;

	----------------------------------------------------------------------------
	-- Inser new record
	when (tar).func_state_var.action_new then
	
		
--		--raise notice '%', tar.actions[c_action_runningInsert];
		_sqlStr=vrsn.__tar_h__bind_action(tar.actions[c_action_runningInsert],tar.table_new_rec);
		
--		raise notice '%', _sqlStr;
		execute _sqlStr into _updated_newrec using tar.bt_info_new;
--		raise notice 'updated_newrec: %', _updated_newrec;

	----------------------------------------------------------------------------
	-- caso eventuale
	else
		raise exception 'No actions identified for this data';
	end case;
	
	--raise notice 'OK dml';

	----------------------------------------------------------------------------
	--> Populate new and old record to propagate back
	----------------------------------------------------------------------------
/*	
	--> Populate OLD value
	if		(tar).func_state_var.action_close 
		or	(tar).func_state_var.action_mod
	then

		raise notice e'\nold_rec:\n%\n\nupdate old rec:\n%'
			,	tar.wrkn_old_rec
			,	hstore(_updated_oldrec);
			
		updated_oldrec=tar.wrkn_old_rec || hstore(_updated_oldrec);
		
	end if;
	--raise notice 'OK dml';
	*/
	--> Popuate NEW value		
	if		(tar).func_state_var.action_new
		or	(tar).func_state_var.action_mod
	then
		updated_newrec=tar.wrkn_old_rec || hstore(_updated_newrec);
	end if;

	return updated_newrec;

--	raise notice e'updated_newrec: %\n%\n%', updated_newrec,tar.wrkn_old_rec , hstore(_updated_newrec);
END;
$_$;


--
-- Name: __tar_h__prepare_record(vrsn.trigger_activation_record_stack); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__prepare_record(INOUT tar vrsn.trigger_activation_record_stack) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $_$
declare
/*
	inout tar vrsn.trigger_activation_record_stack,

*/

	_rec record;	
	_key text;

	_sqlStr text=$$
		select * 
		from only %1$s
		where %2$s
	$$ ;
	_searchUk	integer=null;
	_load_rec	boolean=null;
	_n		integer;
begin

	tar.status=tar.status || '{"hOldRec":false,"hNewRec":false}'::jsonb;


/*
--	raise notice 'o:<%>',hstore(tar.wrkn_old_rec);
--	raise notice 'n:<%>',hstore(tar.wrkn_new_rec);
	if tar.wrkn_old_rec = null::hstore then
		raise notice 'vuoto';
	end if;
	if tar.wrkn_old_rec <> null::hstore then
		raise notice 'pieno';
	end if;
	if  array_length(akeys(hstore(tar.wrkn_old_rec)), 1) > 0 then
		raise notice 'pieno a';
	end if;
*/	

	----------------------------------------------------------------------------
	--> if the onDupKey option is active
	--> Func looks for an existing record searching for all the unique index
	--> if one record is found the function swithes to update
	--> if more of one record is found, raise an error
	-----------------------------------------------------------------------------

	-----------------------------------------------------------------------------
	-->determines if load record
	-----------------------------------------------------------------------------
	if ((tar).func_state_var.action_new) then
		if 		(tar).func_state_var.on_dup_key_update 
			or	(tar).func_state_var.on_dup_key_exit  
		then

			-->use all uk indexes
			_searchUk=null;
			_load_rec=true;
		else
			_load_rec=false;
		end if;
	else
		_load_rec=true;
		--> use only primary key
		_searchUk=0;
	end if;

	-----------------------------------------------------------------------------
	--> Load previous record
	-----------------------------------------------------------------------------
	
	--> if is set old rec get information from the table and join with data caming from trigger
	if  _load_rec then
	
		if (tar).func_state_var.lock_main_table then
			_sqlStr =_sqlStr || $$
			for update
			$$;
		end if;

		_sqlStr=format(_sqlStr
				,		vrsn.__entity_fullname_type__to_ident( 
							tar.current_table_full_name 
						)
				,		vrsn.jsonb_table_structure__get_uk_where
						(	tar.wrkn_new_rec
						,	tar.current_entity_columns_list
						,	tar.unique_index_list
						,	_searchUk
						)
				);

			
/*		
			_sqlStr=format(_sqlStr, tar.name_of_schema, tar.main_table
					   , vrsn.jsonb_table_structure__get_pk_where(tar.wrkn_old_rec, tar.current_entity_columns_list));
*/		
--		raise notice '%',_sqlStr;

		begin
			execute _sqlStr into strict _rec;
	--		raise notice '%',_rec;
			
			tar.table_old_rec=(tar.table_old_rec || tar.wrkn_old_rec ) || hstore(_rec);
			
			tar.bt_info=tar.table_old_rec[tar.bt_info_name]::vrsn.bitemporal_record;
	
			tar.status['hOldRec']=to_jsonb(true);

		exception
			when NO_DATA_FOUND then
				null;
--raise notice 'sqlstr: %', _sqlStr;
--raise notice e'\ntar configuration\n%', jsonb_pretty(to_jsonb(tar));
--			raise exception'doh!'	;
			WHEN TOO_MANY_ROWS THEN
				raise exception 'Data refers to many records';
		end;
		

	end if;	
	
	-----------------------------------------------------------------------------
	-- Prepare new record
	-----------------------------------------------------------------------------


	----------------------------------------------------------------------------
	--> if is set tar.wrkn_new_rec I set data on structure
	if  (tar).func_state_var.action_new or (tar).func_state_var.action_mod then

		-------------------------------------------------------------------------
		--> if ignore_null_on_update
		--		start from old record  table
		--		and strip nulls key
		if (tar).func_state_var.ignore_null_on_update and (tar.status->>'hOldRec')::bool then

			--> set old values
			foreach _key in array akeys(tar.table_old_rec) loop
				if exist(tar.table_new_rec,_key) then
					tar.table_new_rec[_key]=tar.table_old_rec[_key];
				end if;
			end loop;
			--> remove empty values
			tar.wrkn_new_rec=common.hstore_strip_nulls(tar.wrkn_new_rec);
		end if;
		/*	
		_hs=(tar.wrkn_new_rec);
		foreach _key in array akeys(tar.wrkn_new_rec) loop
			if exist(tar.wrkn_new_rec,_key) then
				tar.table_new_rec[_key]=tar.wrkn_new_rec[_key];
			end if;
		end loop;
		*/
		--tar.table_new_rec=tar.table_new_rec|| tar.wrkn_new_rec;

		--> overwrite / insert new values
		foreach _key in array akeys(tar.wrkn_new_rec) loop
		
			--> Evaluate if there is a default value for null value
			if 		tar.wrkn_new_rec[_key] is null 
				and	tar.current_entity_columns_list[_key]->>'generated'='on_null'
			then

				tar.table_new_rec[_key] = vrsn.get_resolved_default_value(
					tar.current_entity_columns_list[_key]->>'default_value'
				) ;
				--tar.table_new_rec[_key]=tar.current_entity_columns_list[_key]['default_value'];
			elseif	tar.table_new_rec[_key] 
					is distinct from
					tar.wrkn_new_rec[_key]
			then
			
				tar.table_new_rec[_key] = tar.wrkn_new_rec[_key];
				tar.func_state_var.found_changed_value=true;
				
			end if;
/*
			raise notice 'key: %, generated: %, w_current: %, default: %, resolved default:% --> t_curr: %'
					, _key
					, tar.current_entity_columns_list[_key]->>'generated'
					, tar.wrkn_new_rec[_key]
					, tar.current_entity_columns_list[_key]->>'default_value'
					, vrsn.get_resolved_default_value(tar.current_entity_columns_list[_key]->>'default_value')
					, tar.table_new_rec[_key]
					;
				
*/
		end loop;

		
		tar.status=tar.status || '{"hNewRec":true}'::jsonb;

--raise  notice '%', (tar.unique_index_list)->0;
		-- If there is tar.wrkn_old_rec
		-- looking for tar.wrkn_new_rec pk's empty fields and replace with old one
		if (tar.status->>'hOldRec')::bool then
			-- loop on pk
			for _key in 
				select * from jsonb_array_elements_text((tar.unique_index_list)->0->'fields')
			loop
				if tar.table_new_rec[_key] is null then
--					raise  notice '%', _key;
					tar.table_new_rec[_key]=tar.table_old_rec[_key];
				end if;
			end loop;
		end if;

	else
		tar.status['hNewRec']=to_jsonb(true);
	end if;
--raise notice e'%\n%\n%', jsonb_pretty(tar.status) 	, tar.table_old_rec 	, tar.table_new_rec;

	------------------------------------------------------------------------------
	--> Start evaluation of newTS
	--> could be
	--> new standard ts
	--> ts in the far past
	--> ts in the near past
	--> ts in future (exception)
	------------------------------------------------------------------------------
	
	-->retrieve valid_ts if any
	if not common.is_empty(tar.wrkn_new_rec[tar.func_param->>'t_modify_ts']) then

		tar.new_valid_ts=tar.wrkn_new_rec[tar.func_param->>'t_modify_ts']::timestamptz;

		--> if it's reqired a valid ts versioning must be acive
		tar.func_state_var.versioning_active=true;

		raise notice 'pd: % < % = %',tar.new_valid_ts, lower((tar).bt_info_old.user_ts_range), (tar.new_valid_ts < lower((tar).bt_info_old.user_ts_range)) ;

		----------------------------------------------------------------------------------
		--> New valid TS is previous the user_ts_sart of current record
		if tar.new_valid_ts < lower((tar).bt_info.user_ts_range) then

			raise notice 'Modifica antecedente record corrente';
		
			tar.func_state_var.past_time= true;

		----------------------------------------------------------------------------------
		--> New valid TS in the future
		elseif tar.new_valid_ts > tar.time_stamp_to_use then
		
			--tar.func_state_var.futureDate = true;
			raise exception 'Future date isn''t allowed';

		----------------------------------------------------------------------------------
		--> No change is happening, so no matter about new TS
		elseif	(tar).func_state_var.ignore_unchanged_values
			and	not	(tar).func_state_var.found_changed_value
		then
			null;
		----------------------------------------------------------------------------------
		--> New valid TS is between now and some hours ago (hours_for_nearPastTime)
		elseif  tstzrange(tar.new_valid_ts, tar.new_valid_ts  + INTERVAL '1  hours' * (tar.func_param->>'hours_for_nearPastTime')::int,'[)')  @> tar.time_stamp_to_use then

			------------------------------------------------------------------------------
			--> check if there already are some history records with db_ts_start  prior tar.new_valid_ts
			execute vrsn.__tar_h__bind_action(
						tar.actions['historySearchByDate']
					,	tar.table_old_rec) 
					into _n
					using tar.new_valid_ts
			;
			--raise notice 'Number of history record with db_start_date > % is %', tar.new_valid_ts, _n ;

			------------------------------------------------------------------------------
			--> there are previous record with tar.new_valid_ts in user_ts_range 
			if _n > 0 then

				raise notice 'Trovati record esistenti';
				tar.func_state_var.past_time= true;
				
			------------------------------------------------------------------------------	
			--> there aren't previous record with db_ts_start > tar.new_valid_ts
			--> but is near real time
			elseif  tstzrange(
						tar.new_valid_ts
					,	tar.new_valid_ts  
						+ INTERVAL '1  second' * (tar.func_param->>'seconds_for_nearRealTime')::int
					,'[)')  @> tar.time_stamp_to_use
			then
				null;
				
			------------------------------------------------------------------------------
			--> no previous rec and new valid ts previous seconds_for_nearRealTime ago
			else
			
				tar.func_state_var.near_past_time=true;
				
			end if;
		----------------------------------------------------------------------------------
		-- if new date is outside near past date 
		else
			tar.func_state_var.past_time= true;
		end if;
	end if;

	


	--> Se il TS è nel passato non può esserci un unchanged value
	if (tar).func_state_var.near_past_time or (tar).func_state_var.past_time then
		tar.func_state_var.ignore_unchanged_values=false;
		tar.func_state_var.found_changed_value=true;
	--> Menage conflict of timestamp
	elseif tar.new_valid_ts <= lower((tar).bt_info.user_ts_range) then
		if (tar).func_state_var.mitigate_conflicts then
			tar.new_valid_ts = lower((tar).bt_info.user_ts_range) + (interval '1 second'/10);
		else
			raise exception 'New user timespamp <%> conflits with the preiovus one.', tar.new_valid_ts;
		end if;
		
	end if;

	tar.bt_info_old=tar.bt_info;
end;
$_$;


--
-- Name: trigger_activation_record_stack_trace_parent; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE UNLOGGED TABLE vrsn.trigger_activation_record_stack_trace_parent (
    trx_id xid8,
    rec_id bigint NOT NULL,
    trace_ts timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    call_trace text
)
INHERITS (vrsn.trigger_activation_record_stack);


--
-- Name: __tar_h__trace(vrsn.trigger_activation_record_stack_trace_parent); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__trace(tar vrsn.trigger_activation_record_stack_trace_parent) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
--	INOUT tar vrsn.trigger_activation_record)

begin
	----------------------------------------------------------------------------
	-- assegno transazione se assegnata
	tar.trx_id = pg_current_xact_id_if_assigned();

	tar.call_trace = common.get_diagnostic_text(1);

	tar.trace_ts =clock_timestamp();

	case extract(month from tar.trace_ts)%4
	when 0 then
		insert into vrsn.trigger_activation_record_stack_trace_p00
		select tar.*;
	when 1 then
		insert into vrsn.trigger_activation_record_stack_trace_p01
		select tar.*;
	when 2 then
		insert into vrsn.trigger_activation_record_stack_trace_p02
		select tar.*;
	when 3 then
		insert into vrsn.trigger_activation_record_stack_trace_p03
		select tar.*;
	end case;
	
	return;

end;
$$;


--
-- Name: __tar_h__user_far_past_handling(vrsn.trigger_activation_record_stack); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__user_far_past_handling(INOUT tar vrsn.trigger_activation_record_stack) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $$
declare
--	INOUT tar vrsn.trigger_activation_record_stack)

	---------------
	-- constant
	c_username							constant	text=	'username';

	c_action_runningTouch				constant	text=	'runningTouch';
	c_action_runningUpdate				constant	text=	'runningUpdate';
	c_action_runningInsert				constant	text=	'runningInsert';
	c_action_runningDelete				constant	text=	'runningDelete';
	c_action_pastDateRunningInsert		constant	text=	'pastDateRunningInsert';
	c_action_historyInsert				constant	text=	'historyInsert';
	c_action_pastDateHistoryReOpen		constant	text=	'pastDateHistoryReOpen';
	c_action_pastDateHistoryDeactivate	constant	text=	'pastDateHistoryDeactivate';
	c_action_historySearchByDate		constant	text=	'historySearchByDate';

	
	_rec								record;
--	_updated_oldrec						record;
--	_updated_newrec						record;
	_sqlStr								text;
begin

--> Add touch ts, not needed because part of default attributes
--tar.bt_info_old.audit_record=vrsn.audit_record__set(tar.time_stamp_to_use,'touchTs',tar.bt_info_old.audit_record);			

	----------------------------------------------------------------------------
	--> close period
	----------------------------------------------------------------------------
	tar.bt_info_old.user_ts_range=vrsn.bitemporal_tsrange__close( 
				(tar).bt_info_old.user_ts_range
			,	tar.time_stamp_to_use);
				
	tar.bt_info_old.db_ts_range=vrsn.bitemporal_tsrange__close(
				(tar).bt_info_old.db_ts_range
			,	tar.time_stamp_to_use);

	----------------------------------------------------------------------------
	--> insert into history table current record
	--> with closing period
	----------------------------------------------------------------------------
	_sqlStr=vrsn.__tar_h__bind_action(tar.actions[c_action_historyInsert]
			, tar.table_old_rec);
	--raise notice '%', _sqlStr;
	execute _sqlStr --into _updated_oldrec 
	using tar.bt_info_old;

	----------------------------------------------------------------------------
	--> delete current record
	----------------------------------------------------------------------------
	_sqlStr=vrsn.__tar_h__bind_action(tar.actions[c_action_runningDelete]
			,tar.table_old_rec);
	--raise notice '%', _sqlStr;
	execute _sqlStr;

	----------------------------------------------------------------------------
	--> insert into main table the record contain tar.new_valid_ts with some change:
		-- user_ts_end is infinity
		-- db_ts_start is now
	--> in the next steps this record will be closed in the standard way
	--> In other words now, this closed record, must be reopen, then close with tar.new_valid_ts as user_ts_end
	--> pay attention, this insert could be no record satisfy the conditions
	----------------------------------------------------------------------------
	_sqlStr = vrsn.__tar_h__bind_action(
			tar.actions[c_action_pastDateHistoryReOpen]
		,	tar.table_old_rec
	);
	--raise notice '%', _sqlStr;

	----------------------------------------------------------------------------
	--> Search for active record includes tar.new_valid_ts
	--> reopen with db_start=tar.time_stamp_to_use
	--> use _rec as temp variable
	----------------------------------------------------------------------------
	execute _sqlStr into _rec  
	using tar.new_valid_ts
		,	tar.time_stamp_to_use
		,	 (tar.func_param->>'username');
	
--		--raise notice '%',tar.bt_info_old;

	----------------------------------------------------------------------------
	--> replace oldrec with newer		
	----------------------------------------------------------------------------
	tar.wrkn_old_rec = hstore(_rec);
	tar.bt_info_old= tar.wrkn_old_rec[tar.bt_info_name];
	--raise notice 'test clone % % %', _rec,tar.wrkn_old_rec,tar.bt_info_old;
	
	----------------------------------------------------------------------------
	--> Deactivate previous records
	----------------------------------------------------------------------------
	_sqlStr=vrsn.__tar_h__bind_action(
			tar.actions[c_action_pastDateHistoryDeactivate]
		,	tar.table_old_rec);
	
	--raise notice '%', _sqlStr;
	execute _sqlStr using tar.new_valid_ts
			,	tar.time_stamp_to_use
			,	(tar.func_param->>c_username);

	----------------------------------------------------------------------------
	-- Generate new behavior:
	-- if tar.bt_info_old is null means previous insert no found record
	--		if action_close is active
	--			if it's allowed to close every record -> ok
	--			else raise exception
	--		else allow past date insert
	-- else just create new timestamp to use	
	----------------------------------------------------------------------------
	--> if tar.bt_info_old is null means previous insert no found record, this means we have to just insert a new record
	if tar.bt_info_old is null then
		if (tar).func_state_var.action_close then
			if (tar).func_state_var.allow_full_deactivation_by_past_close_ts then
				tar.func_state_var.deactivate_all=true;
				tar.func_state_var.action_new=false;
			else
				raise exception 'The closing date must be greater the first date of the record';
			end if;
		else
			tar.func_state_var.action_new=true;
		end if;
		
		--> set null _updated_oldrec
--		_updated_oldrec=_rec;
	else
		--> generate new tar.time_stamp_to_use
		--> because we need to close reopen record
		tar.time_stamp_to_use = clock_timestamp();
	end if;

end;
$$;


--
-- Name: __tar_h__user_near_past_handling(vrsn.trigger_activation_record_stack); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.__tar_h__user_near_past_handling(INOUT tar vrsn.trigger_activation_record_stack) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $$
declare
--	INOUT tar vrsn.trigger_activation_record_stack)
	---------------
	-- constant
	c_actualCloseTs						constant	text=	'actualCloseTs';
	c_actualInsertTs					constant	text=	'actualInsertTs';

begin

		--> manage date new valid date in the near past
		--> this usecase is useful for bulk asyncronous update
		--> we assume the db_ts_start=user_ts_start=tar.new_valid_ts
		--> but in audit record we memorize the actual timestamp of the update
		tar.bt_info_old.audit_record=vrsn.audit_record__set(
				tar.time_stamp_to_use
			,	c_actualCloseTs
			,	(tar).bt_info_old.audit_record);
				
		tar.bt_info_new.audit_record=vrsn.audit_record__set(
				tar.time_stamp_to_use
			,	c_actualInsertTs
			,	(tar).bt_info_new.audit_record);
			
		tar.time_stamp_to_use=tar.new_valid_ts;
		
end;
$$;


--
-- Name: _d_jsonb_table_structure__build(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn._d_jsonb_table_structure__build(name_of_table text, name_of_schema text DEFAULT 'public'::text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    BEGIN ATOMIC
 WITH tbl AS (
          SELECT _d_jsonb_table_structure__build.name_of_schema AS sn,
             _d_jsonb_table_structure__build.name_of_table AS tn
         ), clm AS (
          SELECT cs.table_schema,
             cs.table_name,
             cs.column_name AS cn,
                 CASE
                     WHEN (cs.domain_name IS NOT NULL) THEN (((cs.domain_schema)::text || '.'::text) || (cs.domain_name)::text)
                     WHEN ((cs.data_type)::text = 'ARRAY'::text) THEN ((((cs.udt_schema)::text || '.'::text) || "substring"((cs.udt_name)::text, 2)) || '[]'::text)
                     WHEN ((cs.data_type)::text <> 'USER-DEFINED'::text) THEN (cs.data_type)::text
                     ELSE (((cs.udt_schema)::text || '.'::text) || (cs.udt_name)::text)
                 END AS ct,
                 CASE
                     WHEN (((cs.is_identity)::text = 'YES'::text) AND ((cs.identity_generation)::text = 'BY DEFAULT'::text)) THEN 'default'::text
                     WHEN (((cs.is_identity)::text = 'YES'::text) AND ((cs.identity_generation)::text = 'ALWAYS'::text)) THEN 'identity'::text
                     WHEN ((cs.is_generated)::text = 'ALWAYS'::text) THEN 'always'::text
                     WHEN (((cs.is_nullable)::text = 'NO'::text) AND (cs.column_default IS NOT NULL)) THEN 'on_null'::text
                     ELSE ''::text
                 END AS cg,
             cs.ordinal_position,
             cs.column_default
            FROM (tbl
              JOIN information_schema.columns cs ON ((((cs.table_schema)::name = tbl.sn) AND ((cs.table_name)::name = tbl.tn))))
           ORDER BY cs.ordinal_position
         ), pk AS (
          SELECT cu.column_name AS cn,
             cu.ordinal_position
            FROM ((tbl
              JOIN information_schema.table_constraints tc ON ((((tc.table_schema)::name = tbl.sn) AND ((tc.table_name)::name = tbl.tn))))
              JOIN information_schema.key_column_usage cu ON (((tc.constraint_name)::name = (cu.constraint_name)::name)))
           WHERE ((tc.constraint_type)::text = 'PRIMARY KEY'::text)
         ), j1 AS (
          SELECT l.cn,
             json_build_object('type', l.ct, 'generated', l.cg, 'pk',
                 CASE
                     WHEN (pk.cn IS NULL) THEN false
                     ELSE true
                 END, 'pk_order',
                 CASE
                     WHEN (pk.cn IS NULL) THEN NULL::integer
                     ELSE (pk.ordinal_position)::integer
                 END, 'default_value', l.column_default, 'field_order', l.ordinal_position) AS obj
            FROM (clm l
              LEFT JOIN pk ON (((l.cn)::name = (pk.cn)::name)))
           ORDER BY l.ordinal_position
         )
  SELECT jsonb_object_agg(j1.cn, j1.obj) AS jsonb_object_agg
    FROM j1;
END;


--
-- Name: admin__bitemporal_entity_register(jsonb, boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__bitemporal_entity_register(p_conf jsonb, p_execute boolean DEFAULT false) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
/*
	IN p_conf jsonb,
	IN p_execute boolena default false)
	RETURNS text
*/
    v_result		text;
	v_conf			jsonb;
BEGIN

	----------------------------------------------------------------------------------------
	--	Normalizzo input
	CASE jsonb_typeof(p_conf)
    WHEN 'array' THEN
		null;
	WHEN 'object' THEN 
		p_conf = jsonb_build_array(p_conf);
	ELSE
		raise exception 'Input does not seem to be an object or an array';
	END case;



	----------------------------------------------------------------------------------------
	--	Itero sugli elementi
	for v_conf in select jsonb_array_elements(p_conf)loop
	
	    v_result :=e'\n------------------------------------\n\n'
			|| __bitemporal_entity__build_ddl(v_conf);
			
	end loop;

	----------------------------------------------------------------------------------------
	--	if not p_execute just return sql
	if not p_execute then
		RETURN v_result;	
	end if;


	----------------------------------------------------------------------------------------
	--	Executing
	execute v_result;
	
    RETURN e'-----Executed------\n\n\n' || v_result;
END;
$$;


--
-- Name: FUNCTION admin__bitemporal_entity_register(p_conf jsonb, p_execute boolean); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.admin__bitemporal_entity_register(p_conf jsonb, p_execute boolean) IS 'You can pass an object in the format of admin__get_bitemporal_entity_conf_param
or an jsonb array of the same element.

With this method you can define many parameters for each entity';


--
-- Name: admin__bitemporal_entity_register(text, text, boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__bitemporal_entity_register(p_current_table_schema text, p_current_table_name text, p_execute boolean DEFAULT false) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
/*
	IN p_current_table_schema text,
	IN p_current_table_name text,
	IN p_execute boolena default false)
	RETURNS text
*/
    v_result		text;
	v_jb			jsonb='{   "current_table": {
								    "table_name": "",
								    "schema_name": ""
							  }
							}'::jsonb;
BEGIN

	v_jb['current_table']['schema_name']	=	to_jsonb(p_current_table_schema);
	v_jb['current_table']['table_name']		=	to_jsonb(p_current_table_name);
	

		
    -- Chiamiamo la funzione sottostante di vrsn, passando i parametri nominativamente.
    v_result := __bitemporal_entity__build_ddl(jb);

	if not p_execute then
		RETURN v_result;	
	end if;

	execute v_result;
	
    RETURN e'-----Executed------\n\n\n' || v_result;
END;
$$;


--
-- Name: FUNCTION admin__bitemporal_entity_register(p_current_table_schema text, p_current_table_name text, p_execute boolean); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.admin__bitemporal_entity_register(p_current_table_schema text, p_current_table_name text, p_execute boolean) IS 'Easiast way to register a bitemporal table.
All the parameters as streatda in standard way.
';


--
-- Name: admin__entity_change_behavior(text, text, text, vrsn.historice_entity_behaviour, boolean, text, text, boolean, boolean, boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__entity_change_behavior(p_entity_schema text, p_entity_name text, p_modify_user_id text, p_historice_entity vrsn.historice_entity_behaviour DEFAULT NULL::vrsn.historice_entity_behaviour, p_enable_history_attributes boolean DEFAULT NULL::boolean, p_main_fields_list text DEFAULT NULL::text, p_cached_fields_list text DEFAULT NULL::text, p_mitigate_conflicts boolean DEFAULT NULL::boolean, p_ignore_unchanged_values boolean DEFAULT NULL::boolean, p_enable_attribute_to_fields_replacement boolean DEFAULT NULL::boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Chiamiamo la funzione sottostante di vrsn, passando i parametri nominativamente.
    -- I nomi a destra del ":=" sono i nomi dei parametri della funzione wrapper.
    PERFORM vrsn.bitemporal_entity__change(
        p_entity_schema := p_entity_schema,
        p_entity_name := p_entity_name,
        p_modify_user_id := p_modify_user_id,
        p_historice_entity := p_historice_entity,
        p_enable_history_attributes := p_enable_history_attributes,
        p_main_fields_list := p_main_fields_list,
        p_cached_fields_list := p_cached_fields_list,
        p_mitigate_conflicts := p_mitigate_conflicts,
        p_ignore_unchanged_values := p_ignore_unchanged_values,
        p_enable_attribute_to_fields_replacement := p_enable_attribute_to_fields_replacement
    );
END;
$$;


--
-- Name: admin__get_bitemporal_entity_conf_param(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__get_bitemporal_entity_conf_param() RETURNS TABLE(input_example jsonb, json_schema jsonb)
    LANGUAGE sql
    AS $$
select
	vrsn.parameters__get('bitemporal_entity','external_input') as input_example
,	vrsn.parameters__get('bitemporal_entity','json_schema') as json_schema
;
$$;


--
-- Name: FUNCTION admin__get_bitemporal_entity_conf_param(); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.admin__get_bitemporal_entity_conf_param() IS 'Retrieve a  TABLE(input_example jsonb, json_schema jsonb)
With an input example and relative json_schema

Plese, remove all null parameters';


--
-- Name: admin__init(boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__init(only_get_query boolean) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
	v_sql_str	 text=$$
--> empty tables
	truncate table only vrsn.test_table_history;
	truncate table only vrsn.test_table_current restart identity ;
	truncate table only vrsn.test_table_attribute_current restart identity;
	truncate table only vrsn.test_table_attribute_history;	
	truncate table only vrsn.test_table_check_run restart identity;
	truncate table only vrsn.test_table_check_run_detail restart identity;
	truncate table only vrsn.test_table_check_run_attribute_detail restart identity;

	truncate table only vrsn.trigger_activation_record_base restart identity;
	truncate table only vrsn.trigger_activation_record_stack restart identity;

	truncate table only trigger_activation_record_base_changelog restart identity;
	truncate table only trigger_activation_record_stack_trace_p00 restart identity;
	truncate table only trigger_activation_record_stack_trace_p01 restart identity;
	truncate table only trigger_activation_record_stack_trace_p02 restart identity;
	truncate table only trigger_activation_record_stack_trace_p03 restart identity;

	truncate table only def_entity_behavior_current restart identity;
	truncate table only def_entity_behavior_history restart identity;
	truncate table only attribute_lineage_current restart identity;
	truncate table only attribute_lineage_history restart identity;
	truncate table only attribute_mapping_to_entity_current restart identity;
	truncate table only attribute_mapping_to_entity_history restart identity;
	truncate table only parameter_current restart identity;
	truncate table only parameter_history restart identity;


INSERT INTO vrsn.def_entity_behavior_current VALUES
	('("[""2025-08-27 01:47:04.813292+02"",infinity)","[""2025-08-27 01:47:04.813292+02"",infinity)","{""process"": ""vrsn.register""}")', '(vrsn,def_entity_behavior)', '(vrsn,def_entity_behavior)', '(vrsn,def_entity_behavior_current)', '(vrsn,def_entity_behavior_history)', '(,)', 'always', false, NULL, NULL, true, true, false, NULL),
	('("[""2025-08-27 10:27:05.83773+02"",infinity)","[""2025-08-27 10:27:05.83773+02"",infinity)","{""process"": ""vrsn.register""}")', '(vrsn,parameter)', '(vrsn,parameter)', '(vrsn,parameter_current)', '(vrsn,parameter_history)', '(,)', 'always', false, NULL, NULL, true, true, false, NULL),
	('("[""2025-08-27 10:28:01.115262+02"",infinity)","[""2025-08-27 10:28:01.115262+02"",infinity)","{""process"": ""vrsn.register""}")', '(vrsn,attribute_mapping_to_entity)', '(vrsn,attribute_mapping_to_entity)', '(vrsn,attribute_mapping_to_entity_current)', '(vrsn,attribute_mapping_to_entity_history)', '(,)', 'always', false, NULL, NULL, true, true, false, NULL),
	('("[""2025-08-27 10:28:30.986994+02"",infinity)","[""2025-08-27 10:28:30.986994+02"",infinity)","{""process"": ""vrsn.register""}")', '(vrsn,attribute_lineage)', '(vrsn,attribute_lineage)', '(vrsn,attribute_lineage_current)', '(vrsn,attribute_lineage_history)', '(,)', 'always', false, NULL, NULL, true, true, false, NULL);



INSERT INTO vrsn.parameter_current VALUES
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'trace', 'list', 'last stack trace truncate
new date for truncate', '{"last_ts": null, "next_ts": null, "last_partition": null}'),
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'field_type', 'config', 'behavior of specific fields', '{"vrsn.cached_attribute": {"null_on_history": true}}'),
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'tar', 'config', 'constant, parameters, state_var defaults', '{"params": {"t_dbTs": "dbTs", "t_closed": "is_closed", "username": null, "extraInfo": null, "t_onDupKey": "onDupKey", "t_onUpdate": "onUpdate", "t_username": "modify_user_id", "t_modify_ts": "modify_ts", "t_versioning": "versioning", "t_action_hints": "action_hints", "tar_week_to_live": 10, "versioning_active": "cipolla", "t_onUnchangedValue": "onUnchangedValue", "t_versioning_c_off": "off", "t_onDupKey_c_update": "update", "hours_for_nearPastTime": 3, "t_onDupKey_c_doNothing": "do nothing", "seconds_for_nearRealTime": 5, "t_onUpdate_c_ignoreNulls": "ignore nulls", "t_onUnchangedValue_c_touch": "touch", "t_onUnchangedValue_c_update": "update", "t_onUnchangedValue_c_discard": "discard", "t_allowFullDeactivationByPastCloseTs": "allowFullDeactivationByPastCloseTs"}, "state_variables": {"is_ready": true, "tar_changelog": true, "versioning_active": true, "mitigate_conflicts": true, "ignore_unchanged_values": true}}'),
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'bitemporal_entity', 'inner_conf', 'Configuration param managed internally', '{"entity": {"table_name": null, "schema_name": null}, "version": null, "structure": {}, "current_pk": [], "history_pk": [], "bt_info_name": null, "current_view": {"table_name": null, "schema_name": null}, "current_table": {"table_name": null, "schema_name": null}, "history_table": {"table_name": null, "schema_name": null}, "attribute_entity": {"table_name": null, "schema_name": null}, "historice_entity": null, "main_fields_list": null, "bitemporal_fields": [], "cached_fields_list": null, "mitigate_conflicts": true, "ignore_unchanged_values": true, "enable_history_attributes": false, "enable_attribute_to_fields_replacement": false}'),
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'bitemporal_entity', 'external_input', 'Configuration param used to call function', '{"entity": {"table_name": null, "schema_name": null}, "current_view": {"table_name": null, "schema_name": null}, "current_table": {"table_name": null, "schema_name": null}, "history_table": {"table_name": null, "schema_name": null}, "attribute_entity": {"table_name": null, "schema_name": null}, "historice_entity": "always", "main_fields_list": null, "cached_fields_list": null, "mitigate_conflicts": true, "ignore_unchanged_values": true, "enable_history_attributes": false, "enable_attribute_to_fields_replacement": false}'),
	('("[""2025-07-10 23:39:40.079853+02"",infinity)","[""2025-07-10 23:39:40.079853+02"",infinity)","{""process"": ""vrsn.init""}")', 'bitemporal_entity', 'json_schema', 'jsonSchema for input', '{"type": "object", "title": "Entity Configuration Schema", "$schema": "http://json-schema.org/draft-07/schema#", "required": ["current_table"], "properties": {"entity": {"$ref": "#/definitions/table_reference", "description": "Definizione dell''entità principale"}, "current_view": {"$ref": "#/definitions/table_reference", "description": "Vista corrente dell''entità"}, "current_table": {"$ref": "#/definitions/table_reference", "description": "Tabella corrente dell''entità"}, "history_table": {"$ref": "#/definitions/table_reference", "description": "Tabella storica dell''entità"}, "attribute_entity": {"$ref": "#/definitions/table_reference", "description": "Entità degli attributi"}, "historice_entity": {"enum": ["on_main_fields", "never", "always"], "type": "string", "description": "Strategia per la gestione della storicizzazione dell''entità"}, "main_fields_list": {"type": ["string", "null"], "pattern": "^([a-zA-Z_][a-zA-Z0-9_]*(\\s*,\\s*[a-zA-Z_][a-zA-Z0-9_]*)*)?$", "description": "Lista dei campi principali separati da virgole, oppure null"}, "cached_fields_list": {"type": ["string", "null"], "pattern": "^([a-zA-Z_][a-zA-Z0-9_]*(\\s*,\\s*[a-zA-Z_][a-zA-Z0-9_]*)*)?$", "description": "Lista dei campi in cache separati da virgole, oppure null"}, "mitigate_conflicts": {"type": "boolean", "description": "Flag per attivare la mitigazione dei conflitti"}, "ignore_unchanged_values": {"type": "boolean", "description": "Flag per ignorare i valori non modificati"}, "enable_history_attributes": {"type": "boolean", "description": "Flag per abilitare gli attributi storici"}, "enable_attribute_to_fields_replacement": {"type": "boolean", "description": "Flag per abilitare la sostituzione degli attributi con i campi"}}, "definitions": {"table_reference": {"type": "object", "required": ["table_name", "schema_name"], "properties": {"table_name": {"type": ["string", "null"], "description": "Nome della tabella"}, "schema_name": {"type": ["string", "null"], "description": "Nome dello schema"}}, "description": "Riferimento a una tabella con schema e nome", "additionalProperties": false}}, "description": "Schema per la configurazione di entità con supporto per tabelle storiche e attributi", "additionalProperties": false}');

$$;
begin

	if only_get_query then	
		return v_sql_str;	
	end if;

	execute v_sql_str;

	return e'Executing:\n\n' || v_sql_str;

end;$_$;


--
-- Name: FUNCTION admin__init(only_get_query boolean); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.admin__init(only_get_query boolean) IS 'Destructive method.
Use only when you want to regenerate a clean configuration.';


--
-- Name: admin__insert_global_attribute(text, text, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__insert_global_attribute(p_attribute_name text, p_modify_user_id text, p_json_schema_plus jsonb DEFAULT NULL::jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
/*
	in p_attribute_name text,
	in p_modify_user_id text,
	in p_json_schema_plus jsonb default null
	returns bigint
*/
	t_username text;
	v_sql text;
	v_new_id bigint;
begin
	-- verifica duplicati (schema_name/entity_name null)
	if exists (
		select 1
		from vrsn.attribute_lineage al
		where al.attribute_name = p_attribute_name
		  and al.schema_name is null
		  and al.entity_name is null
	) then
		raise exception 'Esiste già un attributo globale con nome %', p_attribute_name;
	end if;

	-- recupera colonna modify_user_id
	select coalesce(
		vrsn.parameters__get_value('tar', 'params.t_username') #>>'{}',
		'modify_user_id'
	)
	into t_username;

	-- insert dinamica
	v_sql := format(
		'insert into vrsn.attribute_lineage (attribute_name, schema_name, entity_name, json_schema_plus, %I)
		 values ($1, null, null, $2, $3)
		 returning attribute_id',
		t_username
	);

	execute v_sql
	into v_new_id
	using p_attribute_name, p_json_schema_plus, p_modify_user_id;

	return v_new_id;
end;
$_$;


--
-- Name: admin__insert_local_attribute(text, text, text, text, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__insert_local_attribute(p_attribute_name text, p_schema_name text, p_entity_name text, p_modify_user_id text, p_json_schema_plus jsonb DEFAULT NULL::jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
/*
	in p_attribute_name text,
	in p_schema_name text,
	in p_entity_name text,
	in p_modify_user_id text,
	in p_json_schema_plus jsonb default null
	returns bigint
*/
	t_username text;
	v_sql text;
	v_new_id bigint;
begin
	-- verifica che schema_name.entity_name sia una vista
	if not exists (
		select 1
		from pg_catalog.pg_class c
		join pg_catalog.pg_namespace n on n.oid = c.relnamespace
		where n.nspname = p_schema_name
		  and c.relname = p_entity_name
		  and c.relkind = 'v'
	) then
		raise exception '%.% non esiste o non è una vista', p_schema_name, p_entity_name;
	end if;

	-- verifica duplicati
	if exists (
		select 1
		from vrsn.attribute_lineage al
		where al.attribute_name = p_attribute_name
		  and al.schema_name = p_schema_name
		  and al.entity_name = p_entity_name
	) then
		raise exception 'Esiste già un attributo locale % per %.%', p_attribute_name, p_schema_name, p_entity_name;
	end if;

	-- recupera colonna modify_user_id
	select coalesce(
		vrsn.parameters__get_value('tar', 'params.t_username') #>>'{}',
		'modify_user_id'
	)
	into t_username;

	-- insert dinamica
	v_sql := format(
		'insert into vrsn.attribute_lineage (attribute_name, schema_name, entity_name, json_schema_plus, %I)
		 values ($1, $2, $3, $4, $5)
		 returning attribute_id',
		t_username
	);

	execute v_sql
	into v_new_id
	using p_attribute_name, p_schema_name, p_entity_name, p_json_schema_plus, p_modify_user_id;

	return v_new_id;
end;
$_$;


--
-- Name: admin__readme(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__readme() RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT 'Package wrapper for user.
 Every function thought to be used for a user is wrapped in this package.
 If you wish to add functionallity... probabily you''re wrong....
'::text AS text;
END;


--
-- Name: admin__reserve_attribute(bigint, text, text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.admin__reserve_attribute(p_attribute_id bigint, p_schema_name text, p_entity_name text, p_modify_user_id text) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$declare
/*
	IN p_attribute_id bigint, 
	IN p_schema_name text, 
	IN p_entity_name text)
	in p_modify_user_id text
    RETURNS boolean
*/

    t_username text;
    v_sql text;
    v_dummy int;
begin
    -- 1) verifica esistenza dell'attribute_id (usa from)
	/*
    select 1
    into v_dummy
    from vrsn.attribute_lineage al
    where al.attribute_id = p_attribute_id
    limit 1;

    if not found then
    end if;
*/
    -- 2) verifica che schema_name.entity_name sia una vista (pg_class/pg_namespace, più efficiente)
    select 1
    into v_dummy
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = p_schema_name
      and c.relname = p_entity_name
      and c.relkind = 'v'   -- v = view
    limit 1;

    if not found then
        raise exception '%.% non esiste o non è una vista', p_schema_name, p_entity_name;
    end if;

    -- 3) verifica che l'attributo non sia usato altrove
    with mappings as (
        select schema_name, entity_name
        from only vrsn.attribute_mapping_to_entity_current
        where attribute_id = p_attribute_id
        union all
        select schema_name, entity_name
        from only  vrsn.attribute_mapping_to_entity_history
        where attribute_id = p_attribute_id
    )
    select 1
    into v_dummy
    from mappings m
    where not (m.schema_name = p_schema_name and m.entity_name = p_entity_name)
    limit 1;

    if found then
        raise exception 'attribute_id % è già usato da altre entità oltre %.%', 
            p_attribute_id, p_schema_name, p_entity_name;
    end if;

    -- 4) recupera il nome della colonna utente da parametri (default: modify_user_id)
    select coalesce(
        vrsn.parameters__get_value('tar', 'params.t_username') #>>'{}',
        'modify_user_id'
    )
    into t_username;

    -- 5) update con nome colonna dinamico (e parametri safe via USING)
    v_sql := format(
        'update vrsn.attribute_lineage
           set schema_name = $1,
               entity_name = $2,
               %I = $3
         where attribute_id = $4',
        t_username
    );

    execute v_sql
    using p_schema_name, p_entity_name, p_modify_user_id, p_attribute_id;

    if found then
        return true;
    else
        raise exception 'attribute_id % non esiste in vrsn.attribute_lineage', p_attribute_id;

    end if;
end;$_$;


--
-- Name: audit_record__build(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__build() RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT '{}'::jsonb AS jsonb;
END;


--
-- Name: audit_record__close(text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__close(user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
	_moreInfo jsonb='{}'::jsonb;
begin
	_moreInfo= vrsn.audit_record__set(user_id,audit_record=>_moreInfo);

	if when_appens is not null then
		_moreInfo= vrsn.audit_record__set(when_appens,'when',_moreInfo);
	end if;

	return vrsn.audit_record__set(_moreInfo,'closing', audit_record);

end;
$$;


--
-- Name: audit_record__deactivate(text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__deactivate(user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT now()) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare	
	_moreInfo jsonb='{}'::jsonb;
begin
	_moreInfo= vrsn.audit_record__set(user_id,audit_record=>_moreInfo);
	_moreInfo= vrsn.audit_record__set(when_appens,'when',_moreInfo);

	return vrsn.audit_record__set(_moreInfo,'deactivation', audit_record);

end;
$$;


--
-- Name: FUNCTION audit_record__deactivate(user_id text, audit_record jsonb, when_appens timestamp with time zone); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.audit_record__deactivate(user_id text, audit_record jsonb, when_appens timestamp with time zone) IS 'Deactivate record.
This record will be outside of timeline from user perspective';


--
-- Name: audit_record__get_deactiovation_ts(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__get_deactiovation_ts(audit_record jsonb) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT (((audit_record -> 'deactivation'::text) ->> 'when'::text))::timestamp with time zone AS timestamptz;
END;


--
-- Name: audit_record__is_active(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__is_active(audit_record jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT (NOT (audit_record ? 'deactivation'::text));
END;


--
-- Name: audit_record__readme(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__readme() RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT 'Manage audit_record object.
It manage username, touchTs and other audit information on record stored.'::text AS text;
END;


--
-- Name: audit_record__reopen(text, jsonb, timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__reopen(user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
	_moreInfo jsonb='{}'::jsonb;
begin
	_moreInfo= vrsn.audit_record__set(user_id,audit_record=>_moreInfo);

	if when_appens is null then
		when_appens=clock_timestamp();
	end if;
	_moreInfo= vrsn.audit_record__set(when_appens,'when',_moreInfo);


	_moreInfo=jsonb_insert('{"reopening":[]}'::jsonb , '{reopening,0}' , _moreInfo);

	return common.jsonb_recursive_merge( audit_record, _moreInfo);

end;
$$;


--
-- Name: audit_record__set(anycompatible, text, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__set(value_to_set anycompatible, key_to_set text DEFAULT 'user_id'::text, audit_record jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$declare
	_audit_record jsonb;	
	_arr text[];
begin

	if audit_record is null then
		--raise notice '%', audit_record;
		_audit_record=vrsn.audit_record__build();
	else
		_audit_record= audit_record;
	end if;
	
	--raise notice '% % %', _audit_record, key_to_set, value_to_set;
	--> if value_to_set is in the format "process:someProcess"
	if key_to_set='user_id' then 		
		_arr= regexp_split_to_array(value_to_set, '\s*:\s*');
		if array_length(_arr, 1) =2 then
			_arr[1]=lower(_arr[1]);
			if _arr[1]='process' then
				key_to_set		=_arr[1];
				value_to_set	=_arr[2];
			end if;
		end if;
	end if;
	
	--raise notice '%', pg_typeof(value_to_set);
	_audit_record[key_to_set]=to_jsonb(value_to_set);

	return _audit_record;

end;
$$;


--
-- Name: audit_record__validate(jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.audit_record__validate(jb jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$declare
	js jsonb='{
	"type":"object"
	,"properties":{
 		 "user_id":{"type":"string"}
		,"process":{"type":"string"}
		,"actualInsertTs":{"type":"string", "format":"date-time"}
		,"actualCloseTs":{"type":"string", "format":"date-time"}
		,"deactivation":{ "type":"object"
			, "required":["user_id","when"]
			, "additionalProperties": false
			, "properties":{
				"user_id":{"type":"string"}
				,"when":{"type":"string", "format":"date-time"}
			}
		}
		,"reopening": {"type":"array",
			"items": { "type":"object"
				, "required":["user_id","when"]
				, "additionalProperties": false
				, "properties":{
						"user_id":{"type":"string"}
					,	"when":{"type":"string", "format":"date-time"}
				}
			}
		}

		,"closing":{ "type":"object"
			, "required":["user_id", "when"]
			, "additionalProperties": false
			, "properties":{
				"user_id":{"type":"string"}
				,	"decision_id":{"type":"string"}
				,	"decision_date":{"type":"string", "format":"date"}
				,	"when":{"type":"string", "format":"date-time"}
			}
		}
 	}
	,"required":["user_id"]
	, "additionalProperties": false
}'::jsonb;

BEGIN
  	return ext_pkg.validate_json_schema(js, jb);
END;$$;


--
-- Name: bitemporal_entity__change(text, text, text, vrsn.historice_entity_behaviour, boolean, text, text, boolean, boolean, boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_entity__change(p_entity_schema text, p_entity_name text, p_modify_user_id text, p_historice_entity vrsn.historice_entity_behaviour DEFAULT NULL::vrsn.historice_entity_behaviour, p_enable_history_attributes boolean DEFAULT NULL::boolean, p_main_fields_list text DEFAULT NULL::text, p_cached_fields_list text DEFAULT NULL::text, p_mitigate_conflicts boolean DEFAULT NULL::boolean, p_ignore_unchanged_values boolean DEFAULT NULL::boolean, p_enable_attribute_to_fields_replacement boolean DEFAULT NULL::boolean) RETURNS void
    LANGUAGE plpgsql
    AS $_$
declare
/*
	p_entity_schema text,
	p_entity_name text,
	p_modify_user_id text,
	p_historice_entity vrsn.historice_entity_behaviour DEFAULT null,
	p_enable_history_attributes boolean DEFAULT null,
	p_main_fields_list text DEFAULT NULL::text,
	p_cached_fields_list text DEFAULT NULL::text
	p_mitigate_conflicts boolean default null,
	p_ignore_unchanged_values boolean default null,
	p_enable_attribute_to_fields_replacement	boolean default null

	RETURNS void
*/
	
	
	
	v_entity_full_name 		vrsn.entity_fullname_dmn;	
	
	affected_rows			INTEGER;
	row_lock				boolean	=false;
	v_table_full_name		text;
begin

	
	--------------------------------------------------------------------
	--	set entity name
	v_entity_full_name.schema_name	=	p_entity_schema;
	v_entity_full_name.table_name	=	p_entity_name;

	
	--------------------------------------------------------------------
	--	Try to obtain an advisory locks (semaphore) for
	--	

	perform vrsn.__lock__get_advsory(
		'vrsn.trigger_activation_record_base'
	,	v_entity_full_name::text
	);

	perform vrsn.__lock__get_advsory(
		'vrsn.def_entity_behavior'
	,	v_entity_full_name::text
	);

	--------------------------------------------------------------------
	--	Try to obtain row lock
	--	and check if there is record for entity

	begin 
		v_table_full_name='vrsn.def_entity_behavior';
		
		select true into strict row_lock
		from vrsn.def_entity_behavior
		WHERE entity_full_name = v_entity_full_name
		for update NOWAIT;

		v_table_full_name='vrsn.trigger_activation_record_base';
		
		select true into row_lock
		from only vrsn.trigger_activation_record_base
		WHERE entity_full_name = v_entity_full_name
		for update NOWAIT;

	EXCEPTION
		WHEN lock_not_available THEN
		raise lock_not_available 
			using message=format('Exlusive row lock unavailable for entity in %1$s in %2$s'
					,	v_entity_full_name
					,	v_table_full_name);	
		WHEN no_data_found THEN
			raise no_data_found	
				using message=format('No record for %1$s in %2$s'
					,	v_entity_full_name
					,	v_table_full_name);	
	end;
	--------------------------------------------------------------------
	--	update def entity behaviour record

    UPDATE vrsn.def_entity_behavior
    SET 
        historice_entity 
			= COALESCE(p_historice_entity, historice_entity),
        enable_history_attributes 
			= COALESCE(p_enable_history_attributes, enable_history_attributes),
        main_fields_list 
			= COALESCE(p_main_fields_list, main_fields_list),
        cached_fields_list 
			= COALESCE(p_cached_fields_list, cached_fields_list),
        mitigate_conflicts 
			= COALESCE(p_mitigate_conflicts, mitigate_conflicts),
        ignore_unchanged_values
			= COALESCE(p_ignore_unchanged_values, ignore_unchanged_values),
        enable_attribute_to_fields_replacement 
			= COALESCE(p_enable_attribute_to_fields_replacement, enable_attribute_to_fields_replacement),
		modify_user_id 
			= p_modify_user_id
    WHERE entity_full_name = v_entity_full_name;
    
    GET DIAGNOSTICS affected_rows = ROW_COUNT;

	delete
	from only vrsn.trigger_activation_record_base
	WHERE entity_full_name = v_entity_full_name;

	
    if affected_rows =0 then
		raise exception 'Entity <%> doesn''t exist,', v_entity_full_name::text;
	end if;


end;
$_$;


--
-- Name: bitemporal_entity__readme(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_entity__readme() RETURNS text
    LANGUAGE sql IMMUTABLE
    BEGIN ATOMIC
 SELECT 'Manage objects under historicizaiton.
Giving an existing table:
- generate history table
- generate standard view (entity)
- register the behaviour of the entity, including if use the historicization by attributes
- generate entity for attribute (curren and history table and view).
Also provide method to customize in deep the attribute behaviour.'::text AS text;
END;


--
-- Name: bitemporal_record__build(text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_record__build(user_id text DEFAULT NULL::text, user_ts_start timestamp with time zone DEFAULT NULL::timestamp with time zone, db_ts_start timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS vrsn.bitemporal_record
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN user_id text DEFAULT null, 
	IN user_ts_start timestamp with time zone DEFAULT null, 
	IN db_ts_start timestamp without time zone DEFAULT null
*/	
	_bt_info				vrsn.bitemporal_record;
	_time_stamp_to_use		timestamptz := clock_timestamp();
begin
	if user_ts_start is null then
		user_ts_start=_time_stamp_to_use;
	end if;
	
	if db_ts_start is null then
		db_ts_start=_time_stamp_to_use;
	end if;
	
	if common.is_empty(user_id) then
		user_id='install';
	end if;
	--> create new audit record with username and touchTs
	_bt_info.audit_record=vrsn.audit_record__set(user_id);
	_bt_info.user_ts_range=vrsn.bitemporal_tsrange__create(user_ts_start);
	_bt_info.db_ts_range=vrsn.bitemporal_tsrange__create(db_ts_start);
	
	return _bt_info;
end;
$$;


--
-- Name: bitemporal_record__get_deactiovation_ts(vrsn.bitemporal_record); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_record__get_deactiovation_ts(bt_info vrsn.bitemporal_record) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT vrsn.audit_record__get_deactiovation_ts((bt_info).audit_record) AS audit_record__get_deactiovation_ts;
END;


--
-- Name: bitemporal_record__is_active(vrsn.bitemporal_record); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_record__is_active(bt_info vrsn.bitemporal_record) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT (NOT ((bt_info).audit_record ? 'deactivation'::text));
END;


--
-- Name: bitemporal_tsrange__close(tstzrange, timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_tsrange__close(ts_range tstzrange, ts_end timestamp with time zone DEFAULT clock_timestamp()) RETURNS tstzrange
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$begin
--	raise notice ' % %',ts_range, ts_end;
	if upper(ts_range) <> 'infinity' then
		raise exception 'Impossible to close ts_range already closed: %', ts_range;
	end if;
	return tstzrange(lower(ts_range), ts_end,'[)');
end;$$;


--
-- Name: bitemporal_tsrange__create(timestamp with time zone); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.bitemporal_tsrange__create(ts_start timestamp with time zone) RETURNS tstzrange
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$begin
	return tstzrange(ts_start, 'infinity','[)');
end;$$;


--
-- Name: entity_fullname_type__readme(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.entity_fullname_type__readme() RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT 'Boring collection of method to properly manage the user type: entity_fullname_type'::text AS text;
END;


--
-- Name: get_resolved_default_value(text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.get_resolved_default_value(p_default_value_str text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    v_resolved_value text;
begin
    -- 1. controlla se la stringa contiene un'operazione di cast (::) o una funzione senza virgolette
    --    questo suggerisce che è un'espressione sql che necessita di valutazione
    if p_default_value_str ilike '%::%' or p_default_value_str ~* '^([a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*\(\)' then
        begin
            -- tenta di eseguire la stringa come espressione sql e cattura il risultato
            execute 'select (' || p_default_value_str || ')::text' into v_resolved_value;
            return v_resolved_value;
        exception
            when others then
                -- se l'esecuzione fallisce, torna la stringa originale
                raise warning 'impossibile risolvere l''espressione sql "%". errore: %', p_default_value_str, sqlerrm;
                return p_default_value_str;
        end;
    else
        -- se non ci sono cast o chiamate a funzioni, si presume sia un valore letterale semplice.
        -- rimuovi apici singoli esterni se presenti, altrimenti torna la stringa così com'è.
        if p_default_value_str like '''%''' and p_default_value_str like '%''' then
            -- assicurati che non sia solo un apice, o qualcosa di malformato
            if length(p_default_value_str) > 2 then
                return trim(both '''' from p_default_value_str);
            end if;
        end if;
        return p_default_value_str;
    end if;
end;
$$;


--
-- Name: json_schema_ts_formatter(timestamp with time zone, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.json_schema_ts_formatter(ts timestamp with time zone DEFAULT now(), format_to_use text DEFAULT 'data-time'::text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
	txt text:='null';
begin

	case format_to_use
	when 'date-time' then
		txt=to_char(ts,'yyyy-mm-ddThh24:mi:ss.us tzh:tzm');
	when 'date' then
		txt=to_char(ts,'yyyy-mm-dd');
	when 'time' then
		txt=to_char(ts,'hh24:mi:ss.us tzh:tzm');
	else
		null;
	end case;
	
	return txt ;
end;$$;


--
-- Name: jsonb_table_structure__build(vrsn.table_field_details[]); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build(p_fields_data vrsn.table_field_details[]) RETURNS jsonb
    LANGUAGE sql
    AS $$
	WITH jb1 AS (
		SELECT 
			l.field_name,
			json_build_object(
				'type', l.data_type, 
				'generated', l.generation_type, 
				'pk', l.is_pk, 
				'pk_order', l.pk_order, 
				'default_value', l.default_value, 
				'field_order', l.table_order
			) AS obj
		FROM unnest(p_fields_data) l
		ORDER BY l.table_order
	)
	SELECT jsonb_object_agg(jb1.field_name, jb1.obj)
	FROM jb1;
$$;


--
-- Name: jsonb_table_structure__build(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build(table_full_name vrsn.entity_fullname_type) RETURNS jsonb
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$

 SELECT vrsn.jsonb_table_structure__build((table_full_name).table_name, (table_full_name).schema_name) AS jsonb_table_structure__build;
$$;


--
-- Name: jsonb_table_structure__build(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build(name_of_table text, name_of_schema text DEFAULT 'public'::text) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
/*
 WITH jb1 AS (
          SELECT l.field_name,
             json_build_object('type', l.data_type, 'generated', l.generation_type, 'pk', l.is_pk, 'pk_order', l.pk_order, 'default_value', l.default_value, 'field_order', l.table_order) AS obj
            FROM vrsn.table__get_fields_details(jsonb_table_structure__build.name_of_schema, jsonb_table_structure__build.name_of_table) l(field_name, data_type, default_value, is_nullable, is_pk, pk_order, table_order, generation_type, complete_definition)
           ORDER BY l.table_order
         )
  SELECT jsonb_object_agg(jb1.field_name, jb1.obj) AS jsonb_object_agg
    FROM jb1;
*/
select vrsn.table_field_details_to_jts_agg(l )
FROM vrsn.table__get_fields_details(name_of_schema, name_of_table) l
;

	
$$;


--
-- Name: jsonb_table_structure__build(vrsn.entity_fullname_type, vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build(entity_full_name vrsn.entity_fullname_type, table_full_name vrsn.entity_fullname_type) RETURNS jsonb
    LANGUAGE plpgsql STABLE PARALLEL SAFE
    AS $$
declare
/*
	IN entity_full_name vrsn.entity_fullname_type,
	IN table_full_name vrsn.entity_fullname_type
	RETURNS jsonb
*/
	p_entity_full_name alias for entity_full_name;
	v_ret	jsonb;
	v_def	jsonb;
	v_param	jsonb;
	v_field_key	text;
	v_jb	jsonb;
BEGIN 

	------------------------------------------------------------------------------
	-- Read data from def_entity_behavior
	select field_special_behavior into v_def
	from vrsn.def_entity_behavior d
	where d.entity_full_name= p_entity_full_name;

	if v_def is null then
		v_def='{}'::jsonb;
	end if;


	-------------------------------------------------------------------------------
	-- Generate base structure
	v_ret=vrsn.jsonb_table_structure__build(
			(table_full_name).table_name
		,	(table_full_name).schema_name
	);


	v_param=vrsn.parameters__get(
		'field_type'::text
	);

--raise notice 'v_param for %',v_param;

	for v_field_key, v_jb in
		select * from jsonb_each(v_ret)
	loop


--raise notice 'v_jb %=>%',v_field_key,v_jb;

		if v_param ?  (v_jb->>'type') then
		--raise notice 'param for type %=>%',(v_jb->>'type'), v_param->(v_jb->>'type');
			v_jb=v_jb || (v_param->(v_jb->>'type'));
		end if;
--raise notice 'v_jb %=>%',v_field_key,v_jb;
		
		
		-- controlla se la chiave esiste nel jsonb 
		-- della entità def_entity_behavior
		if v_def ? v_field_key then
			v_jb=v_jb ||  (v_def->v_field_key);
		end if;
--raise notice 'v_jb %=>%',v_field_key,v_jb;
		v_ret[v_field_key]=v_jb;
		
	end loop;

	return v_ret;
	
END;
$$;


--
-- Name: jsonb_table_structure__build_uks(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build_uks(name_of_table text, name_of_schema text DEFAULT 'public'::text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 WITH tbl AS (
          SELECT jsonb_table_structure__build_uks.name_of_schema AS sn,
             jsonb_table_structure__build_uks.name_of_table AS tn
         ), uks AS (
          SELECT cu.column_name AS cn,
                 CASE
                     WHEN ((tc.constraint_type)::text = 'PRIMARY KEY'::text) THEN 'pk'::text
                     ELSE 'uk'::text
                 END AS type_uk,
             tc.constraint_name AS uk_name
            FROM ((tbl
              JOIN information_schema.table_constraints tc ON ((((tc.table_schema)::name = tbl.sn) AND ((tc.table_name)::name = tbl.tn))))
              JOIN information_schema.key_column_usage cu ON (((tc.constraint_name)::name = (cu.constraint_name)::name)))
           WHERE ((tc.constraint_type)::text = ANY (ARRAY['PRIMARY KEY'::text, 'UNIQUE'::text]))
         ), uks1 AS (
          SELECT json_build_object('type', uks.type_uk, 'name', uks.uk_name, 'fields', jsonb_agg(uks.cn)) AS jbo,
             row_number() OVER (ORDER BY uks.type_uk, uks.uk_name) AS ord
            FROM uks
           GROUP BY uks.type_uk, uks.uk_name
         )
  SELECT jsonb_agg(uks1.jbo ORDER BY uks1.ord) AS uks
    FROM uks1;
END;


--
-- Name: FUNCTION jsonb_table_structure__build_uks(name_of_table text, name_of_schema text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.jsonb_table_structure__build_uks(name_of_table text, name_of_schema text) IS 'retrieve unique keys (also primary) in a jsonb setting:
- type (pk|uk)
- name and 
- list of fields.

Primary key is always the first occurence';


--
-- Name: jsonb_table_structure__build_uks(vrsn.entity_fullname_type); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__build_uks(table_full_name vrsn.entity_fullname_type) RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT vrsn.jsonb_table_structure__build_uks((table_full_name).table_name, (table_full_name).schema_name) AS jsonb_table_structure__build;
END;


--
-- Name: FUNCTION jsonb_table_structure__build_uks(table_full_name vrsn.entity_fullname_type); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.jsonb_table_structure__build_uks(table_full_name vrsn.entity_fullname_type) IS 'retrieve unique keys (also primary) in a jsonb setting:
- type (pk|uk)
- name and 
- list of fields.

Primary key is always the first occurence';


--
-- Name: jsonb_table_structure__get_insert(extensions.hstore, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__get_insert(rec extensions.hstore, columns_list jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
	v_key		text;
	v_jb 		jsonb;
	v_field		text='';
	v_value		text='';
begin
	for v_key, v_jb in 
		select *
		from jsonb_each(columns_list)
	loop
	
		v_field = v_field || ', ' || v_key;
		v_value = v_value || ', ' || quote_nullable(rec[v_key])
				|| '::'|| (v_jb->>'type');
	end loop;
	--raise notice '%', substring(_whereStr from 6);
	return '(' || substring(v_field from 2) 
		|| e')\nvalues (' || 	substring(v_value from 2) || ')';
end;
$$;


--
-- Name: jsonb_table_structure__get_pk_where(extensions.hstore, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__get_pk_where(rec extensions.hstore, columns_list jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$declare
	_key text;
	_type text;
	_whereStr text='';
begin
	for _key, _type in 
		select l->>'key', (l->'value')->>'type'
		from (select jsonb_path_query(columns_list, '$.keyvalue() ? (@.value.pk == true)')) sub(l)
	loop
/*
		raise notice '<%> <%> <%> <%>',_key, _value, pg_typeof(_value),_type;
		for _rec in select jsonb_object_keys(_value) loop
			raise notice '%', _rec;
		end loop;
*/		
		_whereStr= _whereStr || ' and ' || quote_ident(_key) || 
			'=' || quote_nullable(rec[_key]) 
			||'::'|| _type;
	end loop;
	--raise notice '%', substring(_whereStr from 6);
	return substring(_whereStr from 6);
end;$_$;


--
-- Name: jsonb_table_structure__get_pk_where(record, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__get_pk_where(rec record, columns_list jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$begin
	return vrsn.jsonb_table_structure__get_pk_where(hstore(rec),columns_list);
end;$$;


--
-- Name: FUNCTION jsonb_table_structure__get_pk_where(rec record, columns_list jsonb); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.jsonb_table_structure__get_pk_where(rec record, columns_list jsonb) IS 'Wrapper for hstore version';


--
-- Name: jsonb_table_structure__get_uk_where(extensions.hstore, jsonb, jsonb, integer); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__get_uk_where(rec extensions.hstore, columns_list jsonb, uk_list jsonb, uk_index integer DEFAULT NULL::integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
	_key text;
	_type text;
	_whereStr text='false';
	_whereStrSingle text='';
	_jb	jsonb;
	_t_fields	text='fields';

	uk_ix_min	integer;
	uk_ix_max	integer;
begin

	if uk_index is null then
		uk_ix_min=0;
		uk_ix_max = jsonb_array_length(uk_list);
	else
		uk_ix_min=uk_index;
		uk_ix_max=uk_index;
	end if;

	for uk_index in uk_ix_min..uk_ix_max loop
		
		-- retrieve the N-esim uk		
		_jb = uk_list->uk_index;

		-- Check if uk exist with valid data
		if		_jb is null 
			or	_jb->_t_fields is null 
			or	jsonb_array_length(_jb->_t_fields) =0  then
			
				continue;
		end if;

		_whereStrSingle ='';
		for _key in 
			select * from jsonb_array_elements_text(_jb->_t_fields)
		loop
	/*
			raise notice '<%> <%> <%> <%>',_key, _value, pg_typeof(_value),_type;
			for _rec in select jsonb_object_keys(_value) loop
				raise notice '%', _rec;
			end loop;
	*/		
			_whereStrSingle= _whereStrSingle || ' and ' || quote_ident(_key) || 
				'=' || quote_nullable(rec[_key]) 
				||'::'|| (columns_list->_key->>'type');
		end loop;
		_whereStr=_whereStr|| e'\n\tor (' || substring(_whereStrSingle from 6) || ')';

	end loop;
	--raise notice '%', substring(_whereStr from 6);
	return _whereStr;
end;
$$;


--
-- Name: jsonb_table_structure__get_update(extensions.hstore, jsonb); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.jsonb_table_structure__get_update(rec extensions.hstore, columns_list jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
declare
	v_key		text;
	v_jb 		jsonb;
	v_whereStr	text='';
	v_setStr	text='';
	v_sql_part	text=e' %1$s = %4$s( %2$s::%3$s )\n';
begin
	for v_key, v_jb in 
		select *
		from jsonb_each(columns_list)
	loop
/*
		raise notice '<%> <%> <%> <%>',_key, _value, pg_typeof(_value),_type;
		for _rec in select jsonb_object_keys(_value) loop
			raise notice '%', _rec;
		end loop;
*/		
		if (v_jb->>'pk')::boolean then
			v_whereStr= v_whereStr || ' and ' 
				|| format (v_sql_part
					,	quote_ident(v_key)
					,	quote_nullable(rec[v_key])
					,	(v_jb->>'type')
					,	coalesce(v_jb->>'convertion_func','')
					)
			;
		else
			v_setStr =v_setStr ||', '
				|| format (v_sql_part
					,	quote_ident(v_key)
					,	quote_nullable(rec[v_key])
					,	(v_jb->>'type')
					,	coalesce(v_jb->>'convertion_func','')
					)
			;
		end if;
	end loop;
	--raise notice '%', substring(_whereStr from 6);
	return e'\nset ' || substring(v_setStr from 2)
		|| 'where' || 	substring(v_whereStr from 5);
end;
$_$;


--
-- Name: parameters__get(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.parameters__get(p_context text, p_sub_context text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
    c_schema_name constant text := 'vrsn';
    c_table_name  constant text := 'parameter';
    v_final_jsonb jsonb := '{}'::jsonb;
	_jb jsonb;
    v_current_context text;
    v_contexts text[];
    v_query text;
    v_key text;
    v_is_single_key boolean := false;
	v_no_key boolean := false;
begin
    -- 1. verifica l'esistenza della tabella o vista
    if not exists (
        select 1
        from information_schema.tables
        where table_schema = c_schema_name
          and table_name = c_table_name
--          and table_type in ('base table', 'view') -- include sia tabelle che viste
    ) then
		raise notice 'Entity %.% does not exist.', c_schema_name, c_table_name;
        return null;
    end if;


	-- 3. esegue una query, il loop non è necessario
	for _jb in 
		select properties
		from vrsn.parameter
		where context =p_context
			and (p_sub_context is null or p_sub_context=sub_context)	
	loop
		v_final_jsonb =common.jsonb_recursive_merge(v_final_jsonb,  _jb);

	end loop;

	return v_final_jsonb;
	    
end;
$$;


--
-- Name: parameters__get_subset(text, text, text[]); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.parameters__get_subset(p_context text, p_sub_context text DEFAULT NULL::text, p_search_keys text[] DEFAULT NULL::text[]) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN	p_context text,
	IN	p_sub_context text DEFAULT NULL::text,
	IN	p_search_keys text[] DEFAULT NULL::text[])
    RETURNS jsonb
*/
    v_final_jsonb jsonb := '{}'::jsonb;
begin

	v_final_jsonb=vrsn.parameters__get(p_context,p_sub_context);

	if v_final_jsonb is null then
		return null;
	end if;

	v_final_jsonb=common.jsonb_extract_multiple_paths(v_final_jsonb,p_search_keys);
	
	return v_final_jsonb->'__FOUND__';
	    
end;
$$;


--
-- Name: parameters__get_value(text, text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.parameters__get_value(p_context text, p_search_key text, p_sub_context text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN	p_context text,
	IN	p_search_key text,
	IN	p_sub_context text DEFAULT NULL::text
    RETURNS jsonb
*/
    v_final_jsonb jsonb := '{}'::jsonb;
begin

	if common.is_empty(p_search_key) then
		return null;
	end if;

	v_final_jsonb=vrsn.parameters__get(p_context,p_sub_context);

	if v_final_jsonb is null then
		return null;
	end if;

	v_final_jsonb=common.jsonb_extract_multiple_paths(v_final_jsonb,array[p_search_key]);
	
	
	return v_final_jsonb->'__SINGLE_VALUE__';
	    
end;
$$;


--
-- Name: table__get_fields_details(text, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.table__get_fields_details(p_schema_name text, p_table_name text) RETURNS SETOF vrsn.table_field_details
    LANGUAGE sql
    AS $$
	SELECT 
		a.attname::text as field_name,
		format_type(a.atttypid, a.atttypmod)::text as data_type,
		pg_get_expr(ad.adbin, ad.adrelid)::text as default_value,
		not a.attnotnull as is_nullable,
		(kcu.column_name is not null)::boolean as is_pk,
		kcu.ordinal_position::integer as pk_order,
		a.attnum::integer as table_order,
		case
			when ((cs.is_identity)::text = 'YES'::text) and ((cs.identity_generation)::text = 'BY DEFAULT'::text) then 'default'::text
			when ((cs.is_identity)::text = 'YES'::text) and ((cs.identity_generation)::text = 'ALWAYS'::text) then 'identity'::text
			when ((cs.is_generated)::text = 'ALWAYS'::text) then 'always'::text
			when ((cs.is_nullable)::text = 'NO'::text) and (cs.column_default is not null) then 'on_null'::text
			else ''::text
		end as generation_type,
		format('%I %s%s%s', 
			a.attname, 
			format_type(a.atttypid, a.atttypmod),
			case 
				when ad.adbin is not null then 
					format(' default %s', pg_get_expr(ad.adbin, ad.adrelid))
				else ''
			end,
			case 
				when a.attnotnull then ' not null'
				else ''
			end
		)::text as complete_definition
	from pg_attribute a
	join pg_class c on c.oid = a.attrelid
	join pg_namespace n on n.oid = c.relnamespace
	left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
	left join information_schema.columns cs
		on cs.table_schema = n.nspname
		and cs.table_name = c.relname
		and cs.column_name = a.attname
	left join information_schema.key_column_usage kcu
		on kcu.table_schema = n.nspname
		and kcu.table_name = c.relname
		and kcu.column_name = a.attname
	left join information_schema.table_constraints tc 
		on tc.constraint_name = kcu.constraint_name
		and tc.table_schema = kcu.table_schema
		and tc.table_name = kcu.table_name
		and tc.constraint_type = 'PRIMARY KEY'
	where n.nspname = p_schema_name
		and c.relname = p_table_name
		and a.attnum > 0  -- esclude attributi di sistema
		and not a.attisdropped  -- esclude colonne eliminate
	order by a.attnum;
$$;


--
-- Name: tar_h__get(vrsn.entity_fullname_type, anycompatiblearray); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.tar_h__get(entity_full_name vrsn.entity_fullname_type, argv anycompatiblearray DEFAULT ARRAY[]::text[]) RETURNS vrsn.trigger_activation_record_stack
    LANGUAGE plpgsql
    AS $$
declare
	p_entity_full_name alias for entity_full_name;
	p_argv	alias for	argv;
begin	
	return vrsn.__tar_h__build(
			entity_full_name=>p_entity_full_name
		,	argv=>p_argv
		,	force_rebuild=>false);
end;
$$;


--
-- Name: tar_h__readme(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.tar_h__readme() RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT 'Trigger Activation Record Handler
This package provides the full management of instead of trigger.
Trigger_handler call tar_h__handle_data
From here appens:
- a tar record for the view as build (reading an existing record or from scratch)
- the datas will be matched with the table structure
- if the modify_ts is not null will be managede the change of history
- record will be inserted, updated or deleted
- if new and old record is the same, the table receive an update in audit record at touchInformation with timestamp and user

If the record has to be create from scratch (aslo if the record is too ancient):
- create an empty tar record
- upadte with default value
- set current and history tables information
- build a jsonb with structure the structu of the current and history table

'::text AS text;
END;


--
-- Name: test__tar_check(integer, text); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.test__tar_check(step_number integer, step_description text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare
--	in step_number integer,
--	in step_description text
--    RETURNS boolean

	_step_number		alias for step_number;
	_step_description	alias for step_description;
	_valid	boolean=true;
	_rec	record;
	_jb		jsonb=$${
			"valid":true
		,	"check_closing_period":null
		,	"check_actual_ts":null
		,	"check_db_period":null
		,	"check_user_period":null
		,	"check_actual_ts_compliance":null

		}$$::jsonb;
--		,	"check_closing_period":[]

	_param	text[][]=array[
		array[ 'vrsn.test_table_check_run_detail'
		,	$$	id,
	sometext,
	main_ts,
	somevalue,
	many_fields,$$
		,	'vrsn.test_table_current'
		]
	,	array[ 'vrsn.test_table_check_run_attribute_detail'
		,	$$	id,
	attribute_id,
	idx,
	attribute_value,$$
		,	'vrsn.test_table_attribute_current'
		]
	
	];
	_checkSqlStr	text=$$	
insert into %1$s
WITH step1 AS (
	SELECT
		CASE
			WHEN s0.tableoid::regclass::text ~~ '%%_current'::text THEN true
			ELSE false
		END AS table_current,
	%2$s
	((s0.bt_info).audit_record ->> 'actualInsertTs'::text)::timestamp with time zone AS actual_insert_ts,
	((s0.bt_info).audit_record ->> 'actualCloseTs'::text)::timestamp with time zone AS actual_close_ts,
	isfinite(upper((s0.bt_info).db_ts_range)) AS db_close_finite,
	isfinite(upper((s0.bt_info).user_ts_range)) AS user_close_finite,
	vrsn.bitemporal_record__get_deactiovation_ts(s0.bt_info) AS deactivation_ts,
	vrsn.bitemporal_record__is_active(s0.bt_info) AS is_active,
	lag(s0.bt_info, 1) OVER (PARTITION BY s0.id ORDER BY 
			((s0.bt_info).db_ts_range)) AS bt_info_prev,
	s0.bt_info
   FROM %3$s as s0
), step2 AS (
	SELECT s1.table_current,
		%2$s
		s1.actual_insert_ts,
		s1.actual_close_ts,
		s1.db_close_finite,
		s1.user_close_finite,
		s1.deactivation_ts,
		s1.is_active,
		s1.bt_info_prev,
		s1.bt_info,
		lag(s1.bt_info, 1) OVER (PARTITION BY s1.id, s1.deactivation_ts ORDER BY s1.bt_info) AS bt_info_prev_group
		FROM step1 s1
	)
SELECT	$1 as step_number,
	row_number() OVER (ORDER BY s2.id, s2.deactivation_ts, s2.bt_info DESC) AS rwn,
    s2.table_current,
    %2$s
	null::jsonb	as error_found,
    s2.deactivation_ts,
    s2.table_current AND NOT s2.user_close_finite AND NOT s2.db_close_finite OR NOT s2.table_current AND s2.user_close_finite AND s2.db_close_finite AS check_closing_period,
        CASE
            WHEN s2.actual_insert_ts IS NOT NULL THEN s2.actual_insert_ts = (((s2.bt_info_prev).audit_record ->> 'actualCloseTs'::text)::timestamp with time zone)
            ELSE NULL::boolean
        END AS check_actual_ts,
        CASE
            WHEN s2.bt_info_prev IS NOT NULL THEN lower((s2.bt_info).db_ts_range) = upper((s2.bt_info_prev).db_ts_range)
            ELSE NULL::boolean
        END AS check_db_period,
    row_number() OVER (ORDER BY s2.id, (lower((s2.bt_info).db_ts_range)) DESC) AS rwn_seq,
        CASE
            WHEN s2.bt_info_prev_group IS NOT NULL THEN lower((s2.bt_info).user_ts_range) = upper((s2.bt_info_prev_group).user_ts_range)
            ELSE NULL::boolean
        END AS check_user_period,
        CASE
            WHEN s2.actual_insert_ts IS NOT NULL THEN (s2.actual_insert_ts + '00:00:02'::interval) > clock_timestamp()
            ELSE NULL::boolean
        END AS check_actual_ts_compliance,
    vrsn.audit_record__validate((s2.bt_info).audit_record) AS check_json_schema,
    s2.actual_insert_ts,
    s2.actual_close_ts,
    s2.db_close_finite,
    s2.user_close_finite,
    s2.is_active,
    lower((s2.bt_info).user_ts_range) AS user_ts_start,
    upper((s2.bt_info).user_ts_range) AS user_ts_end,
    lower((s2.bt_info).db_ts_range) AS db_ts_start,
    upper((s2.bt_info).db_ts_range) AS db_ts_end,
    (s2.bt_info).audit_record AS audit_record,
    s2.bt_info_prev,
    s2.bt_info_prev_group
   FROM step2 s2;
	$$;

	i	integer;
	
begin
/*
raise exception '%', format(_checkSqlStr
			,	_param[i][1]
			,	_param[i][2]
			,	_param[i][3])
			;
*/
	for i in 1..2 loop
		execute format(_checkSqlStr
			,	_param[i][1]
			,	_param[i][2]
			,	_param[i][3]
		)	
		using step_number;
	
		--> loop over record
		for _rec in 
			select s.ctid, s.*
			from vrsn.test_table_check_run_detail as s
		loop
			_jb=$${
				"valid":true
			,	"check_closing_period":null
			,	"check_actual_ts":null
			,	"check_db_period":null
			,	"check_user_period":null
			,	"check_actual_ts_compliance":null
	
			}$$::jsonb;
			
			if not _rec.check_closing_period then
				_valid=false;
				_jb['valid']=to_jsonb(false);
				_jb['check_closing_period']= to_jsonb(_rec.rwn);
			end if;
			if not _rec.check_actual_ts then
				_valid=false;
				_jb['valid']=to_jsonb(false);
				_jb['check_actual_ts']= to_jsonb(_rec.rwn);
			end if;
			if not _rec.check_db_period then
				_valid=false;
				_jb['valid']=to_jsonb(false);
				_jb['check_db_period']= to_jsonb(_rec.rwn);
			end if;
			if not _rec.check_user_period then
				_valid=false;
				_jb['valid']=to_jsonb(false);
				_jb['check_user_period']= to_jsonb(_rec.rwn);
			end if;
			if not _rec.check_actual_ts_compliance then
				_valid=false;
				_jb['valid']=to_jsonb(false);
				_jb['check_actual_ts_compliance']= to_jsonb(_rec.rwn);
			end if;
	
			
			if not (_jb->>'valid')::boolean then
				execute format($$
					update %1$s as s
					set error_found=$1
					where s.ctid=$2;
					$$, _param[i][1]
				) using _jb , _rec.ctid;
			end if;
	
	
		end loop;
	

	end loop;

	insert into vrsn.test_table_check_run
	values (_step_number,_step_description, _valid) ;	


	return _valid;

end;
$_$;


--
-- Name: FUNCTION test__tar_check(step_number integer, step_description text); Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON FUNCTION vrsn.test__tar_check(step_number integer, step_description text) IS 'Check the result of test';


--
-- Name: test__tar_exec(boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.test__tar_exec(recreate boolean DEFAULT false) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare
--	in	recreate boolean DEFAULT false
--	RETURNS boolean

	_step_description	text =e'Test list\n--------';
	_step_num	integer=0;
	_jb			jsonb;

	userid		text='ui987';
	_timestampe_to_use		timestamptz= clock_timestamp();
	_id			integer;
	_i			integer=0;
	
	_bt_info	vrsn.bitemporal_record;

	_k			integer;
	_b			boolean;
	_ts			timestamptz;

	_rec		record;

	tcname		text='vrsn.test_table_current';
	thname		text='vrsn.test_table_history';
	tvname		text='vrsn.test_table';
begin

	if recreate then	
		_b =vrsn.test__tar_init();
	end if;

	---------------------------------------------------------------------------------------------
	--> empty tables
	truncate table only vrsn.test_table_history;
	truncate table only vrsn.test_table_current restart identity ;
	truncate table only vrsn.test_table_attribute_current restart identity;
	truncate table only vrsn.test_table_attribute_history;	
	truncate table only vrsn.test_table_check_run restart identity;
	truncate table only vrsn.test_table_check_run_detail restart identity;
	truncate table only vrsn.test_table_check_run_attribute_detail restart identity;

	delete from only vrsn.trigger_activation_record_base
	where entity_full_name in 
		(	'vrsn.test_table'::text::vrsn.entity_fullname_dmn
		,	'vrsn.test_table_attribute'::text::vrsn.entity_fullname_dmn
		)
	;

	---------------------------------------------------------------------------------------------
	--> Disable attribute handling
	perform vrsn.bitemporal_entity__change(
		p_entity_schema	=>	'vrsn'
	,	p_entity_name	=>	'test_table'
	,	p_modify_user_id	=>	'process:test'
	,	p_historice_entity	=>	'always'::vrsn.historice_entity_behaviour
	,	p_enable_history_attributes	=> false
	,	p_enable_attribute_to_fields_replacement => false
/*	<p_main_fields_list text>,
	<p_cached_fields_list text>,
	<p_mitigate_conflicts boolean>,
	<p_ignore_unchanged_values boolean>,
	<p_enable_attribute_to_fields_replacement boolean>
	*/
	);
	

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Insert into view generating id'; 	_step_num=_step_num+1;

		insert into vrsn.test_table (sometext,somevalue, modify_user_id)
		values ('tar',5610, 'a user') returning id into _id;
	
		_b= _id >0;
		--insert into vrsn.test_table_check_run
		--values (_step_num,_step_description, _b) ;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

		if not  _id >0 then
			raise notice  'Insert into view does not generate id: %', _id;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Generate historical position';	_step_num=_step_num+1;
	
		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '1 day'
			,	_timestampe_to_use - interval '1 day'
			);
		
		
		
		insert into vrsn.test_table_current (sometext,somevalue, bt_info)
		values ('foo',10, _bt_info) returning id into _id;
	
	
		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '2 day', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '2 day', lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'foo',20, _bt_info);
	
	
		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '5 day', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '5 day', lower((_bt_info).db_ts_range),'[)');
		
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'bar',30, _bt_info);

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;
		
	---------------------------------------------------------------------------------------------
	--
	_step_description ='Insert row in near future'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo near past'
			,	modify_user_id	=	userid
			,	modify_ts		=	_timestampe_to_use - interval '1 hour'		
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;


	---------------------------------------------------------------------------------------------
	--
	_step_description ='Update a row in standard wqy'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo simple update'
			,	somevalue		=	43
			,	modify_user_id	=	userid
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Insert into a far past'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo far past in between'
			,	modify_user_id	=	userid
			,	modify_ts		=	_timestampe_to_use - interval '36 hour'		
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Insert before every record'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo before every record'
			,	modify_user_id	=	userid
			,	modify_ts		=	_timestampe_to_use - interval '10 days'		
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Close position'; _step_num=_step_num+1;
	
		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '49 hours'
			,	_timestampe_to_use - interval '49 hours'
			);
		
		insert into vrsn.test_table_current (sometext,somevalue, bt_info)
		values ('Zup',801, _bt_info) returning id into _id;

		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '79 hours', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '79 hours', lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'Zup',800, _bt_info);

		update  vrsn.test_table 
			set	is_closed		=	true
			,	modify_user_id	=	'otherUID'
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Close position in the past'; _step_num=_step_num+1;
	
		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '36 hours'
			,	_timestampe_to_use - interval '36 hours'
			);
		
		insert into vrsn.test_table_current (sometext,somevalue, bt_info)
		values ('PAA closing in the past',701, _bt_info) returning id into _id;

		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '47 hours', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '47 hours', lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'PAA',700, _bt_info);

		update  vrsn.test_table 
			set	is_closed		=	true
			,	modify_user_id	=	'otherUID'
			,	modify_ts		=	_timestampe_to_use - interval '10 hours'
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Close before current position'; _step_num=_step_num+1;

		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '6 hours'
			,	_timestampe_to_use - interval '6 hours'
			);

		insert into vrsn.test_table_current (sometext,somevalue, bt_info)
		values ('ZAC closing before current position',701, _bt_info) returning id into _id;

		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '47 hours', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '47 hours', lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'ZAC',700, _bt_info);

		update  vrsn.test_table 
			set	is_closed		=	true
			,	modify_user_id	=	'otherUID'
			,	modify_ts		=	_timestampe_to_use - interval '10 hours'
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Close before every positions'; _step_num=_step_num+1;

		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '6 hours'
			,	_timestampe_to_use - interval '6 hours'
			);

		insert into vrsn.test_table_current (sometext,somevalue, bt_info)
		values ('QWE closing before every positions',701, _bt_info) returning id into _id;

		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '8 hours', lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '8 hours', lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'QWE',700, _bt_info);

		update  vrsn.test_table 
			set	is_closed		=	true
			,	modify_user_id	=	'otherUID'
			,	modify_ts		=	_timestampe_to_use - interval '10 hours'
			,	action_hints	='{"allowFullDeactivationByPastCloseTs":true}'::jsonb
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--	Enable attribute handling
	
	perform vrsn.bitemporal_entity__change(
		p_entity_schema	=>	'vrsn'
	,	p_entity_name	=>	'test_table'
	,	p_modify_user_id	=>	'process:test'
	,	p_historice_entity	=>	'on_main_fields'::vrsn.historice_entity_behaviour
	,	p_enable_history_attributes	=> true
	,	p_enable_attribute_to_fields_replacement => true
/*	<p_main_fields_list text>,
	<p_cached_fields_list text>,
	<p_mitigate_conflicts boolean>,
	<p_ignore_unchanged_values boolean>,
	<p_enable_attribute_to_fields_replacement boolean>
	*/
	);
	
--	_timestampe_to_use		timestamptz= clock_timestamp();
	---------------------------------------------------------------------------------------------
	--

	
	_step_description ='Generate historical position for attribute';	_step_num=_step_num+1;
	
		_bt_info= vrsn.bitemporal_record__build(
				userid
			,	_timestampe_to_use - interval '1 day'
			,	_timestampe_to_use - interval '1 day'
			);
		
		
		
		insert into vrsn.test_table_current (sometext,somevalue, main_ts, many_fields, bt_info)
		values ('foo_jb',10
			,	_timestampe_to_use - interval '25 hour'
			,	$${"field_01":1,"field_02":2}$$::jsonb
		, _bt_info) returning id into _id;
	
	
		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '2 day'
			,	lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '2 day'
			,	lower((_bt_info).db_ts_range),'[)');
	
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'foo_jb',20, _bt_info);
	
	
		_bt_info.user_ts_range= tstzrange(_timestampe_to_use - interval '5 day'
			,	lower((_bt_info).user_ts_range),'[)');
		_bt_info.db_ts_range= tstzrange(_timestampe_to_use - interval '5 day'
			,	lower((_bt_info).db_ts_range),'[)');
		
		insert into vrsn.test_table_history (id, sometext,somevalue, bt_info)
		values (_id, 'foo_jb',30, _bt_info);

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;




	---------------------------------------------------------------------------------------------
	--
	_step_description ='Insert row in near past'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo jb near past'
			,	modify_user_id	=	userid
			,	many_fields		=	
					$${"field_02":2,"somevalue":32}$$::jsonb

			,	modify_ts		=	_timestampe_to_use - interval '1 hour'
			,	action_hints	=	'{"onUpdate": "ignore nulls"}'::jsonb
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;

	---------------------------------------------------------------------------------------------
	--
	_step_description ='Update a row with attribute in standard wqy'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	sometext		=	'foo jb simple update'
			,	many_fields		=	
					$${"field_01":1,"field_02":2,"somevalue":37}$$::jsonb
			,	modify_user_id	=	userid
		where id=_id;


		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;


	---------------------------------------------------------------------------------------------
	--
	_step_description ='Update only with json'; _step_num=_step_num+1;

		update  vrsn.test_table 
			set	many_fields		=	
					$${"field_02":4,"somevalue":32,"sometext":"foo jb tutto jb","modify_user_id":"sono un utente"}$$::jsonb


			,	action_hints	=	'{"onUpdate": "ignore nulls"}'::jsonb
		where id=_id;

		-----------------------------------------------------------
		--> check error
		if not  vrsn.test__tar_check(_step_num,_step_description) then
			raise notice  'Errore al passo: %', _step_num;
			return false;
		end if;













	--------------------------------------------------------------		
	raise notice 'Executed % tests.', _step_num;

	
	return true;

 exception	
 	when ASSERT_FAILURE then

		raise notice 'Execution got error at step: %', _step_num;
	return false;
	
end;
$_$;


--
-- Name: test__tar_init(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.test__tar_init() RETURNS boolean
    LANGUAGE plpgsql
    AS $$declare

begin

	---------------------------------------------------------------------------------------
	-- Drop test table cascade
	drop table vrsn.test_table_current cascade;


	---------------------------------------------------------------------------------------
	-- Create current test table

	CREATE TABLE IF NOT EXISTS vrsn.test_table_current
	(
		bt_info vrsn.bitemporal_record NOT NULL,
		id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY ( CYCLE INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
		sometext text COLLATE pg_catalog."default",
		main_ts timestamptz,
		somevalue bigint,
		many_fields vrsn.cached_attribute,
		CONSTRAINT test_table_current_pk PRIMARY KEY (id)
	);


	---------------------------------------------------------------------------------------
	-- Register current table and create all other structure

	select  vrsn.bitemporal_entity__register(
		'vrsn',
		'test_table_current',
		'on_main_fields',
		true,
		'main_ts',
		'many_fields',
		false
	);


	---------------------------------------------------------------------------------------
	-- Drop check run table	

	DROP TABLE IF EXISTS vrsn.test_table_check_run;


	---------------------------------------------------------------------------------------
	-- Drop check run table	
	
	CREATE TABLE IF NOT EXISTS vrsn.test_table_check_run
	(
		step_run	integer,
		step_descritpion	text,
		is_valid	boolean
	)
	
	TABLESPACE pg_default;
	
	
	ALTER TABLE IF EXISTS vrsn.test_table_check_run
		ADD CONSTRAINT test_table_check_run_pk PRIMARY KEY (step_run);

	---------------------------------------------------------------------------------------
	-- Drop check run table details
	DROP TABLE IF EXISTS vrsn.test_table_check_run_detail;


	---------------------------------------------------------------------------------------
	-- Create check run table details

	CREATE TABLE IF NOT EXISTS vrsn.test_table_check_run_detail
	(
		step_run	integer,
		rwn bigint,
		table_current boolean,
		id integer,
		sometext text COLLATE pg_catalog."default",
		main_ts timestamptz,
		somevalue bigint,
		many_fields vrsn.cached_attribute,
		error_found jsonb,
		deactivation_ts timestamp with time zone,
		check_closing_period boolean,
		check_actual_ts boolean,
		check_db_period boolean,
		rwn_seq bigint,
		check_user_period boolean,
		check_actual_ts_compliance boolean,
		check_json_schema boolean,
		actual_insert_ts timestamp with time zone,
		actual_close_ts timestamp with time zone,
		db_close_finite boolean,
		user_close_finite boolean,
		is_active boolean,
		user_ts_start timestamp with time zone,
		user_ts_end timestamp with time zone,
		db_ts_start timestamp with time zone,
		db_ts_end timestamp with time zone,
		audit_record jsonb,
		bt_info_prev vrsn.bitemporal_record,
		bt_info_prev_group vrsn.bitemporal_record
	)
	
	TABLESPACE pg_default;
	
	
	ALTER TABLE IF EXISTS vrsn.test_table_check_run_detail
		ADD CONSTRAINT test_table_check_run_detail_pk PRIMARY KEY (step_run, rwn );

	return true;
end;$$;


--
-- Name: trace_ddl(boolean); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.trace_ddl(enable boolean) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    IF enable THEN
        CREATE TABLE IF NOT EXISTS vrsn.ddl_audit (
            event_time  timestamptz NOT NULL DEFAULT now(),
            schema_name TEXT        NOT NULL,
            object_name TEXT        NOT NULL,
            command_tag TEXT        NOT NULL,
            object_type TEXT        NOT NULL
        );

        CREATE INDEX IF NOT EXISTS ddl_audit_schema_object_idx
        ON vrsn.ddl_audit(schema_name, object_name);

        CREATE INDEX IF NOT EXISTS ddl_audit_event_time_idx
        ON vrsn.ddl_audit(event_time DESC);

        CREATE OR REPLACE FUNCTION vrsn.log_ddl_event()
        RETURNS event_trigger LANGUAGE plpgsql AS $$
        BEGIN
            INSERT INTO vrsn.ddl_audit(command_tag, object_type, object_name, schema_name)
            SELECT TG_TAG, objtype, objid::regclass::text, nspname
            FROM pg_event_trigger_ddl_commands() c
            JOIN pg_class cl ON cl.oid = c.objid
            JOIN pg_namespace n ON n.oid = cl.relnamespace;
        END;
        $$;

        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_event_trigger WHERE evtname = 'trg_vrsn_ddl_audit'
            ) THEN
                CREATE EVENT TRIGGER trg_vrsn_ddl_audit
                ON ddl_command_end
                EXECUTE FUNCTION vrsn.log_ddl_event();
            END IF;
        END;
        $$;
    ELSE
        DROP EVENT TRIGGER IF EXISTS trg_vrsn_ddl_audit;
    END IF;
END;
$_$;


--
-- Name: trigger_handler(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.trigger_handler() RETURNS trigger
    LANGUAGE plpgsql
    AS $$declare

	_updated_oldrec hstore;
	_updated_newrec hstore;
	
	view_full_name	vrsn.entity_fullname_type;

	tar_h_version 	integer=2;
begin
	if not TG_WHEN = 'INSTEAD OF' then
		raise exception 'Can''t use function direclty before manipulation of tables. Must be used with an "instead of" trigger';
	end if;
	
--	select * from vrsn.tar_h__handle_data(
	case tar_h_version
	when 2 then
		view_full_name.schema_name=TG_TABLE_SCHEMA;
		view_full_name.table_name=TG_TABLE_NAME;

		_updated_newrec = vrsn.__tar_h__handle_trigger(
			entity_full_name =>view_full_name,
			trigger_operation => TG_OP,
			oldrec =>OLD,
			newrec =>NEW
		);
	
	else
		raise exception 'Tar Handgling not set.';
	end case;
/*		
	raise notice '%', _updated_oldrec;
	raise notice '%', _updated_newrec;
*/	
	--OLD=populate_record(OLD,_updated_oldrec);
	NEW=populate_record(NEW,_updated_newrec);
	
	return NEW;
	
	
end;$$;


--
-- Name: trigger_inhibit_dml(); Type: FUNCTION; Schema: vrsn; Owner: -
--

CREATE FUNCTION vrsn.trigger_inhibit_dml() RETURNS trigger
    LANGUAGE plpgsql
    AS $$begin
	raise exception 'No DML allowed';
end;$$;


--
-- Name: entity_fullname_type_agg(vrsn.entity_fullname_type); Type: AGGREGATE; Schema: vrsn; Owner: -
--

CREATE AGGREGATE vrsn.entity_fullname_type_agg(vrsn.entity_fullname_type) (
    SFUNC = vrsn.__entity_fullname_type__array_agg_transfn,
    STYPE = vrsn.entity_fullname_type[],
    INITCOND = '{}',
    FINALFUNC = vrsn.__entity_fullname_type__array_agg_finalfn
);


--
-- Name: entity_fullname_type_string_agg(vrsn.entity_fullname_type, text); Type: AGGREGATE; Schema: vrsn; Owner: -
--

CREATE AGGREGATE vrsn.entity_fullname_type_string_agg(vrsn.entity_fullname_type, text) (
    SFUNC = vrsn.__entity_fullname_type__string_agg_transfn,
    STYPE = text,
    INITCOND = ''
);


--
-- Name: table_field_details_to_jts_agg(vrsn.table_field_details); Type: AGGREGATE; Schema: vrsn; Owner: -
--

CREATE AGGREGATE vrsn.table_field_details_to_jts_agg(vrsn.table_field_details) (
    SFUNC = vrsn.__table_field_details__to_jsonb_transfn,
    STYPE = jsonb,
    INITCOND = '{}'
);


--
-- Name: bitemporal_parent_table; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.bitemporal_parent_table (
    user_ts_range vrsn.bt_user_ts_range NOT NULL,
    db_ts_range vrsn.bt_db_ts_range NOT NULL,
    audit_record vrsn.bt_audit_record
);


--
-- Name: TABLE bitemporal_parent_table; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON TABLE vrsn.bitemporal_parent_table IS 'Table should be used in future as parent for all the bitemporal table';


--
-- Name: attribute_lineage_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.attribute_lineage_current (
    bt_info vrsn.bitemporal_record,
    attribute_id bigint NOT NULL,
    attribute_name text NOT NULL,
    schema_name text,
    entity_name text,
    json_schema_plus json
);


--
-- Name: attribute_mapping_to_entity_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.attribute_mapping_to_entity_current (
    bt_info vrsn.bitemporal_record,
    attribute_id bigint NOT NULL,
    attribute_name text NOT NULL,
    schema_name text NOT NULL,
    entity_name text NOT NULL,
    field_name text NOT NULL,
    attribute_type text
);


--
-- Name: admin__attribute_defintion_and_usage; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.admin__attribute_defintion_and_usage AS
 WITH field_json AS (
         SELECT attribute_mapping_to_entity_current.attribute_id,
            attribute_mapping_to_entity_current.schema_name,
            attribute_mapping_to_entity_current.attribute_name,
            jsonb_object_agg(attribute_mapping_to_entity_current.field_name, attribute_mapping_to_entity_current.attribute_type) AS fields_by_attribute
           FROM ONLY vrsn.attribute_mapping_to_entity_current
          GROUP BY attribute_mapping_to_entity_current.attribute_id, attribute_mapping_to_entity_current.schema_name, attribute_mapping_to_entity_current.attribute_name
        ), attribute_json AS (
         SELECT field_json.attribute_id,
            field_json.schema_name,
            jsonb_object_agg(field_json.attribute_name, field_json.fields_by_attribute) AS attributes_by_schema
           FROM field_json
          GROUP BY field_json.attribute_id, field_json.schema_name
        ), schema_json AS (
         SELECT attribute_json.attribute_id,
            jsonb_object_agg(attribute_json.schema_name, attribute_json.attributes_by_schema) AS mapping
           FROM attribute_json
          GROUP BY attribute_json.attribute_id
        )
 SELECT a.attribute_id,
    a.attribute_name,
        CASE
            WHEN (a.schema_name IS NULL) THEN 'global'::text
            ELSE format('%I.%I'::text, a.schema_name, a.entity_name)
        END AS attribute_scope,
    a.json_schema_plus,
    sj.mapping AS attribute_mapping_json
   FROM (ONLY vrsn.attribute_lineage_current a
     LEFT JOIN schema_json sj ON ((a.attribute_id = sj.attribute_id)));


--
-- Name: VIEW admin__attribute_defintion_and_usage; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON VIEW vrsn.admin__attribute_defintion_and_usage IS 'Lineage of each attribute and where it''s used';


--
-- Name: attribute_lineage; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.attribute_lineage AS
 SELECT s.attribute_id,
    s.attribute_name,
    s.schema_name,
    s.entity_name,
    s.json_schema_plus,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.attribute_lineage_current s;


--
-- Name: attribute_lineage_current_attribute_id_seq; Type: SEQUENCE; Schema: vrsn; Owner: -
--

ALTER TABLE vrsn.attribute_lineage_current ALTER COLUMN attribute_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME vrsn.attribute_lineage_current_attribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: attribute_lineage_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.attribute_lineage_history (
)
INHERITS (vrsn.attribute_lineage_current);
ALTER TABLE ONLY vrsn.attribute_lineage_history ALTER COLUMN bt_info SET NOT NULL;


--
-- Name: attribute_mapping_to_entity; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.attribute_mapping_to_entity AS
 SELECT s.attribute_id,
    s.attribute_name,
    s.schema_name,
    s.entity_name,
    s.field_name,
    s.attribute_type,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.attribute_mapping_to_entity_current s;


--
-- Name: attribute_mapping_to_entity_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.attribute_mapping_to_entity_history (
)
INHERITS (vrsn.attribute_mapping_to_entity_current);
ALTER TABLE ONLY vrsn.attribute_mapping_to_entity_history ALTER COLUMN bt_info SET NOT NULL;


--
-- Name: bitemporal_parent_attribute_table; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.bitemporal_parent_attribute_table (
    attribute_id bigint NOT NULL,
    idx text DEFAULT ''::text NOT NULL,
    attribute_value text
);


--
-- Name: def_entity_behavior_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.def_entity_behavior_current (
    bt_info vrsn.bitemporal_record NOT NULL,
    entity_full_name vrsn.entity_fullname_dmn NOT NULL,
    current_view_full_name vrsn.entity_fullname_dmn NOT NULL,
    current_table_full_name vrsn.entity_fullname_dmn NOT NULL,
    history_table_full_name vrsn.entity_fullname_dmn NOT NULL,
    attribute_entity_full_name vrsn.entity_fullname_dmn,
    historice_entity vrsn.historice_entity_behaviour DEFAULT 'always'::vrsn.historice_entity_behaviour NOT NULL,
    enable_history_attributes boolean DEFAULT false NOT NULL,
    main_fields_list text,
    cached_fields_list text,
    mitigate_conflicts boolean DEFAULT true NOT NULL,
    ignore_unchanged_values boolean DEFAULT true NOT NULL,
    enable_attribute_to_fields_replacement boolean DEFAULT false NOT NULL,
    field_special_behavior jsonb,
    CONSTRAINT def_entity_behavior_current_check CHECK (((NOT enable_history_attributes) OR (attribute_entity_full_name IS NOT NULL)))
);


--
-- Name: COLUMN def_entity_behavior_current.main_fields_list; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON COLUMN vrsn.def_entity_behavior_current.main_fields_list IS 'list of main fields
when of them changes historices of enitre table is triggered';


--
-- Name: COLUMN def_entity_behavior_current.cached_fields_list; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON COLUMN vrsn.def_entity_behavior_current.cached_fields_list IS 'list of fields containing attribute cached';


--
-- Name: COLUMN def_entity_behavior_current.enable_attribute_to_fields_replacement; Type: COMMENT; Schema: vrsn; Owner: -
--

COMMENT ON COLUMN vrsn.def_entity_behavior_current.enable_attribute_to_fields_replacement IS 'If yes, trigger looks for each attribute with same name of an entity fields and replace it.
e.g.
if  there is an attribute called "foo" and "foo" is also a field of main table, the trigger replace the infomation in the new record';


--
-- Name: def_entity_behavior; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.def_entity_behavior AS
 SELECT s.entity_full_name,
    s.current_view_full_name,
    s.current_table_full_name,
    s.history_table_full_name,
    s.attribute_entity_full_name,
    s.historice_entity,
    s.enable_history_attributes,
    s.main_fields_list,
    s.cached_fields_list,
    s.mitigate_conflicts,
    s.ignore_unchanged_values,
    s.enable_attribute_to_fields_replacement,
    s.field_special_behavior,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.def_entity_behavior_current s;


--
-- Name: def_entity_behavior_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.def_entity_behavior_history (
)
INHERITS (vrsn.def_entity_behavior_current);


--
-- Name: parameter_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.parameter_current (
    bt_info vrsn.bitemporal_record NOT NULL,
    context text NOT NULL,
    sub_context text NOT NULL,
    description text,
    properties jsonb
);


--
-- Name: parameter; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.parameter AS
 SELECT s.context,
    s.sub_context,
    s.description,
    s.properties,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.parameter_current s;


--
-- Name: parameter_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.parameter_history (
)
INHERITS (vrsn.parameter_current);


--
-- Name: test_table_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_current (
    bt_info vrsn.bitemporal_record NOT NULL,
    id integer NOT NULL,
    sometext text,
    main_ts timestamp with time zone,
    somevalue bigint,
    many_fields vrsn.cached_attribute
);


--
-- Name: test_table; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.test_table AS
 SELECT s.id,
    s.sometext,
    s.main_ts,
    s.somevalue,
    s.many_fields,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.test_table_current s;


--
-- Name: test_table_attribute_current; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_attribute_current (
    bt_info vrsn.bitemporal_record NOT NULL,
    id integer NOT NULL,
    attribute_id integer NOT NULL,
    idx text DEFAULT '0'::text NOT NULL,
    attribute_value text
);


--
-- Name: test_table_attribute; Type: VIEW; Schema: vrsn; Owner: -
--

CREATE VIEW vrsn.test_table_attribute AS
 SELECT s.id,
    s.attribute_id,
    s.idx,
    s.attribute_value,
    false AS is_closed,
    NULL::text AS modify_user_id,
    NULL::timestamp with time zone AS modify_ts,
    NULL::jsonb AS action_hints
   FROM ONLY vrsn.test_table_attribute_current s;


--
-- Name: test_table_attribute_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_attribute_history (
)
INHERITS (vrsn.test_table_attribute_current);


--
-- Name: test_table_check_run; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_check_run (
    step_run integer NOT NULL,
    step_descritpion text,
    is_valid boolean
);


--
-- Name: test_table_check_run_attribute_detail; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_check_run_attribute_detail (
    step_run integer NOT NULL,
    rwn bigint NOT NULL,
    table_current boolean,
    id integer NOT NULL,
    attribute_id integer NOT NULL,
    idx text DEFAULT '0'::text NOT NULL,
    attribute_value text,
    error_found jsonb,
    deactivation_ts timestamp with time zone,
    check_closing_period boolean,
    check_actual_ts boolean,
    check_db_period boolean,
    rwn_seq bigint,
    check_user_period boolean,
    check_actual_ts_compliance boolean,
    check_json_schema boolean,
    actual_insert_ts timestamp with time zone,
    actual_close_ts timestamp with time zone,
    db_close_finite boolean,
    user_close_finite boolean,
    is_active boolean,
    user_ts_start timestamp with time zone,
    user_ts_end timestamp with time zone,
    db_ts_start timestamp with time zone,
    db_ts_end timestamp with time zone,
    audit_record jsonb,
    bt_info_prev vrsn.bitemporal_record,
    bt_info_prev_group vrsn.bitemporal_record
);


--
-- Name: test_table_check_run_detail; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_check_run_detail (
    step_run integer NOT NULL,
    rwn bigint NOT NULL,
    table_current boolean,
    id integer,
    sometext text,
    main_ts timestamp with time zone,
    somevalue bigint,
    many_fields vrsn.cached_attribute,
    error_found jsonb,
    deactivation_ts timestamp with time zone,
    check_closing_period boolean,
    check_actual_ts boolean,
    check_db_period boolean,
    rwn_seq bigint,
    check_user_period boolean,
    check_actual_ts_compliance boolean,
    check_json_schema boolean,
    actual_insert_ts timestamp with time zone,
    actual_close_ts timestamp with time zone,
    db_close_finite boolean,
    user_close_finite boolean,
    is_active boolean,
    user_ts_start timestamp with time zone,
    user_ts_end timestamp with time zone,
    db_ts_start timestamp with time zone,
    db_ts_end timestamp with time zone,
    audit_record jsonb,
    bt_info_prev vrsn.bitemporal_record,
    bt_info_prev_group vrsn.bitemporal_record
);


--
-- Name: test_table_current_id_seq; Type: SEQUENCE; Schema: vrsn; Owner: -
--

ALTER TABLE vrsn.test_table_current ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME vrsn.test_table_current_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    CYCLE
);


--
-- Name: test_table_history; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.test_table_history (
)
INHERITS (vrsn.test_table_current);


--
-- Name: trigger_activation_record_base_changelog; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE TABLE vrsn.trigger_activation_record_base_changelog (
    active_row boolean
)
INHERITS (vrsn.trigger_activation_record_base)
WITH (autovacuum_enabled='true', toast.autovacuum_enabled='true');
ALTER TABLE ONLY vrsn.trigger_activation_record_base_changelog ALTER COLUMN last_update_ts SET NOT NULL;


--
-- Name: trigger_activation_record_stack_trace_p00; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE UNLOGGED TABLE vrsn.trigger_activation_record_stack_trace_p00 (
)
INHERITS (vrsn.trigger_activation_record_stack_trace_parent);


--
-- Name: trigger_activation_record_stack_trace_p01; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE UNLOGGED TABLE vrsn.trigger_activation_record_stack_trace_p01 (
)
INHERITS (vrsn.trigger_activation_record_stack_trace_parent);


--
-- Name: trigger_activation_record_stack_trace_p02; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE UNLOGGED TABLE vrsn.trigger_activation_record_stack_trace_p02 (
)
INHERITS (vrsn.trigger_activation_record_stack_trace_parent);


--
-- Name: trigger_activation_record_stack_trace_p03; Type: TABLE; Schema: vrsn; Owner: -
--

CREATE UNLOGGED TABLE vrsn.trigger_activation_record_stack_trace_p03 (
)
INHERITS (vrsn.trigger_activation_record_stack_trace_parent);


--
-- Name: trigger_activation_record_stack_trace_parent_rec_id_seq; Type: SEQUENCE; Schema: vrsn; Owner: -
--

ALTER TABLE vrsn.trigger_activation_record_stack_trace_parent ALTER COLUMN rec_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME vrsn.trigger_activation_record_stack_trace_parent_rec_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    CYCLE
);


--
-- Name: def_entity_behavior_history historice_entity; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history ALTER COLUMN historice_entity SET DEFAULT 'always'::vrsn.historice_entity_behaviour;


--
-- Name: def_entity_behavior_history enable_history_attributes; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history ALTER COLUMN enable_history_attributes SET DEFAULT false;


--
-- Name: def_entity_behavior_history mitigate_conflicts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history ALTER COLUMN mitigate_conflicts SET DEFAULT true;


--
-- Name: def_entity_behavior_history ignore_unchanged_values; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history ALTER COLUMN ignore_unchanged_values SET DEFAULT true;


--
-- Name: def_entity_behavior_history enable_attribute_to_fields_replacement; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history ALTER COLUMN enable_attribute_to_fields_replacement SET DEFAULT false;


--
-- Name: test_table_attribute_history idx; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_attribute_history ALTER COLUMN idx SET DEFAULT '0'::text;


--
-- Name: trigger_activation_record_base_changelog last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_base_changelog ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_base_changelog bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_base_changelog ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_p00 last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p00 ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack_trace_p00 bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p00 ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_p00 status; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p00 ALTER COLUMN status SET DEFAULT '{}'::jsonb;


--
-- Name: trigger_activation_record_stack_trace_p00 trace_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p00 ALTER COLUMN trace_ts SET DEFAULT clock_timestamp();


--
-- Name: trigger_activation_record_stack_trace_p01 last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p01 ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack_trace_p01 bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p01 ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_p01 status; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p01 ALTER COLUMN status SET DEFAULT '{}'::jsonb;


--
-- Name: trigger_activation_record_stack_trace_p01 trace_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p01 ALTER COLUMN trace_ts SET DEFAULT clock_timestamp();


--
-- Name: trigger_activation_record_stack_trace_p02 last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p02 ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack_trace_p02 bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p02 ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_p02 status; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p02 ALTER COLUMN status SET DEFAULT '{}'::jsonb;


--
-- Name: trigger_activation_record_stack_trace_p02 trace_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p02 ALTER COLUMN trace_ts SET DEFAULT clock_timestamp();


--
-- Name: trigger_activation_record_stack_trace_p03 last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p03 ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack_trace_p03 bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p03 ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_p03 status; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p03 ALTER COLUMN status SET DEFAULT '{}'::jsonb;


--
-- Name: trigger_activation_record_stack_trace_p03 trace_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p03 ALTER COLUMN trace_ts SET DEFAULT clock_timestamp();


--
-- Name: trigger_activation_record_stack_trace_parent last_update_ts; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_parent ALTER COLUMN last_update_ts SET DEFAULT now();


--
-- Name: trigger_activation_record_stack_trace_parent bt_info_name; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_parent ALTER COLUMN bt_info_name SET DEFAULT 'bt_info'::text;


--
-- Name: trigger_activation_record_stack_trace_parent status; Type: DEFAULT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_parent ALTER COLUMN status SET DEFAULT '{}'::jsonb;


--
-- Name: attribute_lineage_current attribute_lineage_current_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_lineage_current
    ADD CONSTRAINT attribute_lineage_current_pk PRIMARY KEY (attribute_id);


--
-- Name: attribute_lineage_current attribute_lineage_current_uk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_lineage_current
    ADD CONSTRAINT attribute_lineage_current_uk UNIQUE (attribute_name, schema_name, entity_name) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: attribute_lineage_history attribute_lineage_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_lineage_history
    ADD CONSTRAINT attribute_lineage_history_pk PRIMARY KEY (attribute_id, bt_info);


--
-- Name: attribute_mapping_to_entity_current attribute_mapping_to_entity_current_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_mapping_to_entity_current
    ADD CONSTRAINT attribute_mapping_to_entity_current_pk PRIMARY KEY (attribute_id, schema_name, entity_name, field_name);


--
-- Name: attribute_mapping_to_entity_history attribute_mapping_to_entity_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_mapping_to_entity_history
    ADD CONSTRAINT attribute_mapping_to_entity_history_pk PRIMARY KEY (attribute_id, schema_name, entity_name, field_name, bt_info);


--
-- Name: bitemporal_parent_attribute_table bitemporal_parent_attribute_table_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.bitemporal_parent_attribute_table
    ADD CONSTRAINT bitemporal_parent_attribute_table_pk PRIMARY KEY (attribute_id, idx);


--
-- Name: def_entity_behavior_current def_entity_behavior_current_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_current
    ADD CONSTRAINT def_entity_behavior_current_pk PRIMARY KEY (entity_full_name);


--
-- Name: def_entity_behavior_history def_entity_behavior_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.def_entity_behavior_history
    ADD CONSTRAINT def_entity_behavior_history_pk PRIMARY KEY (entity_full_name, bt_info);


--
-- Name: parameter_history parameter_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.parameter_history
    ADD CONSTRAINT parameter_history_pk PRIMARY KEY (context, sub_context, bt_info);


--
-- Name: parameter_current parameter_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.parameter_current
    ADD CONSTRAINT parameter_pk PRIMARY KEY (context, sub_context);


--
-- Name: test_table_attribute_current test_table_attribute_current_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_attribute_current
    ADD CONSTRAINT test_table_attribute_current_pk PRIMARY KEY (id, attribute_id, idx);


--
-- Name: test_table_attribute_history test_table_attribute_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_attribute_history
    ADD CONSTRAINT test_table_attribute_history_pk PRIMARY KEY (id, attribute_id, idx, bt_info);


--
-- Name: test_table_check_run_attribute_detail test_table_check_run_attribute_detail_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_check_run_attribute_detail
    ADD CONSTRAINT test_table_check_run_attribute_detail_pk PRIMARY KEY (step_run, rwn);


--
-- Name: test_table_check_run_detail test_table_check_run_detail_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_check_run_detail
    ADD CONSTRAINT test_table_check_run_detail_pk PRIMARY KEY (step_run, rwn);


--
-- Name: test_table_check_run test_table_check_run_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_check_run
    ADD CONSTRAINT test_table_check_run_pk PRIMARY KEY (step_run);


--
-- Name: test_table_current test_table_current_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_current
    ADD CONSTRAINT test_table_current_pk PRIMARY KEY (id);


--
-- Name: test_table_history test_table_history_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.test_table_history
    ADD CONSTRAINT test_table_history_pk PRIMARY KEY (id, bt_info);


--
-- Name: trigger_activation_record_base_changelog trigger_activation_record_base_changelog_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_base_changelog
    ADD CONSTRAINT trigger_activation_record_base_changelog_pk PRIMARY KEY (entity_full_name, last_update_ts);


--
-- Name: trigger_activation_record_base_changelog trigger_activation_record_base_changelog_uk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_base_changelog
    ADD CONSTRAINT trigger_activation_record_base_changelog_uk UNIQUE (entity_full_name, active_row) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: trigger_activation_record_base trigger_activation_record_base_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_base
    ADD CONSTRAINT trigger_activation_record_base_pk PRIMARY KEY (entity_full_name);


--
-- Name: trigger_activation_record_stack trigger_activation_record_stack_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack
    ADD CONSTRAINT trigger_activation_record_stack_pk PRIMARY KEY (entity_full_name);


--
-- Name: trigger_activation_record_stack_trace_p00 trigger_activation_record_stack_trace_p00_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p00
    ADD CONSTRAINT trigger_activation_record_stack_trace_p00_pk PRIMARY KEY (rec_id);


--
-- Name: trigger_activation_record_stack_trace_p01 trigger_activation_record_stack_trace_p01_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p01
    ADD CONSTRAINT trigger_activation_record_stack_trace_p01_pk PRIMARY KEY (rec_id);


--
-- Name: trigger_activation_record_stack_trace_p02 trigger_activation_record_stack_trace_p02_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p02
    ADD CONSTRAINT trigger_activation_record_stack_trace_p02_pk PRIMARY KEY (rec_id);


--
-- Name: trigger_activation_record_stack_trace_p03 trigger_activation_record_stack_trace_p03_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_p03
    ADD CONSTRAINT trigger_activation_record_stack_trace_p03_pk PRIMARY KEY (rec_id);


--
-- Name: trigger_activation_record_stack_trace_parent trigger_activation_record_stack_trace_parent_pk; Type: CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.trigger_activation_record_stack_trace_parent
    ADD CONSTRAINT trigger_activation_record_stack_trace_parent_pk PRIMARY KEY (rec_id);


--
-- Name: attribute_lineage_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_lineage_current_db_tsr_ix ON vrsn.attribute_lineage_current USING gist (((bt_info).db_ts_range));


--
-- Name: attribute_lineage_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_lineage_current_user_db_tsr_ix ON vrsn.attribute_lineage_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: attribute_lineage_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_lineage_history_db_tsr_ix ON vrsn.attribute_lineage_history USING gist (((bt_info).db_ts_range));


--
-- Name: attribute_lineage_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_lineage_history_user_db_tsr_ix ON vrsn.attribute_lineage_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: attribute_mapping_to_entity_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_mapping_to_entity_current_db_tsr_ix ON vrsn.attribute_mapping_to_entity_current USING gist (((bt_info).db_ts_range));


--
-- Name: attribute_mapping_to_entity_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_mapping_to_entity_current_user_db_tsr_ix ON vrsn.attribute_mapping_to_entity_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: attribute_mapping_to_entity_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_mapping_to_entity_history_db_tsr_ix ON vrsn.attribute_mapping_to_entity_history USING gist (((bt_info).db_ts_range));


--
-- Name: attribute_mapping_to_entity_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX attribute_mapping_to_entity_history_user_db_tsr_ix ON vrsn.attribute_mapping_to_entity_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: def_entity_behavior_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX def_entity_behavior_current_db_tsr_ix ON vrsn.def_entity_behavior_current USING gist (((bt_info).db_ts_range));


--
-- Name: def_entity_behavior_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX def_entity_behavior_current_user_db_tsr_ix ON vrsn.def_entity_behavior_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: def_entity_behavior_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX def_entity_behavior_history_db_tsr_ix ON vrsn.def_entity_behavior_history USING gist (((bt_info).db_ts_range));


--
-- Name: def_entity_behavior_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX def_entity_behavior_history_user_db_tsr_ix ON vrsn.def_entity_behavior_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: parameter_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX parameter_current_db_tsr_ix ON vrsn.parameter_current USING gist (((bt_info).db_ts_range));


--
-- Name: parameter_current_properties_idx; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX parameter_current_properties_idx ON vrsn.parameter_current USING gin (properties) WITH (fastupdate='true');


--
-- Name: parameter_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX parameter_current_user_db_tsr_ix ON vrsn.parameter_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: parameter_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX parameter_history_db_tsr_ix ON vrsn.parameter_history USING gist (((bt_info).db_ts_range));


--
-- Name: parameter_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX parameter_history_user_db_tsr_ix ON vrsn.parameter_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: test_table_attribute_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_attribute_current_db_tsr_ix ON vrsn.test_table_attribute_current USING gist (((bt_info).db_ts_range));


--
-- Name: test_table_attribute_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_attribute_current_user_db_tsr_ix ON vrsn.test_table_attribute_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: test_table_attribute_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_attribute_history_db_tsr_ix ON vrsn.test_table_attribute_history USING gist (((bt_info).db_ts_range));


--
-- Name: test_table_attribute_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_attribute_history_user_db_tsr_ix ON vrsn.test_table_attribute_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: test_table_current_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_current_db_tsr_ix ON vrsn.test_table_current USING gist (((bt_info).db_ts_range));


--
-- Name: test_table_current_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_current_user_db_tsr_ix ON vrsn.test_table_current USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: test_table_history_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_history_db_tsr_ix ON vrsn.test_table_history USING gist (((bt_info).db_ts_range));


--
-- Name: test_table_history_user_db_tsr_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX test_table_history_user_db_tsr_ix ON vrsn.test_table_history USING gist (((bt_info).user_ts_range), ((bt_info).db_ts_range));


--
-- Name: trigger_activation_record_stack_trace_p00_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX trigger_activation_record_stack_trace_p00_ix ON vrsn.trigger_activation_record_stack_trace_p00 USING btree (entity_full_name, last_update_ts) WITH (deduplicate_items='true');


--
-- Name: trigger_activation_record_stack_trace_p01_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX trigger_activation_record_stack_trace_p01_ix ON vrsn.trigger_activation_record_stack_trace_p01 USING btree (entity_full_name, last_update_ts) WITH (deduplicate_items='true');


--
-- Name: trigger_activation_record_stack_trace_p02_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX trigger_activation_record_stack_trace_p02_ix ON vrsn.trigger_activation_record_stack_trace_p02 USING btree (entity_full_name, last_update_ts) WITH (deduplicate_items='true');


--
-- Name: trigger_activation_record_stack_trace_p03_ix; Type: INDEX; Schema: vrsn; Owner: -
--

CREATE INDEX trigger_activation_record_stack_trace_p03_ix ON vrsn.trigger_activation_record_stack_trace_p03 USING btree (entity_full_name, last_update_ts) WITH (deduplicate_items='true');


--
-- Name: admin__attribute_defintion_and_usage attribute_defintion_and_usage_trg; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER attribute_defintion_and_usage_trg INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.admin__attribute_defintion_and_usage FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_inhibit_dml();


--
-- Name: bitemporal_parent_table bt_parent_table_trg; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER bt_parent_table_trg BEFORE INSERT OR DELETE OR UPDATE OR TRUNCATE ON vrsn.bitemporal_parent_table FOR EACH STATEMENT EXECUTE FUNCTION vrsn.trigger_inhibit_dml();


--
-- Name: attribute_lineage trg_attribute_lineage; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_attribute_lineage INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.attribute_lineage FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: attribute_mapping_to_entity trg_attribute_mapping_to_table; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_attribute_mapping_to_table INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.attribute_mapping_to_entity FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: def_entity_behavior trg_def_entity_behavior; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_def_entity_behavior INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.def_entity_behavior FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: parameter trg_parameter; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_parameter INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.parameter FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: test_table trg_test_table; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_test_table INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.test_table FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: test_table_attribute trg_test_table_attribute; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trg_test_table_attribute INSTEAD OF INSERT OR DELETE OR UPDATE ON vrsn.test_table_attribute FOR EACH ROW EXECUTE FUNCTION vrsn.trigger_handler();


--
-- Name: trigger_activation_record_stack trigger_activation_record_stack_trg; Type: TRIGGER; Schema: vrsn; Owner: -
--

CREATE TRIGGER trigger_activation_record_stack_trg BEFORE INSERT OR DELETE OR UPDATE ON vrsn.trigger_activation_record_stack FOR EACH STATEMENT EXECUTE FUNCTION vrsn.trigger_inhibit_dml();


--
-- Name: attribute_mapping_to_entity_current attribute_mapping_to_entity_current_fk_attribute_id; Type: FK CONSTRAINT; Schema: vrsn; Owner: -
--

ALTER TABLE ONLY vrsn.attribute_mapping_to_entity_current
    ADD CONSTRAINT attribute_mapping_to_entity_current_fk_attribute_id FOREIGN KEY (attribute_id) REFERENCES vrsn.attribute_lineage_current(attribute_id) DEFERRABLE INITIALLY DEFERRED NOT VALID;


--
-- PostgreSQL database dump complete
--


SET check_function_bodies = on;
