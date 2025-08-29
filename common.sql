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
-- Name: common; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA common;


--
-- Name: key_value_list; Type: TYPE; Schema: common; Owner: -
--

CREATE TYPE common.key_value_list AS (
	attribute_name text,
	idx text,
	attribute_value text,
	attribute_type text
);


--
-- Name: TYPE key_value_list; Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON TYPE common.key_value_list IS 'Standard representation of a key-value table, with idx for array, and type to better conversion';


--
-- Name: __jsonb_schema__compile_conditional(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__compile_conditional(p_data jsonb, p_schema jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
	temp_errors text[];
	if_schema jsonb;
	then_schema jsonb;
	else_schema jsonb;
	condition_valid boolean;
begin
	-- se non c'è if, non c'è niente da validare
	if not (p_schema ? 'if') then
		return p_schema;
	end if;
	
	if_schema := p_schema->'if';
	then_schema := p_schema->'then';
	else_schema := p_schema->'else';

	-- rimuovo le parti condizionali
	p_schema = p_schema - array['if','then','else'];
	
	-- valuta la condizione if
	temp_errors := common.__jsonb_schema__validate(p_data, if_schema);
	condition_valid := array_length(temp_errors, 1) is null;
--raise notice '%', condition_valid;
	-- applica then o else in base alla condizione
	if condition_valid then
		-- condizione vera: applica then se presente
		if then_schema is not null then
			p_schema = common.jsonb_recursive_merge(p_schema, then_schema);
		end if;
	else
		-- condizione falsa: applica else se presente
		if else_schema is not null then
			p_schema = common.jsonb_recursive_merge(p_schema, else_schema);
		end if;
	end if;
	
	return p_schema;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__compile_conditional(p_data jsonb, p_schema jsonb); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__compile_conditional(p_data jsonb, p_schema jsonb) IS 'Compila lo schema condizionale: if/then/else.';


--
-- Name: __jsonb_schema__validate(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate(p_data jsonb, p_schema jsonb, p_path text DEFAULT '$'::text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
	temp_errors text[];
begin

--raise notice '% - %', p_path, p_schema->>'required';
	-- valida conditional p_schema (if/then/else)
--	temp_errors := common.__jsonb_schema__validate_conditional(p_data, p_schema, p_path);
--	error_list := error_list || temp_errors;

	

	-- compila conditional p_schema (if/then/else)
	if  p_schema ? 'if' then
		p_schema= common.__jsonb_schema__compile_conditional(p_data, p_schema);
--		raise notice '%', jsonb_pretty(p_schema);
	end if;

	-- valida il tipo principale
	temp_errors := common.__jsonb_schema__validate_type(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;


	-- valida le proprietà se è un oggetto
	if jsonb_typeof(p_data) = 'object' then		
		if  p_schema ? 'properties' then
			temp_errors := common.__jsonb_schema__validate_properties(p_data, p_schema, p_path);
			error_list := error_list || temp_errors;
		end if;
	end if;
	
	-- valida i required fields
	if p_schema ? 'required' then
		temp_errors := common.__jsonb_schema__validate_required(p_data, p_schema, p_path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida enum se presente
	if p_schema ? 'enum' or p_schema ? 'const' then
		temp_errors := common.__jsonb_schema__validate_enum(p_data, p_schema, p_path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida format se presente
	if p_schema ? 'format' then
		temp_errors := common.__jsonb_schema__validate_format(p_data, p_schema, p_path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida string constraints
	temp_errors := common.__jsonb_schema__validate_string_constraints(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;
	
	-- valida number constraints
	temp_errors := common.__jsonb_schema__validate_number_constraints(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;
	
	-- valida array constraints
	temp_errors := common.__jsonb_schema__validate_array_constraints(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;
	
	-- valida object constraints
	temp_errors := common.__jsonb_schema__validate_object_constraints(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;
	
	-- valida logical operators (anyOf, allOf, oneOf, not)
	temp_errors := common.__jsonb_schema__validate_logical(p_data, p_schema, p_path);
	error_list := error_list || temp_errors;
	

	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate(p_data jsonb, p_schema jsonb, p_path text) IS 'Valida un documento JSONB contro un JSON schema completo. Include tutte le validazioni: tipo, proprietà, required, enum, format, string/number/array/object constraints e operatori logici.';


--
-- Name: __jsonb_schema__validate_array_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_array_constraints(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	array_length integer;
	min_items integer;
	max_items integer;
	items_schema jsonb;
	item_data jsonb;
	item_index integer;
	current_path text;
	temp_errors text[];
	error_list text[] := array[]::text[];
	unique_check jsonb[];
	item jsonb;
begin
	-- solo array possono avere array constraints
	if jsonb_typeof(p_data) != 'array' then
		return error_list;
	end if;
	
	array_length := jsonb_array_length(p_data);
	
	-- minItems validation
	if p_schema ? 'minItems' then
		min_items := (p_schema->>'minItems')::integer;
		if array_length < min_items then
			error_list := error_list || format('path %s: array length %s is less than minItems %s', 
				p_path, array_length, min_items);
		end if;
	end if;
	
	-- maxItems validation
	if p_schema ? 'maxItems' then
		max_items := (p_schema->>'maxItems')::integer;
		if array_length > max_items then
			error_list := error_list || format('path %s: array length %s exceeds maxItems %s', 
				p_path, array_length, max_items);
		end if;
	end if;
	
	-- uniqueItems validation
	if p_schema ? 'uniqueItems' and (p_schema->>'uniqueItems')::boolean = true then
		-- costruisce array per controllo unicità
		for item in select jsonb_array_elements(p_data)
		loop
			if item = any(unique_check) then
				error_list := error_list || format('path %s: array contains duplicate items', p_path);
				exit;
			end if;
			unique_check := unique_check || item;
		end loop;
	end if;
	
	-- items validation (p_schema per ogni elemento dell'array)
	if p_schema ? 'items' then
		items_schema := p_schema->'items';
		item_index := 0;
		
		for item_data in select jsonb_array_elements(p_data)
		loop
			current_path := format('%s[%s]', p_path, item_index);
			
			-- valida ricorsivamente ogni elemento
			temp_errors := common.__jsonb_schema__validate(item_data, items_schema, current_path);
			error_list := error_list || temp_errors;
			
			item_index := item_index + 1;
		end loop;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_array_constraints(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_array_constraints(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida i vincoli degli array: minItems, maxItems, uniqueItems, items.';


--
-- Name: __jsonb_schema__validate_conditional(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_conditional(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
	temp_errors text[];
	if_schema jsonb;
	then_schema jsonb;
	else_schema jsonb;
	condition_valid boolean;
begin
	-- se non c'è if, non c'è niente da validare
	if not (p_schema ? 'if') then
		return error_list;
	end if;
	
	if_schema := p_schema->'if';
	then_schema := p_schema->'then';
	else_schema := p_schema->'else';
	
	-- valuta la condizione if
	temp_errors := common.__jsonb_schema__validate(p_data, if_schema, p_path);
	condition_valid := array_length(temp_errors, 1) is null;
	
	-- applica then o else in base alla condizione
	if condition_valid then
		-- condizione vera: applica then se presente
		if then_schema is not null then
			temp_errors := common.__jsonb_schema__validate(p_data, then_schema, p_path);
			error_list := error_list || temp_errors;
		end if;
	else
		-- condizione falsa: applica else se presente
		if else_schema is not null then
			temp_errors := common.__jsonb_schema__validate(p_data, else_schema, p_path);
			error_list := error_list || temp_errors;
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_conditional(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_conditional(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida gli schemi condizionali JSON schema: if/then/else.';


--
-- Name: __jsonb_schema__validate_enum(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_enum(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
begin
	if not (p_schema->'enum' @> to_jsonb(p_data)) then
		error_list := error_list || format('path %s: value %s not in enum %s', 
			p_path, p_data::text, (p_schema->'enum')::text);
	end if;

	if p_schema ? 'const' then
		if not (p_schema->'const' @> to_jsonb(p_data)) then
			error_list := error_list || format('path %s: value %s not equal to %s', 
			p_path, p_data::text, (p_schema->>'const'));
		end if;
	end if;



	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_enum(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_enum(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida che il valore sia presente nell''array enum specificato nello p_schema.';


--
-- Name: __jsonb_schema__validate_format(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_format(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $_$
declare
	format_type text;
	data_text text;
	error_list text[] := array[]::text[];
begin
	-- solo stringhe possono avere format
	if jsonb_typeof(p_data) != 'string' then
		return error_list;
	end if;
	
	format_type := p_schema->>'format';
	data_text := p_data #>> '{}'; -- estrae il valore stringa
	
	case format_type
		when 'date-time' then
			-- RFC 3339 date-time format
			if not (data_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$') then
				error_list := error_list || format('path %s: invalid date-time format "%s"', p_path, data_text);
			else
				-- verifica che sia una p_data valida
				begin
					perform data_text::timestamp with time zone;
				exception
					when others then
						error_list := error_list || format('path %s: invalid date-time value "%s"', p_path, data_text);
				end;
			end if;
			
		when 'date' then
			-- YYYY-MM-DD format
			if not (data_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') then
				error_list := error_list || format('path %s: invalid date format "%s"', p_path, data_text);
			else
				begin
					perform data_text::date;
				exception
					when others then
						error_list := error_list || format('path %s: invalid date value "%s"', p_path, data_text);
				end;
			end if;
			
		when 'time' then
			-- HH:MM:SS format
			if not (data_text ~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?$') then
				error_list := error_list || format('path %s: invalid time format "%s"', p_path, data_text);
			else
				begin
					perform data_text::time;
				exception
					when others then
						error_list := error_list || format('path %s: invalid time value "%s"', p_path, data_text);
				end;
			end if;
			
		when 'email' then
			-- basic email validation
			if not (data_text ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') then
				error_list := error_list || format('path %s: invalid email format "%s"', p_path, data_text);
			end if;
			
		when 'uri' then
			-- basic URI validation
			if not (data_text ~ '^[a-zA-Z][a-zA-Z0-9+.-]*:') then
				error_list := error_list || format('path %s: invalid uri format "%s"', p_path, data_text);
			end if;
			
		when 'uuid' then
			-- UUID v4 format
			if not (data_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
				error_list := error_list || format('path %s: invalid uuid format "%s"', p_path, data_text);
			else
				begin
					perform data_text::uuid;
				exception
					when others then
						error_list := error_list || format('path %s: invalid uuid value "%s"', p_path, data_text);
				end;
			end if;
			
		when 'ipv4' then
			-- IPv4 format
			if not (data_text ~ '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') then
				error_list := error_list || format('path %s: invalid ipv4 format "%s"', p_path, data_text);
			else
				begin
					perform data_text::inet;
				exception
					when others then
						error_list := error_list || format('path %s: invalid ipv4 value "%s"', p_path, data_text);
				end;
			end if;
			
		when 'ipv6' then
			-- basic IPv6 validation (semplificata)
			if not (data_text ~ '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$') then
				error_list := error_list || format('path %s: invalid ipv6 format "%s"', p_path, data_text);
			end if;
			
		else
			-- format non supportato, ma non è un errore
			null;
	end case;
	
	return error_list;
end;
$_$;


--
-- Name: FUNCTION __jsonb_schema__validate_format(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_format(p_data jsonb, p_schema jsonb, p_path text) IS 'Valida i formati stringa (date-time, date, time, email, uri, uuid, ipv4, ipv6) secondo le specifiche JSON p_schema.';


--
-- Name: __jsonb_schema__validate_logical(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_logical(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
	temp_errors text[];
	sub_schema jsonb;
	valid_count integer;
	any_of_valid boolean;
	all_of_errors text[];
	one_of_valid_count integer;
begin
	-- anyOf: almeno uno degli schemi deve essere valido
	if p_schema ? 'anyOf' then
		any_of_valid := false;
		
		for sub_schema in select jsonb_array_elements(p_schema->'anyOf')
		loop
			temp_errors := common.__jsonb_schema__validate(p_data, sub_schema, p_path);
			if array_length(temp_errors, 1) is null then
				any_of_valid := true;
				exit; -- non appena uno è valido, esci
			end if;
		end loop;
		
		if not any_of_valid then
			error_list := error_list || format('path %s: does not match any schema in anyOf', p_path);
		end if;
	end if;
	
	-- allOf: tutti gli schemi devono essere validi
	if p_schema ? 'allOf' then
		all_of_errors := array[]::text[];
		
		for sub_schema in select jsonb_array_elements(p_schema->'allOf')
		loop
			temp_errors := common.__jsonb_schema__validate(p_data, sub_schema, p_path);
			all_of_errors := all_of_errors || temp_errors;
		end loop;
		
		error_list := error_list || all_of_errors;
	end if;
	
	-- oneOf: esattamente uno p_schema deve essere valido
	if p_schema ? 'oneOf' then
		one_of_valid_count := 0;
		
		for sub_schema in select jsonb_array_elements(p_schema->'oneOf')
		loop
			temp_errors := common.__jsonb_schema__validate(p_data, sub_schema, p_path);
			if array_length(temp_errors, 1) is null then
				one_of_valid_count := one_of_valid_count + 1;
			end if;
		end loop;
		
		if one_of_valid_count = 0 then
			error_list := error_list || format('path %s: does not match any schema in oneOf', p_path);
		elsif one_of_valid_count > 1 then
			error_list := error_list || format('path %s: matches %s schemas in oneOf, expected exactly 1', 
				p_path, one_of_valid_count);
		end if;
	end if;
	
	-- not: lo p_schema NON deve essere valido
	if p_schema ? 'not' then
		temp_errors := common.__jsonb_schema__validate(p_data, p_schema->'not', p_path);
		if array_length(temp_errors, 1) is null then
			error_list := error_list || format('path %s: should not be valid against the "not" schema', p_path);
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_logical(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_logical(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida gli operatori logici JSON schema: anyOf, allOf, oneOf, not.';


--
-- Name: __jsonb_schema__validate_number_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_number_constraints(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	data_number numeric;
	minimum_val numeric;
	maximum_val numeric;
	exclusive_min numeric;
	exclusive_max numeric;
	multiple_of_val numeric;
	error_list text[] := array[]::text[];
begin
	-- solo numeri possono avere number constraints
	if jsonb_typeof(p_data) not in ('number') then
		return error_list;
	end if;
	
	data_number := (p_data #>> '{}')::numeric;
	
	-- minimum validation
	if p_schema ? 'minimum' then
		minimum_val := (p_schema->>'minimum')::numeric;
		if data_number < minimum_val then
			error_list := error_list || format('path %s: value %s is less than minimum %s', 
				p_path, data_number, minimum_val);
		end if;
	end if;
	
	-- maximum validation
	if p_schema ? 'maximum' then
		maximum_val := (p_schema->>'maximum')::numeric;
		if data_number > maximum_val then
			error_list := error_list || format('path %s: value %s exceeds maximum %s', 
				p_path, data_number, maximum_val);
		end if;
	end if;
	
	-- exclusiveMinimum validation
	if p_schema ? 'exclusiveMinimum' then
		exclusive_min := (p_schema->>'exclusiveMinimum')::numeric;
		if data_number <= exclusive_min then
			error_list := error_list || format('path %s: value %s must be greater than exclusiveMinimum %s', 
				p_path, data_number, exclusive_min);
		end if;
	end if;
	
	-- exclusiveMaximum validation
	if p_schema ? 'exclusiveMaximum' then
		exclusive_max := (p_schema->>'exclusiveMaximum')::numeric;
		if data_number >= exclusive_max then
			error_list := error_list || format('path %s: value %s must be less than exclusiveMaximum %s', 
				p_path, data_number, exclusive_max);
		end if;
	end if;
	
	-- multipleOf validation
	if p_schema ? 'multipleOf' then
		multiple_of_val := (p_schema->>'multipleOf')::numeric;
		if multiple_of_val > 0 and (data_number % multiple_of_val) != 0 then
			error_list := error_list || format('path %s: value %s is not a multiple of %s', 
				p_path, data_number, multiple_of_val);
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_number_constraints(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_number_constraints(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida i vincoli numerici: minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf.';


--
-- Name: __jsonb_schema__validate_object_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_object_constraints(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	properties_count integer;
	min_properties integer;
	max_properties integer;
	error_list text[] := array[]::text[];
begin
	-- solo oggetti possono avere object constraints
	if jsonb_typeof(p_data) != 'object' then
		return error_list;
	end if;
	
	-- conta il numero di proprietà
	select count(*) into properties_count
	from jsonb_object_keys(p_data);
	
	-- minProperties validation
	if p_schema ? 'minProperties' then
		min_properties := (p_schema->>'minProperties')::integer;
		if properties_count < min_properties then
			error_list := error_list || format('path %s: object has %s properties, minimum required is %s', 
				p_path, properties_count, min_properties);
		end if;
	end if;
	
	-- maxProperties validation
	if p_schema ? 'maxProperties' then
		max_properties := (p_schema->>'maxProperties')::integer;
		if properties_count > max_properties then
			error_list := error_list || format('path %s: object has %s properties, maximum allowed is %s', 
				p_path, properties_count, max_properties);
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_object_constraints(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_object_constraints(p_data jsonb, p_schema jsonb, p_path text) IS '[PRIVATA] Valida i vincoli degli oggetti: minProperties, maxProperties.';


--
-- Name: __jsonb_schema__validate_properties(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_properties(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $_$
declare
	prop_name text;
	prop_schema jsonb;
	prop_data jsonb;
	error_list text[] := array[]::text[];
	temp_errors text[];
	current_path text;
begin
	-- itera su ogni proprietà definita nello p_schema
	for prop_name, prop_schema in
		select key, value from jsonb_each(p_schema->'properties')
	loop
		current_path := format('%s.%s', p_path, prop_name);
		
		if p_data ? prop_name then
			prop_data := p_data->prop_name;
			
			-- gestisce $ref
			if prop_schema ? '$ref' then
				-- risolve il riferimento (implementazione semplificata)
				declare
					ref_path text := prop_schema->>'$ref';
					definitions_schema jsonb;
				begin
					if ref_path like '#/definitions/%' then
						ref_path := replace(ref_path, '#/definitions/', '');
						definitions_schema := p_schema->'definitions'->ref_path;
						if definitions_schema is not null then
							prop_schema := definitions_schema;
						end if;
					end if;
				end;
			end if;
			
			-- valida ricorsivamente
			temp_errors := common.__jsonb_schema__validate(prop_data, prop_schema, current_path);
			error_list := error_list || temp_errors;
		end if;
	end loop;
	
	-- controlla additionalProperties
	if p_schema ? 'additionalProperties' and (p_schema->'additionalProperties')::boolean = false then
		for prop_name in
			select key from jsonb_object_keys(p_data) key
			where not (p_schema->'properties' ? key)
		loop
			error_list := error_list || format('path %s.%s: additional property not allowed', 
				p_path, prop_name);
		end loop;
	end if;
	
	return error_list;
end;
$_$;


--
-- Name: FUNCTION __jsonb_schema__validate_properties(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_properties(p_data jsonb, p_schema jsonb, p_path text) IS 'Valida le proprietà di un oggetto JSONB contro lo schema. Gestisce validation ricorsiva, $ref, e additionalProperties.';


--
-- Name: __jsonb_schema__validate_required(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_required(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	required_field text;
	error_list text[] := array[]::text[];
begin
	for required_field in
		select jsonb_array_elements_text(p_schema->'required')
	loop
		if not (p_data ? required_field) then
			error_list := error_list || format('path %s: missing required property "%s"', 
				p_path, required_field);
		end if;
	end loop;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_required(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_required(p_data jsonb, p_schema jsonb, p_path text) IS 'Verifica che tutti i campi obbligatori specificati nell''array "required" dello schema siano presenti nel documento.';


--
-- Name: __jsonb_schema__validate_string_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_string_constraints(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	data_text text;
	data_length integer;
	min_length integer;
	max_length integer;
	pattern_regex text;
	error_list text[] := array[]::text[];
begin
	-- solo stringhe possono avere string constraints
	if jsonb_typeof(p_data) != 'string' then
		return error_list;
	end if;
	
	data_text := p_data #>> '{}';
	data_length := char_length(data_text);
	
	-- minLength validation
	if p_schema ? 'minLength' then
		min_length := (p_schema->>'minLength')::integer;
		if data_length < min_length then
			error_list := error_list || format('path %s: string length %s is less than minLength %s', 
				p_path, data_length, min_length);
		end if;
	end if;
	
	-- maxLength validation
	if p_schema ? 'maxLength' then
		max_length := (p_schema->>'maxLength')::integer;
		if data_length > max_length then
			error_list := error_list || format('path %s: string length %s exceeds maxLength %s', 
				p_path, data_length, max_length);
		end if;
	end if;
	
	-- pattern validation
	if p_schema ? 'pattern' then
	
		pattern_regex := p_schema->>'pattern';

		if not (data_text ~ pattern_regex) then
		
			error_list := error_list 
				|| format('path %s: string "%s" does not match pattern "%s"'
				, p_path, data_text, pattern_regex);
				
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_string_constraints(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_string_constraints(p_data jsonb, p_schema jsonb, p_path text) IS 'Valida i vincoli delle stringhe: minLength, maxLength, pattern.';


--
-- Name: __jsonb_schema__validate_type(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__jsonb_schema__validate_type(p_data jsonb, p_schema jsonb, p_path text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
declare
	expected_type jsonb;
	actual_type text;
	error_list text[] := array[]::text[];
begin
	expected_type := p_schema->'type';
	actual_type := jsonb_typeof(p_data);
	
	if expected_type is null then
		return error_list;
	end if;
	
	-- gestisce array di tipi (es. ["string", "null"])
	if jsonb_typeof(expected_type) = 'array' then
		if not (expected_type @> to_jsonb(actual_type)) then
			error_list := error_list || format('path %s: expected one of %s, got %s', 
				p_path, expected_type::text, actual_type);
		end if;
	else
		-- tipo singolo
		if expected_type::text != format('"%s"', actual_type) then
			error_list := error_list || format('path %s: expected %s, got %s', 
				p_path, expected_type::text, actual_type);
		end if;
	end if;
	
	return error_list;
end;
$$;


--
-- Name: FUNCTION __jsonb_schema__validate_type(p_data jsonb, p_schema jsonb, p_path text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.__jsonb_schema__validate_type(p_data jsonb, p_schema jsonb, p_path text) IS 'Valida il tipo di un valore JSONB contro lo schema. Supporta tipi singoli e array di tipi (es. ["string", "null"]).';


--
-- Name: __type__get_canonical_output_name(text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__type__get_canonical_output_name(internal_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	t text := lower(trim(coalesce(internal_type, '')));
begin
	-- regole per l'output finale
	case t
		-- datetime: versioni compatte per zoned
		when 'timestamptz' then return 'timestamptz';
		when 'timetz' then return 'timetz';
		when 'timestamp' then return 'timestamp';
		when 'date' then return 'date';
		when 'time' then return 'time';
		
		-- numerici: versioni estese
		when 'int2' then return 'smallint';
		when 'int4' then return 'integer';
		when 'int8' then return 'bigint';
		when 'float4' then return 'real';
		when 'float8' then return 'double';
		when 'numeric' then return 'numeric';
		
		
		-- boolean: versione estesa
		when 'bool' then return 'boolean';
		
		-- text: char per lunghezza fissa, text per variabile
		when 'varchar' then return 'text'; -- varchar è lunghezza variabile -> text
		when 'char' then return 'char';    -- char è lunghezza fissa
		when 'text' then return 'text';
		
		-- altri tipi
		when 'uuid' then return 'uuid';
		when 'invalid' then return 'invalid';
		
		else return t;
	end case;
end;
$$;


--
-- Name: __type__normalize_name(text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.__type__normalize_name(type_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	t text := lower(trim(coalesce(type_name, '')));
begin
	-- normalizza tutti gli alias ai nomi canonici
	case t
		when '' then return 'unknown';
		-- datetime types
		when 'timestamp with time zone' then return 'timestamptz';
		when 'time with time zone' then return 'timetz';
		
		-- numeric types
		when 'smallint' then return 'int2';
		when 'integer' then return 'int4';
		when 'bigint' then return 'int8';
		when 'real' then return 'float4';
		when 'double precision' then return 'float8';
		when 'number' then return 'numeric';
		
		-- boolean
		when 'boolean' then return 'bool';
		
		-- text types
		when 'character varying' then return 'varchar';
		when 'character' then return 'char';
		
		else return t;
	end case;
end;
$$;


--
-- Name: bind_variable(text, extensions.hstore, text, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.bind_variable(pattern_to_process text, variable_to_process extensions.hstore, start_delimiter text DEFAULT ':'::text, end_delimiter text DEFAULT ':'::text) RETURNS text
    LANGUAGE plpgsql
    AS $_$declare
/*
	IN pattern_to_process text, 
	IN variable_to_process hstore, 
	IN start_delimiter text DEFAULT ':', 
	IN end_delimiter text DEFAULT ':'

*/

	_k			text;
--	_v			text;
--	_debug		text;
begin
	--_debug= '--Start' || _sqlstr;
	foreach _k in array akeys(variable_to_process) loop

--		_debug =_debug || format($$
--		hstore: %s %s
--			sqlStr:$$, _k,  hrec[_k]);
		pattern_to_process=replace(pattern_to_process, start_delimiter || _k || end_delimiter, variable_to_process[_k]);
--		_debug =_debug ||  _sqlstr;
	
	end loop;

--	raise notice 'final %',_debug;
	return pattern_to_process;
end;$_$;


--
-- Name: coalesce_array(anycompatiblearray); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.coalesce_array(array_to_collapse anycompatiblearray) RETURNS anycompatible
    LANGUAGE plpgsql
    AS $$declare
/*
	IN array_to_collapse anycompatiblearray)
*/
	_i integer;
begin
	if array_to_collapse is null then
		return null;
	end if;
	for _i in 1..array_length(array_to_collapse,1) loop
		if array_to_collapse[_i] is not null then
			return array_to_collapse[_i];
		end if;
	end loop;
	
	return null;
end;$$;


--
-- Name: dquote_literal(text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.dquote_literal(text_to_dquote text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    BEGIN ATOMIC
 WITH aa AS (
          SELECT quote_ident(dquote_literal.text_to_dquote) AS txt
         )
  SELECT
         CASE
             WHEN (aa.txt ^@ '"'::text) THEN aa.txt
             ELSE (('"'::text || aa.txt) || '"'::text)
         END AS dquoted_text
    FROM aa;
END;


--
-- Name: get_diagnostic_text(integer); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.get_diagnostic_text(skip_lines integer DEFAULT 0) RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
--	IN skip_lines integer DEFAULT 0
--    RETURNS text

	context_string text;
    function_match text[];
    function_name  text;
	i				integer=0;
	out_txt			text='';
	--c_er			text ='^(?:(?!context:).+?(function|statement) (([^(]+).*?)$)';
	c_er			text ='^(?:.*?(function|error:|query:|expression|statement)\s+(([^( ]+)?.*?)$)';
begin
	-- +2 because use i < skip_lines unless i <= skip_lines
	skip_lines=skip_lines+2;
    
	get diagnostics context_string = pg_context;
/*
context_string=$$
ERROR:  record "tar" has no field "historice_entity"
CONTEXT:  SQL expression "tar.historice_entity ='never'"
PL/pgSQL function vrsn.__tar_h__config_func_init(vrsn.trigger_activation_record_base) line 81 at IF
PL/pgSQL function vrsn.__tar_h__build(vrsn.entity_fullname_type,boolean,anycompatiblearray) line 48 at assignment
PL/pgSQL function vrsn.tar_h__get(vrsn.entity_fullname_type,anycompatiblearray) line 6 at RETURN 

SQL state: 42703

$$;
*/
    for function_match in
		select regexp_matches(lower(context_string), c_er,'gn') 
	loop
		i=i+1;
		if i < skip_lines then
			continue;
		end if;
		
		case function_match[1]
		when	'function' then
			if function_name is null then
				function_name=function_match[3];
				
			end if;
			out_txt= out_txt || e'\nfunc: ' ||function_match[2];
		when	'statement' then
			out_txt= out_txt || e'\nstmt: ' ||function_match[2];		
		when	'expression' then
			out_txt= out_txt || e'\nexpr: ' ||function_match[2];
		when	'error:' then
			out_txt= out_txt || e'\nerr: ' ||function_match[2];			
		when	'query:' then
			out_txt= out_txt || e'\nqry: ' ||function_match[2];			
		else
			out_txt= out_txt || e'\nother: ' ||function_match[2];
		end case;
    end loop;

	
	out_txt= format (e'invoker <%s>\n', function_name)
		||	out_txt
--		||	e'\n\n------\n'||context_string
	;
	return out_txt;
end;
$_$;


--
-- Name: hstore_strip_nulls(extensions.hstore); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.hstore_strip_nulls(hstore_to_strip extensions.hstore) RETURNS extensions.hstore
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT extensions.hstore(array_agg(s.k), array_agg(s.v)) AS hstore
    FROM extensions.each(hstore_strip_nulls.hstore_to_strip) s(k, v)
   WHERE (s.v IS NOT NULL);
END;


--
-- Name: is_empty(anycompatible); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.is_empty(value_to_test anycompatible) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$declare
	len integer;
	txt	text;
begin
--raise notice 'start % %', pg_typeof(value_to_test),value_to_test;	
	if value_to_test is null then
		return true;
	end if;

	begin 
--		raise notice 'array %', array_length(value_to_test,1)::int;
		len = array_length(value_to_test,1)::integer;
		return len = 0 or len is null;
	exception
		when others then
			null;
	end;
	
	if pg_typeof(value_to_test) in ('json','jsonb') then
		case jsonb_typeof(value_to_test) 
			when 'null' then
				return true;
			when 'object' then				
				select count(*) into len
				from jsonb_object_keys(value_to_test::jsonb);
				return len = 0 or len is null;
			when 'array' then
				
				len=jsonb_array_length(value_to_test::jsonb);
				return len = 0 or len is null;
			else
/*				value_to_test='a'::text;
				raise notice 'type <%>', pg_typeof(value_to_test);
				raise notice 'rpl <%>', regexp_replace(
						value_to_test::text
					,	'[''"]','','g'
				);*/
				txt=regexp_replace(
						value_to_test::text
					,	'[''"]','','g'
				);
				

		end case;
		
		raise notice 'jsonb %', txt;
	else
		txt=value_to_test::text;

	end if;
	
	begin
		return txt::integer = 0;
	exception
		when others then
			null;
	end;
	
	begin 
		return length(txt) = 0;
	exception
		when others then
			null;
	end;

--	raise notice '% %', pg_typeof(value_to_test),value_to_test;	
	
	return false;
end;$$;


--
-- Name: jsonb_array_to_string(jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_array_to_string(arr jsonb, separator text DEFAULT ', '::text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    BEGIN ATOMIC
 SELECT string_agg(text_result.value, jsonb_array_to_string.separator) AS string_agg
    FROM jsonb_array_elements_text(jsonb_array_to_string.arr) text_result(value);
END;


--
-- Name: jsonb_array_to_text_array(jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_array_to_text_array(_js jsonb) RETURNS text[]
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    BEGIN ATOMIC
 SELECT ARRAY( SELECT jsonb_array_elements_text(_js) AS jsonb_array_elements_text) AS text_array;
END;


--
-- Name: jsonb_extract_multiple_paths(jsonb, text[]); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_extract_multiple_paths(json_data jsonb, path_patterns text[]) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
declare
/*
	IN json_data jsonb,
	IN path_patterns text[]
	RETURNS jsonb
*/


	jb_patterns jsonb := '{}'::jsonb;
	pattern text;
	pattern_ltree ltree;
	v_result jsonb;
	total_matches integer;
	single_value jsonb;
begin
	-- costruisce il jsonb dei pattern
	foreach pattern in array path_patterns loop
		pattern := ltrim(pattern, '$.');
		jb_patterns := common.jsonb_set_building_path(jb_patterns, pattern, 'true'::jsonb);
	end loop;
	
	-- chiama la funzione ricorsiva
	v_result := common.jsonb_extract_recursive(json_data, jb_patterns);
	
	-- estrae il conteggio e lo rimuove dal risultato
	total_matches := (v_result->'__MATCH_COUNT__')::int;
	v_result := v_result - '__MATCH_COUNT__';
	
	-- aggiunge metadati
	v_result['__METADATA__'] =	jsonb_build_object(
			'total_matches', total_matches,
			'patterns_processed', array_length(path_patterns, 1)		
	);
	
	-- aggiunge __SINGLE_VALUE__ se c'è esattamente un match
	if total_matches = 1 then
		v_result['__SINGLE_VALUE__'] =  v_result->'__LAST_VALUE__';
	end if;
	
	v_result := v_result - '__LAST_VALUE__';	
	
	return v_result;
end;
$_$;


--
-- Name: jsonb_extract_recursive(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_extract_recursive(json_data jsonb, jb_patterns jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	IN json_data jsonb,
	IN jb_patterns jsonb)
    RETURNS jsonb
*/


	v_result		jsonb=$${
		"__MATCH_COUNT__": null,
		"__LAST_VALUE__":null,
		"__FOUND__":null
	}$$;
	v_innerResult	jsonb;
	array_index		integer := 0;
	pattern_key		text;
	pattern_value	jsonb;
	data_key		text;
	data_value		jsonb;
	sub_v_result	jsonb;
	v_isArray		boolean=false;
	v_isObject		boolean=false;

	v_singleValue	jsonb;

	total_match		integer=0;
begin
	-- se jb_patterns è un valore finale (true), abbiamo trovato un match
	if jsonb_typeof(jb_patterns) != 'object' then
		-- questo è un match finale
		v_result['__MATCH_COUNT__'] = to_jsonb(1::int);
		v_result['__LAST_VALUE__']= json_data;
		v_result['__FOUND__']= json_data;
		
		return v_result;	
		
	end if;

	-- se json_data non è un oggetto o un array NON ho trovato il match
	-- viceversa predispongo il risultato
	case  jsonb_typeof(json_data)
		when 'object' then 
			v_isObject=true;
			v_innerResult = '{}'::jsonb;
		when 'array' then 	
			v_isArray=true;
			v_innerResult = '[]'::jsonb;
		else 
			--raise notice 'json_data is not an object';
			return null;
	end case;

	
	-- itera sui pattern a questo livello
	for pattern_key, pattern_value in select * from jsonb_each(jb_patterns) loop
	
		array_index =0;

		-- cerca nel json per le chiavi in comune
		for data_key, data_value in 
			select * from jsonb_each(json_data) e(k,v)
			where v_isObject 
			and (k=pattern_key or pattern_key='*')
			
			union all
			
			select ''::text, v 
			from jsonb_array_elements(json_data) e(v)
			where v_isArray 
			and (v::Text=pattern_key or pattern_key='*')

		loop


			-- Passo ricorsivo
			sub_v_result := common.jsonb_extract_recursive(data_value, pattern_value);
			

			if sub_v_result is null then
				continue;
			end if;
			
			
--raise notice '% - %',data_key,sub_v_result;

	
			-- Aggiorno il contatore
			total_match = total_match 
				+ coalesce((sub_v_result->>'__MATCH_COUNT__')::int, 0);

			v_singleValue =sub_v_result->'__LAST_VALUE__';
			
			if v_isArray then
				v_innerResult[array_index]= sub_v_result->'__FOUND__';
			else
				v_innerResult[data_key]=sub_v_result->'__FOUND__';
			end if;
			array_index=array_index+1;
		end loop;
	end loop;

	-- Nessuna corrispondenza
	if array_index =0 then
		return null;
	end if;

	-- compongo il risultato
	v_result['__MATCH_COUNT__'] = to_jsonb( total_match);
	v_result['__LAST_VALUE__']= v_singleValue;
	v_result['__FOUND__']= v_innerResult;
		
	
	return v_result;
end;
$_$;


--
-- Name: jsonb_keys_to_array(jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_keys_to_array(_jb jsonb, pattern text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	_jb	jsonb
	pattern text
*/

	_rst	record;
	_jbA	jsonb[];
	_foundArray	boolean =false;
	_foundKey	boolean = false;
	_keys	text[];
	
	
	_er text ='^__(?:(?:array__(\d+))|(?:(\d+)__))$';
	__id numeric;
	 
begin

	if jsonb_typeof(_jb) <> 'object' then
		return _jb;
	end if;
	
	--pattern is not null and 
	if length(pattern)>0 then
		_keys=string_to_array(pattern,'.');
		
		return jsonb_set(
				_jb
			,	_keys
			,	common.jsonb_keys_to_array(_jb #>_keys)
			);
	
	end if;
	
	--raise notice '%', jsonb_pretty(_jb);
	-- Scorro il jsonb in ampiezza, quindi passo ricorsivo in profondità
	for _rst in select * from jsonb_each ( _jb ) loop
	
		_keys=array_append(_keys, _rst.key);
		
		-- se la chiave è __array__ oppure __ANYDIGITS__ lo memorizzo in una variabile di appoggio
		__id = common.coalesce_array(regexp_match ( _rst.key , _er ) )::numeric;
		
		if __id is null then
			_jb [ _rst.key] = common.jsonb_keys_to_array ( _rst.value ) ;
			_foundKey=true;
		else
			if jsonb_typeof(_rst.value) <> 'object' then
				_rst.value=jsonb_build_object('__innerValue__',_rst.value);
			end if;
			_rst.value['__id__']=to_jsonb(__id);		
			_jbA = array_append (_jbA, common.jsonb_keys_to_array ( _rst.value ) );
			_foundArray=true;
		end if;
		
	end loop;
	
	
	if _foundKey and _foundArray then
		raise exception 'Impossible complete action. Found inconsistent keys: %', _keys;
	end if;
	
	
	--se ho trovato un array lo concateno
	if array_length(_jbA, 1) > 0 then
		_jb=to_jsonb(_jbA);
	end if;
	
	return _jb;
end;
$_$;


--
-- Name: FUNCTION jsonb_keys_to_array(_jb jsonb, pattern text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.jsonb_keys_to_array(_jb jsonb, pattern text) IS 'If jsonb keys are in format __%anydigits__ represent a malfomed array
"a":{"__1__": {"b":14}, "__2__":{"c":"alfa"}} => "a": [{"__id__":1,"b": 14}, {"__id__":2,"c":"alfa"}]
or
"a":{"__1__": 14, "__2__":"alfa"} => "a": [{"__id__":1,"__innerValue": 14}, {"__id__":2,"__innerValue":"alfa"}]


This function correct this situation';


--
-- Name: jsonb_linearize(jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_linearize(jb jsonb, prefix text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare
/*
	IN jb jsonb
	IN prefix text DEFAULT ''
*/
	_k	text;
	_jb jsonb;
	_ret jsonb;
	_i	bigint=0;
begin
	if prefix is null then
		prefix='';
	end if;
	case jsonb_typeOf(jb)
	when 'object' then
		for _k, _jb in 
			select *
			from jsonb_each(jb)
		loop
			_k= prefix || _k;
			if  jsonb_typeOf(_jb) in ('object' ,'array' ) then
				_ret=common.jsonb_recursive_merge(_ret
					, common.jsonb_linearize(_jb, _k||'.')

					);
			else
				_ret[_k]=_jb;
			end if;
		end loop;
	when 'array' then		
		for _jb in 
			select *
			from jsonb_array_elements(jb)
		loop
			if  jsonb_typeOf(_jb) = 'object' and _jb ? '__id__' then
				_i=(_jb->>'__id__')::bigint;
				_jb=_jb - '__id__';
			else
				_i=_i+1;
			end if;
			
			_k= format('%s__%s__', prefix, to_char(_i,'fm00000'));
			
			if  jsonb_typeOf(_jb) in ('object' ,'array' ) then
			
				_ret=common.jsonb_recursive_merge(_ret
					, common.jsonb_linearize(_jb, _k||'.')

					);
			else
				_ret[_k]=_jb;
			end if;
		end loop;
	
	else
	end case;
	
	return _ret;
end;
$$;


--
-- Name: FUNCTION jsonb_linearize(jb jsonb, prefix text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.jsonb_linearize(jb jsonb, prefix text) IS 'Starting with a jsonb (usually coherent with a jason schema)
retrieve an key-value notation, where Key use the ltree notation:
"a.b.c" -> 56
if there are array in the path  (consider "c" as array) is used notation:
"a.b.c.__00001__" -> 45

Output is yet a jsonb';


--
-- Name: jsonb_linearize_to_key_value(jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_linearize_to_key_value(jb jsonb, prefix text DEFAULT ''::text) RETURNS SETOF common.key_value_list
    LANGUAGE plpgsql IMMUTABLE
    AS $_$declare
--	IN jb jsonb, 
--	IN prefix text DEFAULT ''
--	RETURNS common.key_value_list[]

	v_ret	common.key_value_list;

	v_er_searchIdx   	text='(^|\.)__(\d+)__(\.|$)';
	v_er_searchIdx_fr  	text='(^|\.)(__\d+__)(\.|$)';
	v_replace			text='\1__ARRAY__\3';
	
	v_jb			jsonb;
	
begin
	jb=common.jsonb_linearize(jb, prefix);

	for v_ret.attribute_name, v_jb in 
			select *
			from jsonb_each(jb)
	loop

		v_ret.attribute_value=jb->>v_ret.attribute_name;

		--> seek for __anydigits__
		select string_agg(s[2],'.') into v_ret.idx
		from  regexp_matches(v_ret.attribute_name
				,	v_er_searchIdx, 'g') as l(s);

		--> if fount replace with __ARRAY__
		if v_ret.idx is not null then
			v_ret.attribute_name =regexp_replace(v_ret.attribute_name
				,	v_er_searchIdx_fr
				,	v_replace
				,	'g');
		else
			v_ret.idx='';
		end if;

		v_ret.attribute_type=common.type__detect_jsonb_field(v_jb);
		

		return next v_ret;
 
	end loop;

	return;
end;$_$;


--
-- Name: jsonb_recursive_intersect(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_recursive_intersect(first_jb jsonb, second_jb jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$
/*
from https://stackoverflow.com/questions/42944888/merging-jsonb-values-in-postgresql
*/
select 
    jsonb_object_agg(
        coalesce(ka, kb), 
        case 
            when va isnull then null
            when jsonb_typeof(vb) <> 'object' then va 
            
			--WHEN jsonb_typeof(va) = 'array' AND jsonb_typeof(vb) = 'array' THEN va || vb
            
            else common.jsonb_recursive_intersect(va, vb) end 
        ) 
    from jsonb_each(first_jb) e1(ka, va) 
    inner join jsonb_each(second_jb) e2(kb, vb) on ka = kb or kb='*';

$$;


--
-- Name: jsonb_recursive_left_merge(jsonb, jsonb, boolean); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_recursive_left_merge(first_jb jsonb, second_jb jsonb, strip_nulls boolean DEFAULT false) RETURNS jsonb
    LANGUAGE sql
    AS $$
/*
from https://stackoverflow.com/questions/42944888/merging-jsonb-values-in-postgresql
*/
select 
    jsonb_object_agg(
        ka, 
        case 
            when va is null then vb 
            when vb is null then va 
            when va = vb then vb
			WHEN jsonb_typeof(va) = 'array' AND jsonb_typeof(vb) = 'array' THEN va || vb
            when jsonb_typeof(va) <> 'object' or jsonb_typeof(vb) <> 'object' then vb 
            else common.jsonb_recursive_merge(va, vb) end 
        ) 
    from jsonb_each(first_jb) e1(ka, va) 
    left join jsonb_each(second_jb) e2(kb, vb) on ka = kb and (not strip_nulls or jsonb_typeof(vb) <> 'null');

$$;


--
-- Name: jsonb_recursive_merge(jsonb[]); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_recursive_merge(jb_list jsonb[]) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
--jb_list
	_n	integer=array_length(jb_list,1);
	_i	integer;
	_jbOut jsonb;
begin
	_jbOut=jb_list[1];
	for _i in 2.._n loop
		_jbOut=common.jsonb_recursive_merge(_jbOut,jb_list[_i]);
	end loop;

	return _jbOut;
end;$$;


--
-- Name: jsonb_recursive_merge(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_recursive_merge(first_jb jsonb, second_jb jsonb) RETURNS jsonb
    LANGUAGE sql
    AS $$/*
from https://stackoverflow.com/questions/42944888/merging-jsonb-values-in-postgresql
*/
select 
    jsonb_object_agg(
        coalesce(ka, kb), 
        case 
            when va isnull then vb 
            when vb isnull then va 
            when va = vb then vb
			WHEN jsonb_typeof(va) = 'array' AND jsonb_typeof(vb) = 'array' THEN va || vb
            when jsonb_typeof(va) <> 'object' or jsonb_typeof(vb) <> 'object' then vb 
            else common.jsonb_recursive_merge(va, vb) end 
        ) 
    from jsonb_each(first_jb) e1(ka, va) 
    full join jsonb_each(second_jb) e2(kb, vb) on ka = kb;

$$;


--
-- Name: jsonb_schema__get_errors(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_schema__get_errors(p_data jsonb, p_schema jsonb) RETURNS text[]
    LANGUAGE sql
    AS $$
	select (common.jsonb_schema__validate(p_data, p_schema)).errors;
$$;


--
-- Name: FUNCTION jsonb_schema__get_errors(p_data jsonb, p_schema jsonb); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.jsonb_schema__get_errors(p_data jsonb, p_schema jsonb) IS 'Funzione di convenienza che restituisce solo l''array degli errori di validazione con percorsi dettagliati.';


--
-- Name: jsonb_schema__is_valid(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_schema__is_valid(p_data jsonb, p_schema jsonb) RETURNS boolean
    LANGUAGE sql
    AS $$
	select (common.jsonb_schema__validate(p_data, p_schema)).is_valid;
$$;


--
-- Name: FUNCTION jsonb_schema__is_valid(p_data jsonb, p_schema jsonb); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.jsonb_schema__is_valid(p_data jsonb, p_schema jsonb) IS 'Funzione di convenienza che restituisce solo un boolean indicando se il documento JSONB è valido secondo lo schema fornito.';


--
-- Name: jsonb_schema__validate(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_schema__validate(p_data jsonb, p_schema jsonb) RETURNS TABLE(is_valid boolean, errors text[])
    LANGUAGE plpgsql
    AS $$
declare
	error_list text[] := array[]::text[];
begin
	error_list = common.__jsonb_schema__validate(p_data, p_schema);
	
	return query select array_length(error_list, 1) is null, error_list;
end;
$$;


--
-- Name: FUNCTION jsonb_schema__validate(p_data jsonb, p_schema jsonb); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.jsonb_schema__validate(p_data jsonb, p_schema jsonb) IS 'Valida un documento JSONB contro un JSON schema. Restituisce sia il risultato della validazione che un array di errori dettagliati con i percorsi degli errori.';


--
-- Name: jsonb_set_building_path(jsonb, extensions.ltree, jsonb, boolean); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_set_building_path(jsonb_in jsonb, key_to_set extensions.ltree, value_to_set jsonb, create_if_missing boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
declare
/*
	jsonb_in	jsonb,
	key_to_set ltree,
	value_to_set jsonb,
	create_if_missing boolean true
*/

	_aname	text;
	_jb jsonb=  '{}'::jsonb;
begin
--raise notice 'w.on: %',key_to_set;
	if key_to_set::text='' or key_to_set is null then
		return value_to_set;
	end if;
		
	_aname=subpath(key_to_set,0,1)::text;

	if jsonb_in ? _aname then
		if jsonb_typeOf(jsonb_in[_aname]) ='object' then
			_jb = jsonb_in[_aname];
		else
			_jb['__innerCode__'] = jsonb_in[_aname];
		end if;
		
	elseif not create_if_missing then
		return jsonb_in;
	end if;

	if nlevel(key_to_set)>1 then
		key_to_set=subpath(key_to_set,1);
		value_to_set=common.jsonb_set_building_path(
							_jb,
							key_to_set,
							value_to_set,
							create_if_missing
		);
	end if;
--	raise notice e'R: %(%)=%\n %',_aname,key_to_set,value_to_set,jsonb_in;

	jsonb_in[_aname] = value_to_set;
	
	return jsonb_in;
end;
$$;


--
-- Name: jsonb_set_building_path(jsonb, text, jsonb, boolean); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.jsonb_set_building_path(jsonb_in jsonb, key_to_set text, value_to_set jsonb, create_if_missing boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	jsonb_in	jsonb,
	key_to_set ltree,
	value_to_set jsonb,
	create_if_missing boolean true
*/

	v_currentKey	text;	
	v_subPath		text;

	_jb 			jsonb=  '{}'::jsonb;
begin
--raise notice 'w.on: %',key_to_set;
	if key_to_set::text='' or key_to_set is null then
		return value_to_set;
	end if;
		
	with aa as (
		select 	regexp_matches(key_to_set,'^([^.]+)(?:\.(.*))?$','g')	as p
	)
	select p[1], p[2]	into v_currentKey,v_subPath
	from aa;

		
	if jsonb_in ? v_currentKey then
		if jsonb_typeOf(jsonb_in[v_currentKey]) ='object' then
			_jb = jsonb_in[v_currentKey];
		else
			_jb['__innerCode__'] = jsonb_in[v_currentKey];
		end if;
		
	elseif not create_if_missing then
		return jsonb_in;
	end if;

	if v_subPath is not null then

		value_to_set=common.jsonb_set_building_path(
							_jb,
							v_subPath,
							value_to_set,
							create_if_missing
		);
	end if;
--	raise notice e'R: %(%)=%\n %',v_currentKey,key_to_set,value_to_set,jsonb_in;

	jsonb_in[v_currentKey] = value_to_set;
	
	return jsonb_in;
end;
$_$;


--
-- Name: key_value_to_jsonb(common.key_value_list[]); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.key_value_to_jsonb(key_value_list_to_process common.key_value_list[]) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
declare

/*
	key_value_list_to_process common.key_value_list[])
	RETURNS jsonb
*/	
	_jbout	jsonb='{}'::jsonb;
	
	_h hstore;
	_r record;
	
	_keys text[];
	_idxes text[];
	_i	integer;
	_k	integer;
	_n	integer;
	_key_value_list_lenght integer;
	_attribute_name	text;
begin

	_key_value_list_lenght=coalesce(array_length(key_value_list_to_process,1), 0 );

	if _key_value_list_lenght = 0 then
		return _jbout;
	end if;

	for _i in 1.._key_value_list_lenght loop
		
		-- esplodo gli indici
		_idxes = string_to_array(key_value_list_to_process[ _i ].idx::text,'.');
		
		_n=coalesce(array_length(_idxes,1), 0 );
		
		_attribute_name =key_value_list_to_process[ _i ].attribute_name::text;

		--> if there is an __array__ placeholder I store the key
		if _n >0 then
		
			_h[ regexp_replace (
					_attribute_name
				,	'\.__ARRAY__.*'
				,	''
				,	1
				,	0
				)
			]=1;
		
		end if;

		--> if there is an __array__ placeholder I replace all the occurrence
		for _i in 1.._n loop
			_attribute_name = regexp_replace (
					_attribute_name
				,	'__ARRAY__'
				,	format('__%s__',  to_char(_idxes[_i]::numeric,'fm00000'))
				,	1
				,	1
			);
		end loop;

		--> set the jsonb, in this phase array isn't managed properly
		_jbOut = common.jsonb_set_building_path(
								_jbOut,
								_attribute_name::ltree,
								common.to_jsonb_with_type(
										key_value_list_to_process[ _i ].attribute_value
									,	key_value_list_to_process[ _i ].attribute_type
								)
			);
		
	end loop;	
	
	
--	raise notice '%', _h;
	
	-- Foreach array key memorized I call the opportune fixing function
	for _r in select * from each(_h) as v(pattern,value) loop
		
		_jbOut= common.jsonb_keys_to_array(_jbOut, _r.pattern);

	end loop;
	

	return _jbout;
end;
$$;


--
-- Name: key_value_to_jsonb(extensions.ltree, jsonb, extensions.ltree); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.key_value_to_jsonb(path_to_process extensions.ltree, value_to_set jsonb, idx extensions.ltree DEFAULT ''::extensions.ltree) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
declare
/*
	path_to_process ltree,
	value_to_set text,
	idx	ltree
*/

	_ret	jsonb='{}'::jsonb;	
	_aname	text;

begin

	if path_to_process::text='' or path_to_process is null then
		return to_jsonb(value_to_set);
	else
	
		_aname=subpath(path_to_process,0,1)::text;
		
		if _aname='__array__' then
			--_aname = _aname || subpath(idx,0,1)::text;
			_aname = format('__%s__',  to_char(subpath(idx,0,1)::text::numeric,'fm00000'));
			if nlevel(idx)>1 then
				idx=subpath(idx,1);
			else
				idx=''::ltree;
			end if;
		end if;

		if nlevel(path_to_process)>1 then
			path_to_process=subpath(path_to_process,1);
		else
			path_to_process=''::ltree;
		end if;

/*		raise notice '%', common.key_value_to_jsonb(
				path_to_process
			,	value_to_set
			,	idx
		);
*/
		 _ret[_aname] = common.key_value_to_jsonb(
				path_to_process
			,	value_to_set
			,	idx
		);

		
	end if;
	
	return _ret;
end;
$$;


--
-- Name: quote_for_json(anyelement); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.quote_for_json(value_to_quote anyelement) RETURNS text
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$begin
	if value_to_quote is null then 
		return 'null';
	else
		return to_json(value_to_quote)::text;
	end if;
end;$$;


--
-- Name: records_equal(record, record, text[]); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.records_equal(record1 record, record2 record, exclude_fields text[] DEFAULT ARRAY[]::text[]) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$declare
--	IN record1 record, 
--	IN record2 record, 
--	IN exclude_fields text[] DEFAULT ARRAY[]::TEXT[]
--	return boolean
begin

	return (hstore(record1) - exclude_fields )
		=	( hstore(record2) - exclude_fields );

end;$$;


--
-- Name: regexp_replace_array(text, text, text[], text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.regexp_replace_array(text_to_replace text, pattern text, replacement text[], flags text DEFAULT ''::text) RETURNS text
    LANGUAGE plpgsql
    AS $$declare
/*
	IN text_to_replace text, 
	IN pattern text, 
	IN replacement text[], 
	IN flags text DEFAULT ''
*/

	_i	integer;
begin
	if replacement is null or pattern is null or pattern='' then
		return text_to_replace;
	end if;
	
	for _i in 1..array_length(replacement,1) loop
		text_to_replace = regexp_replace (
							text_to_replace
						,	pattern
						,	replacement[_i]
						,	1
						,	1
						,	flags);
	end loop;
	
	return text_to_replace;
end;$$;


--
-- Name: FUNCTION regexp_replace_array(text_to_replace text, pattern text, replacement text[], flags text); Type: COMMENT; Schema: common; Owner: -
--

COMMENT ON FUNCTION common.regexp_replace_array(text_to_replace text, pattern text, replacement text[], flags text) IS 'apply a regex_replace for all element of an array';


--
-- Name: to_jsonb_with_type(text, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.to_jsonb_with_type(value_to_convert text, type_of_value text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
declare
/*
	value_to_convert text
	type_of_value text
*/
	v_result jsonb;

begin
	if value_to_convert is null then
		return to_jsonb(value_to_convert);
	end if;
	
	case type_of_value
		when 'email', 'url', 'codice_fiscale', 'partita_iva' then
		
			type_of_value := 'text';
		when 'number' then
			type_of_value := 'numeric';
		when 'integer' ,'bigint' ,'numeric',  'float8' , 'boolean' then
			null;	
		when 'date' , 'time' , 'timetz' , 'timestamp' , 'timestamptz' , 'interval' then
			type_of_value := 'text';
		when 'uuid' , 'inet' , 'macaddr'  then
			null;
		else
			type_of_value := 'text';
	end case;

	-- costruisce ed esegue la conversione dinamica
	
	execute format('select to_jsonb($1::%I)', type_of_value)
		using value_to_convert into v_result;

	return v_result;
	
exception when others then
	-- se la conversione fallisce, restituisce null
	return null;
	
end;
$_$;


--
-- Name: type__detect_from_value(text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.type__detect_from_value(str_value text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$declare
	--str_len		integer;
	-- dichiarazione delle espressioni regolari
	date_regex text := '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$';
	time_regex text := '^([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(\.\d{1,6})?$';
	time_tz_regex text := '^([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(\.\d{1,6})?\s*(([+-]\d{2}(:\d{2})?|Z)|[A-Z]{3,4})$';
	timestamp_regex text := '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])[T\s]([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(\.\d{1,6})?$';
	timestamp_tz_regex text := '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])[T\s]([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(\.\d{1,6})?\s*(([+-]\d{2}(:\d{2})?|Z)|[A-Z]{3,4})$';
	
	
begin
	str_value=trim(str_value);
	
	-- test per null/empty
	if str_value is null or str_value = '' then
		return null;
	end if;

	--str_len=char_length(str_value);

	-- test per numeric/decimal/float/integer
	begin
		perform str_value::numeric;
		-- distingui tra tipi numerici
		if str_value ~ '\.' then
			-- contiene decimali
			if str_value::numeric = str_value::float8 then
				return 'float8';
			else
				return 'numeric';
			end if;
		else
			-- numero intero
			if str_value::numeric between -2147483648 and 2147483647 then
				return 'integer';
			elsif str_value::numeric between -9223372036854775808 and 9223372036854775807 then
				return 'bigint';
			else
				return 'numeric';
			end if;
		end if;
	exception when others then
		-- continua con altri test
	end;
	
	-- test per uuid
	begin
		perform str_value::uuid;
		return 'uuid';
	exception when others then
		-- continua con altri test
	end;

-- controllo se il valore è null o vuoto
	if str_value is null or length(trim(str_value)) = 0 then
		return 'invalid';
	end if;
	
	-- normalizza il valore (trim degli spazi)
	str_value := trim(str_value);
	
	-- test timestamptz (più specifico, va testato per primo)
	if str_value ~ timestamp_tz_regex then
		begin
			-- prova conversione effettiva
			perform str_value::timestamptz;
			return 'timestamptz';
		exception 
			when others then
				null; -- continua con il prossimo test
		end;
	end if;
	
	-- test timestamp
	if str_value ~ timestamp_regex then
		begin
			-- prova conversione effettiva
			perform str_value::timestamp;
			return 'timestamp';
		exception 
			when others then
				null; -- continua con il prossimo test
		end;
	end if;
	
	-- test timetz
	if str_value ~ time_tz_regex then
		begin
			-- prova conversione effettiva
			perform str_value::timetz;
			return 'timetz';
		exception 
			when others then
				null; -- continua con il prossimo test
		end;
	end if;
	
	-- test time
	if str_value ~ time_regex then
		begin
			-- prova conversione effettiva
			perform str_value::time;
			return 'time';
		exception 
			when others then
				null; -- continua con il prossimo test
		end;
	end if;
	
	-- test date
	if str_value ~ date_regex then
		begin
			-- prova conversione effettiva
			perform str_value::date;
			return 'date';
		exception 
			when others then
				null; -- continua con il prossimo test
		end;
	end if;

	
	-- test per interval
	begin
		perform str_value::interval;
		return 'interval';
	exception when others then
		-- continua con altri test
	end;
	
	
	-- test per boolean (stringhe che rappresentano booleani)
	if lower(str_value) in ('true', 'false', 't', 'f', 'yes', 'no', 'y', 'n', '1', '0') then
		begin
			perform str_value::boolean;
			return 'boolean';
		exception when others then
			-- se fallisce, continua
		end;
	end if;
	

	
	-- test per inet (ip address)
	begin
		perform str_value::inet;
		return 'inet';
	exception when others then
		-- continua con altri test
	end;
	
	-- test per macaddr
	begin
		perform str_value::macaddr;
		return 'macaddr';
	exception when others then
		-- continua con altri test
	end;
	
	-- test per email (pattern + controllo lunghezza)
	if str_value ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' and 
	   length(str_value) <= 254 then
		return 'email';
	end if;
	
	-- test per url
	if str_value ~* '^https?://[^\s/$.?#].[^\s]*$' then
		return 'url';
	end if;
	
	-- test per codice fiscale italiano
	if str_value ~* '^[A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z]$' then
		return 'codice_fiscale';
	end if;
	
	-- test per partita iva italiana
	if str_value ~* '^\d{11}$' then
		return 'partita_iva';
	end if;


	-- test per jsonb
	begin
		perform str_value::jsonb;
		return 'jsonb';
	exception when others then
		-- continua con altri test
	end;

	-- default: text
	return 'text';
end;
$_$;


--
-- Name: type__detect_jsonb_field(jsonb); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.type__detect_jsonb_field(json_value jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
	str_value text;
begin
	-- se è null
	if json_value is null or json_value = 'null'::jsonb then
		return 'null';
	end if;
	
	-- se è già tipizzato come numero in json
	if jsonb_typeof(json_value) = 'number' then
		-- distingui tra integer, bigint e numeric
		begin
			if (json_value::text)::numeric = trunc((json_value::text)::numeric) then
				-- è un intero
				if (json_value::text)::numeric between -2147483648 and 2147483647 then
					return 'integer';
				elsif (json_value::text)::numeric between -9223372036854775808 and 9223372036854775807 then
					return 'bigint';
				else
					return 'numeric';
				end if;
			else
				-- ha decimali
				if (json_value::text)::numeric = (json_value::text)::float8 then
					return 'float8';
				else
					return 'numeric';
				end if;
			end if;
		exception when others then
			return 'text';
		end;
	end if;
	
	if jsonb_typeof(json_value) = 'boolean' then
		return 'boolean';
	end if;
	
	if jsonb_typeof(json_value) = 'array' then
		return 'array';
	end if;
	
	if jsonb_typeof(json_value) = 'object' then
		return 'object';
	end if;
	
	-- se è una stringa, usa la funzione separata
	if jsonb_typeof(json_value) = 'string' then
		str_value := json_value #>> '{}';
		return common.type__detect_from_value(str_value);
	end if;
	
	-- fallback
	return 'unknown';
end;
$$;


--
-- Name: type__get_wider(text, text); Type: FUNCTION; Schema: common; Owner: -
--

CREATE FUNCTION common.type__get_wider(type1 text, type2 text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	-- normalizza i tipi in input
	t1 text := common.__type__normalize_name(type1);
	t2 text := common.__type__normalize_name(type2);
	result_type text;
begin
	-- se uno dei due è null o vuoto, ritorna l'altro
	if t1 = 'unknown' then
		return common.__type__get_canonical_output_name(
				case when t2= 'unknown' then 'text' else t2 end
			);
	end if;
	
	if t2 = 'unknown' then
		return common.__type__get_canonical_output_name(t1);
	end if;
	
	-- se sono uguali, ritorna uno dei due
	if t1 = t2 then
		return common.__type__get_canonical_output_name(t1);
	end if;
	
	-- gerarchia datetime (dal più specifico al più generico)
	-- timestamptz > timestamp > date
	-- timetz > time
	
	-- timestamptz è il più ampio tra i datetime
	if (t1 = 'timestamptz' and t2 in ('timestamp', 'date')) or
	   (t2 = 'timestamptz' and t1 in ('timestamp', 'date')) then
		return common.__type__get_canonical_output_name('timestamptz');
	end if;
	
	-- timestamp è più ampio di date
	if (t1 = 'timestamp' and t2 = 'date') or
	   (t2 = 'timestamp' and t1 = 'date') then
		return common.__type__get_canonical_output_name('timestamp');
	end if;
	
	-- timetz è più ampio di time
	if (t1 = 'timetz' and t2 = 'time') or
	   (t2 = 'timetz' and t1 = 'time') then
		return common.__type__get_canonical_output_name('timetz');
	end if;
	
	-- combinazioni tra time e date/timestamp sono incompatibili
	if (t1 in ('time', 'timetz') and t2 in ('date', 'timestamp', 'timestamptz')) or
	   (t2 in ('time', 'timetz') and t1 in ('date', 'timestamp', 'timestamptz')) then
		return common.__type__get_canonical_output_name('text');
	end if;
	
	-- gerarchia numerica (dal più specifico al più generico)
	-- float8 > float4 > numeric > int8 > int4 > int2
	
	-- float8 è il più ampio
	if t1 = 'float8' or t2 = 'float8' then
		if t1 in ('int2', 'int4', 'int8', 'numeric', 'float4', 'float8') and
		   t2 in ('int2', 'int4', 'int8', 'numeric', 'float4', 'float8') then
			return common.__type__get_canonical_output_name('float8');
		end if;
	end if;
	
	-- float4
	if (t1 = 'float4' or t2 = 'float4') and
	   not (t1 = 'float8' or t2 = 'float8') then
		if t1 in ('int2', 'int4', 'int8', 'numeric', 'float4') and
		   t2 in ('int2', 'int4', 'int8', 'numeric', 'float4') then
			return common.__type__get_canonical_output_name('float4');
		end if;
	end if;
	
	-- numeric
	if (t1 = 'numeric' or t2 = 'numeric') and
	   not (t1 in ('float4', 'float8') or t2 in ('float4', 'float8')) then
		if t1 in ('int2', 'int4', 'int8', 'numeric') and
		   t2 in ('int2', 'int4', 'int8', 'numeric') then
			return common.__type__get_canonical_output_name('numeric');
		end if;
	end if;
	
	-- int8
	if (t1 = 'int8' or t2 = 'int8') and
	   not (t1 in ('numeric', 'float4', 'float8') or t2 in ('numeric', 'float4', 'float8')) then
		if t1 in ('int2', 'int4', 'int8') and
		   t2 in ('int2', 'int4', 'int8') then
			return common.__type__get_canonical_output_name('int8');
		end if;
	end if;
	
	-- int4
	if (t1 = 'int4' or t2 = 'int4') and
	   not (t1 in ('int8', 'numeric', 'float4', 'float8') or t2 in ('int8', 'numeric', 'float4', 'float8')) then
		if t1 in ('int2', 'int4') and
		   t2 in ('int2', 'int4') then
			return common.__type__get_canonical_output_name('int4');
		end if;
	end if;
	
	-- smallint (già gestito sopra)
	
	-- bool rimane bool solo se entrambi sono bool
	if t1 = 'bool' and t2 = 'bool' then
		return common.__type__get_canonical_output_name('bool');
	end if;
	
	-- text è compatibile con tutto e diventa text
	if t1 = 'text' or t2 = 'text' then
		return common.__type__get_canonical_output_name('text');
	end if;
	
	-- varchar/char management -> entrambi diventano text (varchar è variabile)
	if (t1 in ('varchar', 'char') and t2 in ('varchar', 'char', 'text')) or
	   (t2 in ('varchar', 'char') and t1 in ('varchar', 'char', 'text')) then
		return common.__type__get_canonical_output_name('text');
	end if;
	
	-- uuid rimane uuid solo se entrambi sono uuid
	if t1 = 'uuid' and t2 = 'uuid' then
		return common.__type__get_canonical_output_name('uuid');
	end if;
	
	-- tipi non compatibili -> text
	return common.__type__get_canonical_output_name('text');
	
end;
$$;


--
-- Name: test_jsonb_extract_multiple_paths; Type: VIEW; Schema: common; Owner: -
--

CREATE VIEW common.test_jsonb_extract_multiple_paths AS
 WITH test_data AS (
         SELECT '{"params": {"config1": {"other": "ignore", "surpa": "value1"}, "config2": {"surpa": "value2", "inner_arry_Var": [1, 3, 4, 5]}, "t_username": "modify_user_id", "simple_field": "simple_value"}, "complex": [{"beta": 2, "alpha": 1}, {"beta": 5, "alpha": 3, "gamma": 45646}], "arry_Var": [1, 3, 4, 5], "simple_variable": 4, "state_variables": {"is_ready": true}}'::jsonb AS data
        )
 SELECT 'Pattern costruiti:'::text AS test,
    common.jsonb_set_building_path(common.jsonb_set_building_path('{}'::jsonb, 'params.*.surpa'::text, 'true'::jsonb), 'params.t_username'::text, 'true'::jsonb) AS pattern_structure
UNION ALL
 SELECT 'Wildcard sub + match singolo:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.*.config1'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'Path semplice:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.params.t_username'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'Wildcard:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.params.*.surpa'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'variabile semplice:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.simple_variable'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'Multipli:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.params.t_username'::text, '$.params.*.surpa'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'array:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.*.*.*.4'::text, '$.*.4'::text]) AS pattern_structure
   FROM test_data
UNION ALL
 SELECT 'array di oggetti:'::text AS test,
    common.jsonb_extract_multiple_paths(test_data.data, ARRAY['$.complex.*.gamma'::text]) AS pattern_structure
   FROM test_data;


--
-- PostgreSQL database dump complete
--


SET check_function_bodies = on;
