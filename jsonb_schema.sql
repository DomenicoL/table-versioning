--
-- Name: __jsonb_schema__validate(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate(data jsonb, schema jsonb, path text default '$'::text) 
returns text[]
language plpgsql
as $$
declare
	error_list text[] := array[]::text[];
	temp_errors text[];
begin
	-- valida il tipo principale
	temp_errors := common.__jsonb_schema__validate_type(data, schema, path);
	error_list := error_list || temp_errors;
	
	-- valida le proprietà se è un oggetto
	if jsonb_typeof(data) = 'object' and schema ? 'properties' then
		temp_errors := common.__jsonb_schema__validate_properties(data, schema, path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida i required fields
	if schema ? 'required' then
		temp_errors := common.__jsonb_schema__validate_required(data, schema, path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida enum se presente
	if schema ? 'enum' then
		temp_errors := common.__jsonb_schema__validate_enum(data, schema, path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida format se presente
	if schema ? 'format' then
		temp_errors := common.__jsonb_schema__validate_format(data, schema, path);
		error_list := error_list || temp_errors;
	end if;
	
	-- valida string constraints
	temp_errors := common.__jsonb_schema__validate_string_constraints(data, schema, path);
	error_list := error_list || temp_errors;
	
	-- valida number constraints
	temp_errors := common.__jsonb_schema__validate_number_constraints(data, schema, path);
	error_list := error_list || temp_errors;
	
	-- valida array constraints
	temp_errors := common.__jsonb_schema__validate_array_constraints(data, schema, path);
	error_list := error_list || temp_errors;
	
	-- valida object constraints
	temp_errors := common.__jsonb_schema__validate_object_constraints(data, schema, path);
	error_list := error_list || temp_errors;
	
	-- valida logical operators (anyOf, allOf, oneOf, not)
	temp_errors := common.__jsonb_schema__validate_logical(data, schema, path);
	error_list := error_list || temp_errors;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate(data jsonb, schema jsonb, path text) 
is 'Valida un documento JSONB contro un JSON Schema completo. Include tutte le validazioni: tipo, proprietà, required, enum, format, string/number/array/object constraints e operatori logici.';

-- ========================================
-- AGGIORNAMENTO METODI ESISTENTI
-- ========================================

--
-- Name: __jsonb_schema__validate_enum(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate_enum(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
declare
	error_list text[] := array[]::text[];
begin
	if not (schema->'enum' @> to_jsonb(data)) then
		error_list := error_list || format('Path %s: value %s not in enum %s', 
			path, data::text, (schema->'enum')::text);
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_enum(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida che il valore sia presente nell''array enum specificato nello schema.';

--
-- Name: __jsonb_schema__validate_format(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate_format(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $_$
declare
	format_type text;
	data_text text;
	error_list text[] := array[]::text[];
begin
	-- solo stringhe possono avere format
	if jsonb_typeof(data) != 'string' then
		return error_list;
	end if;
	
	format_type := schema->>'format';
	data_text := data #>> '{}'; -- estrae il valore stringa
	
	case format_type
		when 'date-time' then
			-- RFC 3339 date-time format
			if not (data_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$') then
				error_list := error_list || format('Path %s: invalid date-time format "%s"', path, data_text);
			else
				-- verifica che sia una data valida
				begin
					perform data_text::timestamp with time zone;
				exception
					when others then
						error_list := error_list || format('Path %s: invalid date-time value "%s"', path, data_text);
				end;
			end if;
			
		when 'date' then
			-- YYYY-MM-DD format
			if not (data_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') then
				error_list := error_list || format('Path %s: invalid date format "%s"', path, data_text);
			else
				begin
					perform data_text::date;
				exception
					when others then
						error_list := error_list || format('Path %s: invalid date value "%s"', path, data_text);
				end;
			end if;
			
		when 'time' then
			-- HH:MM:SS format
			if not (data_text ~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?$') then
				error_list := error_list || format('Path %s: invalid time format "%s"', path, data_text);
			else
				begin
					perform data_text::time;
				exception
					when others then
						error_list := error_list || format('Path %s: invalid time value "%s"', path, data_text);
				end;
			end if;
			
		when 'email' then
			-- basic email validation
			if not (data_text ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') then
				error_list := error_list || format('Path %s: invalid email format "%s"', path, data_text);
			end if;
			
		when 'uri' then
			-- basic URI validation
			if not (data_text ~ '^[a-zA-Z][a-zA-Z0-9+.-]*:') then
				error_list := error_list || format('Path %s: invalid uri format "%s"', path, data_text);
			end if;
			
		when 'uuid' then
			-- UUID v4 format
			if not (data_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
				error_list := error_list || format('Path %s: invalid uuid format "%s"', path, data_text);
			else
				begin
					perform data_text::uuid;
				exception
					when others then
						error_list := error_list || format('Path %s: invalid uuid value "%s"', path, data_text);
				end;
			end if;
			
		when 'ipv4' then
			-- IPv4 format
			if not (data_text ~ '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') then
				error_list := error_list || format('Path %s: invalid ipv4 format "%s"', path, data_text);
			else
				begin
					perform data_text::inet;
				exception
					when others then
						error_list := error_list || format('Path %s: invalid ipv4 value "%s"', path, data_text);
				end;
			end if;
			
		when 'ipv6' then
			-- basic IPv6 validation (semplificata)
			if not (data_text ~ '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$') then
				error_list := error_list || format('Path %s: invalid ipv6 format "%s"', path, data_text);
			end if;
			
		else
			-- format non supportato, ma non è un errore
			null;
	end case;
	
	return error_list;
end;
$_$;

comment on function common.__jsonb_schema__validate_format(data jsonb, schema jsonb, path text) 
is 'Valida i formati stringa (date-time, date, time, email, uri, uuid, ipv4, ipv6) secondo le specifiche JSON Schema.';

--
-- Name: __jsonb_schema__validate_properties(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate_properties(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $_$
declare
	prop_name text;
	prop_schema jsonb;
	prop_data jsonb;
	error_list text[] := array[]::text[];
	temp_errors text[];
	current_path text;
begin
	-- itera su ogni proprietà definita nello schema
	for prop_name, prop_schema in
		select key, value from jsonb_each(schema->'properties')
	loop
		current_path := format('%s.%s', path, prop_name);
		
		if data ? prop_name then
			prop_data := data->prop_name;
			
			-- gestisce $ref
			if prop_schema ? '$ref' then
				-- risolve il riferimento (implementazione semplificata)
				declare
					ref_path text := prop_schema->>'$ref';
					definitions_schema jsonb;
				begin
					if ref_path like '#/definitions/%' then
						ref_path := replace(ref_path, '#/definitions/', '');
						definitions_schema := schema->'definitions'->ref_path;
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
	if schema ? 'additionalProperties' and (schema->'additionalProperties')::boolean = false then
		for prop_name in
			select key from jsonb_object_keys(data) key
			where not (schema->'properties' ? key)
		loop
			error_list := error_list || format('Path %s.%s: additional property not allowed', 
				path, prop_name);
		end loop;
	end if;
	
	return error_list;
end;
$_$;

comment on function common.__jsonb_schema__validate_properties(data jsonb, schema jsonb, path text) 
is 'Valida le proprietà di un oggetto JSONB contro lo schema. Gestisce validation ricorsiva, $ref, e additionalProperties.';

--
-- Name: __jsonb_schema__validate_required(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate_required(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
declare
	required_field text;
	error_list text[] := array[]::text[];
begin
	for required_field in
		select jsonb_array_elements_text(schema->'required')
	loop
		if not (data ? required_field) then
			error_list := error_list || format('Path %s: missing required property "%s"', 
				path, required_field);
		end if;
	end loop;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_required(data jsonb, schema jsonb, path text) 
is 'Verifica che tutti i campi obbligatori specificati nell''array "required" dello schema siano presenti nel documento.';

--
-- Name: __jsonb_schema__validate_type(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.__jsonb_schema__validate_type(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
declare
	expected_type jsonb;
	actual_type text;
	error_list text[] := array[]::text[];
begin
	expected_type := schema->'type';
	actual_type := jsonb_typeof(data);
	
	if expected_type is null then
		return error_list;
	end if;
	
	-- gestisce array di tipi (es. ["string", "null"])
	if jsonb_typeof(expected_type) = 'array' then
		if not (expected_type @> to_jsonb(actual_type)) then
			error_list := error_list || format('Path %s: expected one of %s, got %s', 
				path, expected_type::text, actual_type);
		end if;
	else
		-- tipo singolo
		if expected_type::text != format('"%s"', actual_type) then
			error_list := error_list || format('Path %s: expected %s, got %s', 
				path, expected_type::text, actual_type);
		end if;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_type(data jsonb, schema jsonb, path text) 
is 'Valida il tipo di un valore JSONB contro lo schema. Supporta tipi singoli e array di tipi (es. ["string", "null"]).';

-- ========================================
-- STRING CONSTRAINTS VALIDATION
-- ========================================

--
-- Name: __jsonb_schema__validate_string_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create function common.__jsonb_schema__validate_string_constraints(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
declare
	data_text text;
	data_length integer;
	min_length integer;
	max_length integer;
	pattern_regex text;
	error_list text[] := array[]::text[];
begin
	-- solo stringhe possono avere string constraints
	if jsonb_typeof(data) != 'string' then
		return error_list;
	end if;
	
	data_text := data #>> '{}';
	data_length := char_length(data_text);
	
	-- minLength validation
	if schema ? 'minLength' then
		min_length := (schema->>'minLength')::integer;
		if data_length < min_length then
			error_list := error_list || format('Path %s: string length %s is less than minLength %s', 
				path, data_length, min_length);
		end if;
	end if;
	
	-- maxLength validation
	if schema ? 'maxLength' then
		max_length := (schema->>'maxLength')::integer;
		if data_length > max_length then
			error_list := error_list || format('Path %s: string length %s exceeds maxLength %s', 
				path, data_length, max_length);
		end if;
	end if;
	
	-- pattern validation
	if schema ? 'pattern' then
		pattern_regex := schema->>'pattern';
		if not (data_text ~ pattern_regex) then
			error_list := error_list || format('Path %s: string "%s" does not match pattern "%s"', 
				path, data_text, pattern_regex);
		end if;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_string_constraints(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida i vincoli delle stringhe: minLength, maxLength, pattern.';

-- ========================================
-- NUMBER CONSTRAINTS VALIDATION
-- ========================================

--
-- Name: __jsonb_schema__validate_number_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create function common.__jsonb_schema__validate_number_constraints(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
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
	if jsonb_typeof(data) not in ('number') then
		return error_list;
	end if;
	
	data_number := (data #>> '{}')::numeric;
	
	-- minimum validation
	if schema ? 'minimum' then
		minimum_val := (schema->>'minimum')::numeric;
		if data_number < minimum_val then
			error_list := error_list || format('Path %s: value %s is less than minimum %s', 
				path, data_number, minimum_val);
		end if;
	end if;
	
	-- maximum validation
	if schema ? 'maximum' then
		maximum_val := (schema->>'maximum')::numeric;
		if data_number > maximum_val then
			error_list := error_list || format('Path %s: value %s exceeds maximum %s', 
				path, data_number, maximum_val);
		end if;
	end if;
	
	-- exclusiveMinimum validation
	if schema ? 'exclusiveMinimum' then
		exclusive_min := (schema->>'exclusiveMinimum')::numeric;
		if data_number <= exclusive_min then
			error_list := error_list || format('Path %s: value %s must be greater than exclusiveMinimum %s', 
				path, data_number, exclusive_min);
		end if;
	end if;
	
	-- exclusiveMaximum validation
	if schema ? 'exclusiveMaximum' then
		exclusive_max := (schema->>'exclusiveMaximum')::numeric;
		if data_number >= exclusive_max then
			error_list := error_list || format('Path %s: value %s must be less than exclusiveMaximum %s', 
				path, data_number, exclusive_max);
		end if;
	end if;
	
	-- multipleOf validation
	if schema ? 'multipleOf' then
		multiple_of_val := (schema->>'multipleOf')::numeric;
		if multiple_of_val > 0 and (data_number % multiple_of_val) != 0 then
			error_list := error_list || format('Path %s: value %s is not a multiple of %s', 
				path, data_number, multiple_of_val);
		end if;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_number_constraints(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida i vincoli numerici: minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf.';

-- ========================================
-- ARRAY CONSTRAINTS VALIDATION
-- ========================================

--
-- Name: __jsonb_schema__validate_array_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create function common.__jsonb_schema__validate_array_constraints(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
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
	if jsonb_typeof(data) != 'array' then
		return error_list;
	end if;
	
	array_length := jsonb_array_length(data);
	
	-- minItems validation
	if schema ? 'minItems' then
		min_items := (schema->>'minItems')::integer;
		if array_length < min_items then
			error_list := error_list || format('Path %s: array length %s is less than minItems %s', 
				path, array_length, min_items);
		end if;
	end if;
	
	-- maxItems validation
	if schema ? 'maxItems' then
		max_items := (schema->>'maxItems')::integer;
		if array_length > max_items then
			error_list := error_list || format('Path %s: array length %s exceeds maxItems %s', 
				path, array_length, max_items);
		end if;
	end if;
	
	-- uniqueItems validation
	if schema ? 'uniqueItems' and (schema->>'uniqueItems')::boolean = true then
		-- costruisce array per controllo unicità
		for item in select jsonb_array_elements(data)
		loop
			if item = any(unique_check) then
				error_list := error_list || format('Path %s: array contains duplicate items', path);
				exit;
			end if;
			unique_check := unique_check || item;
		end loop;
	end if;
	
	-- items validation (schema per ogni elemento dell'array)
	if schema ? 'items' then
		items_schema := schema->'items';
		item_index := 0;
		
		for item_data in select jsonb_array_elements(data)
		loop
			current_path := format('%s[%s]', path, item_index);
			
			-- valida ricorsivamente ogni elemento
			temp_errors := common.__jsonb_schema__validate(item_data, items_schema, current_path);
			error_list := error_list || temp_errors;
			
			item_index := item_index + 1;
		end loop;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_array_constraints(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida i vincoli degli array: minItems, maxItems, uniqueItems, items.';

-- ========================================
-- OBJECT CONSTRAINTS VALIDATION
-- ========================================

--
-- Name: __jsonb_schema__validate_object_constraints(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create function common.__jsonb_schema__validate_object_constraints(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
declare
	properties_count integer;
	min_properties integer;
	max_properties integer;
	error_list text[] := array[]::text[];
begin
	-- solo oggetti possono avere object constraints
	if jsonb_typeof(data) != 'object' then
		return error_list;
	end if;
	
	-- conta il numero di proprietà
	select count(*) into properties_count
	from jsonb_object_keys(data);
	
	-- minProperties validation
	if schema ? 'minProperties' then
		min_properties := (schema->>'minProperties')::integer;
		if properties_count < min_properties then
			error_list := error_list || format('Path %s: object has %s properties, minimum required is %s', 
				path, properties_count, min_properties);
		end if;
	end if;
	
	-- maxProperties validation
	if schema ? 'maxProperties' then
		max_properties := (schema->>'maxProperties')::integer;
		if properties_count > max_properties then
			error_list := error_list || format('Path %s: object has %s properties, maximum allowed is %s', 
				path, properties_count, max_properties);
		end if;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_object_constraints(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida i vincoli degli oggetti: minProperties, maxProperties.';

-- ========================================
-- LOGICAL OPERATORS VALIDATION
-- ========================================

--
-- Name: __jsonb_schema__validate_logical(jsonb, jsonb, text); Type: FUNCTION; Schema: common; Owner: -
--

create function common.__jsonb_schema__validate_logical(data jsonb, schema jsonb, path text) 
returns text[]
language plpgsql
as $$
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
	if schema ? 'anyOf' then
		any_of_valid := false;
		
		for sub_schema in select jsonb_array_elements(schema->'anyOf')
		loop
			temp_errors := common.__jsonb_schema__validate(data, sub_schema, path);
			if array_length(temp_errors, 1) is null then
				any_of_valid := true;
				exit; -- non appena uno è valido, esci
			end if;
		end loop;
		
		if not any_of_valid then
			error_list := error_list || format('Path %s: does not match any schema in anyOf', path);
		end if;
	end if;
	
	-- allOf: tutti gli schemi devono essere validi
	if schema ? 'allOf' then
		all_of_errors := array[]::text[];
		
		for sub_schema in select jsonb_array_elements(schema->'allOf')
		loop
			temp_errors := common.__jsonb_schema__validate(data, sub_schema, path);
			all_of_errors := all_of_errors || temp_errors;
		end loop;
		
		error_list := error_list || all_of_errors;
	end if;
	
	-- oneOf: esattamente uno schema deve essere valido
	if schema ? 'oneOf' then
		one_of_valid_count := 0;
		
		for sub_schema in select jsonb_array_elements(schema->'oneOf')
		loop
			temp_errors := common.__jsonb_schema__validate(data, sub_schema, path);
			if array_length(temp_errors, 1) is null then
				one_of_valid_count := one_of_valid_count + 1;
			end if;
		end loop;
		
		if one_of_valid_count = 0 then
			error_list := error_list || format('Path %s: does not match any schema in oneOf', path);
		elsif one_of_valid_count > 1 then
			error_list := error_list || format('Path %s: matches %s schemas in oneOf, expected exactly 1', 
				path, one_of_valid_count);
		end if;
	end if;
	
	-- not: lo schema NON deve essere valido
	if schema ? 'not' then
		temp_errors := common.__jsonb_schema__validate(data, schema->'not', path);
		if array_length(temp_errors, 1) is null then
			error_list := error_list || format('Path %s: should not be valid against the "not" schema', path);
		end if;
	end if;
	
	return error_list;
end;
$$;

comment on function common.__jsonb_schema__validate_logical(data jsonb, schema jsonb, path text) 
is '[PRIVATA] Valida gli operatori logici JSON Schema: anyOf, allOf, oneOf, not.';

-- ========================================
-- FUNZIONI PUBBLICHE (invariate)
-- ========================================

--
-- Name: jsonb_schema__get_errors(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.jsonb_schema__get_errors(data jsonb, schema jsonb) 
returns text[]
language sql
as $$
	select (common.jsonb_schema__validate(data, schema)).errors;
$$;

comment on function common.jsonb_schema__get_errors(data jsonb, schema jsonb) 
is 'Funzione di convenienza che restituisce solo l''array degli errori di validazione con percorsi dettagliati.';

--
-- Name: jsonb_schema__is_valid(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.jsonb_schema__is_valid(data jsonb, schema jsonb) 
returns boolean
language sql
as $$
	select (common.jsonb_schema__validate(data, schema)).is_valid;
$$;

comment on function common.jsonb_schema__is_valid(data jsonb, schema jsonb) 
is 'Funzione di convenienza che restituisce solo un boolean indicando se il documento JSONB è valido secondo lo schema fornito.';

--
-- Name: jsonb_schema__validate(jsonb, jsonb); Type: FUNCTION; Schema: common; Owner: -
--

create or replace function common.jsonb_schema__validate(data jsonb, schema jsonb) 
returns table(is_valid boolean, errors text[])
language plpgsql
as $$
declare
	error_list text[] := array[]::text[];
begin
	error_list = common.__jsonb_schema__validate(data, schema);
	
	return query select array_length(error_list, 1) is null, error_list;
end;
$$;

comment on function common.jsonb_schema__validate(data jsonb, schema jsonb) 
is 'Valida un documento JSONB contro un JSON Schema. Restituisce sia il risultato della validazione che un array di errori dettagliati con i percorsi degli errori.';

