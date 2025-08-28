# PostgreSQL Bitemporal Solution: Funciton references
	
[main](main.md) - [readme](../README.md)


## Schema: common

Package Count: 6

### Package: jsonb_schema

Method Count: 3

#### Private Functions

##### validate_enum
[PRIVATA] Valida che il valore sia presente nell'array enum specificato nello schema.
- *Full Identifier*: `common.__jsonb_schema__validate_enum`
- *Arguments*: `data jsonb, schema jsonb, path text`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

##### validate_format
[PRIVATA] Valida i formati stringa (date-time, date, time, email, uri, uuid, ipv4, ipv6) secondo le specifiche JSON Schema.
- *Full Identifier*: `common.__jsonb_schema__validate_format`
- *Arguments*: `data jsonb, schema jsonb, path text`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

##### validate_properties
[PRIVATA] Valida le proprietà di un oggetto JSONB contro lo schema. Gestisce validation ricorsiva, $ref, e additionalProperties.
- *Full Identifier*: `common.__jsonb_schema__validate_properties`
- *Arguments*: `data jsonb, schema jsonb, path text`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

##### validate_required
[PRIVATA] Verifica che tutti i campi obbligatori specificati nell'array "required" dello schema siano presenti nel documento.
- *Full Identifier*: `common.__jsonb_schema__validate_required`
- *Arguments*: `data jsonb, schema jsonb, path text`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

##### validate_type
[PRIVATA] Valida il tipo di un valore JSONB contro lo schema. Supporta tipi singoli e array di tipi (es. ["string", "null"]).
- *Full Identifier*: `common.__jsonb_schema__validate_type`
- *Arguments*: `data jsonb, schema jsonb, path text`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

#### Public Functions

##### get_errors
Funzione di convenienza che restituisce solo l'array degli errori di validazione con percorsi dettagliati.
- *Full Identifier*: `common.jsonb_schema__get_errors`
- *Arguments*: `data jsonb, schema jsonb`
- *Returns*: `text[]`

##### is_valid
Funzione di convenienza che restituisce solo un boolean indicando se il documento JSONB è valido secondo lo schema fornito.
- *Full Identifier*: `common.jsonb_schema__is_valid`
- *Arguments*: `data jsonb, schema jsonb`
- *Returns*: `boolean`

##### validate
Valida un documento JSONB contro un JSON Schema. Restituisce sia il risultato della validazione che un array di errori dettagliati con i percorsi degli errori.
- *Full Identifier*: `common.jsonb_schema__validate`
- *Arguments*: `data jsonb, schema jsonb`
- *Returns*: `TABLE(is_valid boolean, errors text[])`

### Package: type

Method Count: 3

#### Private Functions

##### get_canonical_output_name
- *Full Identifier*: `common.__type__get_canonical_output_name`
- *Arguments*: `internal_type text`
- *Returns*: `text`

##### normalize_name
- *Full Identifier*: `common.__type__normalize_name`
- *Arguments*: `type_name text`
- *Returns*: `text`

#### Public Functions

##### detect_from_value
- *Full Identifier*: `common.type__detect_from_value`
- *Arguments*: `str_value text`
- *Returns*: `text`

##### detect_jsonb_field
- *Full Identifier*: `common.type__detect_jsonb_field`
- *Arguments*: `json_value jsonb`
- *Returns*: `text`

##### get_wider
- *Full Identifier*: `common.type__get_wider`
- *Arguments*: `type1 text, type2 text`
- *Returns*: `text`

---

### Functions Without Package



Method Count: 8

#### Public Functions

##### bind_variable
- *Full Identifier*: `common.bind_variable`
- *Arguments*: `pattern_to_process text, variable_to_process hstore, start_delimiter text DEFAULT ':'::text, end_delimiter text DEFAULT ':'::text`
- *Returns*: `text`

##### coalesce_array
- *Full Identifier*: `common.coalesce_array`
- *Arguments*: `array_to_collapse anycompatiblearray`
- *Returns*: `anycompatible`

##### dquote_literal
- *Full Identifier*: `common.dquote_literal`
- *Arguments*: `text_to_dquote text`
- *Returns*: `text`

##### get_diagnostic_text
- *Full Identifier*: `common.get_diagnostic_text`
- *Arguments*: `skip_lines integer DEFAULT 0`
- *Returns*: `text`

##### hstore_strip_nulls
- *Full Identifier*: `common.hstore_strip_nulls`
- *Arguments*: `hstore_to_strip hstore`
- *Returns*: `hstore`

##### is_empty
- *Full Identifier*: `common.is_empty`
- *Arguments*: `value_to_test anycompatible`
- *Returns*: `boolean`

##### jsonb_array_to_string
- *Full Identifier*: `common.jsonb_array_to_string`
- *Arguments*: `arr jsonb, separator text DEFAULT ', '::text`
- *Returns*: `text`

##### jsonb_array_to_text_array
- *Full Identifier*: `common.jsonb_array_to_text_array`
- *Arguments*: `_js jsonb`
- *Returns*: `text[]`

##### jsonb_extract_multiple_paths
- *Full Identifier*: `common.jsonb_extract_multiple_paths`
- *Arguments*: `json_data jsonb, path_patterns text[]`
- *Returns*: `jsonb`

##### jsonb_extract_recursive
- *Full Identifier*: `common.jsonb_extract_recursive`
- *Arguments*: `json_data jsonb, jb_patterns jsonb`
- *Returns*: `jsonb`

##### jsonb_keys_to_array
If jsonb keys are in format __%anydigits__ represent a malfomed array
"a":{"__1__": {"b":14}, "__2__":{"c":"alfa"}} => "a": [{"__id__":1,"b": 14}, {"__id__":2,"c":"alfa"}]
or
"a":{"__1__": 14, "__2__":"alfa"} => "a": [{"__id__":1,"__innerValue": 14}, {"__id__":2,"__innerValue":"alfa"}]


This function correct this situation
- *Full Identifier*: `common.jsonb_keys_to_array`
- *Arguments*: `_jb jsonb, pattern text DEFAULT NULL::text`
- *Returns*: `jsonb`

##### jsonb_linearize
Starting with a jsonb (usually coherent with a jason schema)
retrieve an key-value notation, where Key use the ltree notation:
"a.b.c" -> 56
if there are array in the path  (consider "c" as array) is used notation:
"a.b.c.__00001__" -> 45

Output is yet a jsonb
- *Full Identifier*: `common.jsonb_linearize`
- *Arguments*: `jb jsonb, prefix text DEFAULT ''::text`
- *Returns*: `jsonb`

##### jsonb_linearize_to_key_value
- *Full Identifier*: `common.jsonb_linearize_to_key_value`
- *Arguments*: `jb jsonb, prefix text DEFAULT ''::text`
- *Returns*: `SETOF common.key_value_list`

##### jsonb_recursive_intersect
- *Full Identifier*: `common.jsonb_recursive_intersect`
- *Arguments*: `first_jb jsonb, second_jb jsonb`
- *Returns*: `jsonb`

##### jsonb_recursive_left_merge
- *Full Identifier*: `common.jsonb_recursive_left_merge`
- *Arguments*: `first_jb jsonb, second_jb jsonb, strip_nulls boolean DEFAULT false`
- *Returns*: `jsonb`

##### jsonb_recursive_merge
- *Full Identifier*: `common.jsonb_recursive_merge`
- *Arguments*: `jb_list jsonb[]`
- *Returns*: `jsonb`

##### jsonb_recursive_merge (1)
- *Full Identifier*: `common.jsonb_recursive_merge`
- *Arguments*: `first_jb jsonb, second_jb jsonb`
- *Returns*: `jsonb`

##### jsonb_set_building_path
- *Full Identifier*: `common.jsonb_set_building_path`
- *Arguments*: `jsonb_in jsonb, key_to_set ltree, value_to_set jsonb, create_if_missing boolean DEFAULT true`
- *Returns*: `jsonb`

##### jsonb_set_building_path (1)
- *Full Identifier*: `common.jsonb_set_building_path`
- *Arguments*: `jsonb_in jsonb, key_to_set text, value_to_set jsonb, create_if_missing boolean DEFAULT true`
- *Returns*: `jsonb`

##### key_value_to_jsonb
- *Full Identifier*: `common.key_value_to_jsonb`
- *Arguments*: `key_value_list_to_process common.key_value_list[]`
- *Returns*: `jsonb`

##### key_value_to_jsonb (1)
- *Full Identifier*: `common.key_value_to_jsonb`
- *Arguments*: `path_to_process ltree, value_to_set jsonb, idx ltree DEFAULT ''::ltree`
- *Returns*: `jsonb`

##### quote_for_json
- *Full Identifier*: `common.quote_for_json`
- *Arguments*: `value_to_quote anyelement`
- *Returns*: `text`

##### records_equal
- *Full Identifier*: `common.records_equal`
- *Arguments*: `record1 record, record2 record, exclude_fields text[] DEFAULT ARRAY[]::text[]`
- *Returns*: `boolean`

##### regexp_replace_array
apply a regex_replace for all element of an array
- *Full Identifier*: `common.regexp_replace_array`
- *Arguments*: `text_to_replace text, pattern text, replacement text[], flags text DEFAULT ''::text`
- *Returns*: `text`

##### to_jsonb_with_type
- *Full Identifier*: `common.to_jsonb_with_type`
- *Arguments*: `value_to_convert text, type_of_value text`
- *Returns*: `jsonb`

---
[main](main.md) - [readme](../README.md)

## Schema: srvc

Package Count: 3

### Package: ddl_get

Method Count: 2

#### Public Functions

##### bitemporal_view
Get the standard defintion of view ready for manage bitemporal storage.
- *Full Identifier*: `srvc.ddl_get__bitemporal_view`
- *Arguments*: `table_schema text, table_name text, full_view_name text DEFAULT NULL::text`
- *Returns*: `text`

##### history_table
- *Full Identifier*: `srvc.ddl_get__history_table`
- *Arguments*: `table_schema text, table_name text, full_history_table_name text DEFAULT NULL::text`
- *Returns*: `text`

---

### Functions Without Package



Method Count: 15

#### Public Functions

##### analyze_schema_functions
- *Full Identifier*: `srvc.analyze_schema_functions`
- *Arguments*: `p_schema_name text`
- *Returns*: `TABLE(function_type text, count_functions bigint, total_lines bigint, avg_complexity numeric)`

##### clone_schema
- *Full Identifier*: `srvc.clone_schema`
- *Arguments*: `source_schema text, dest_schema text, include_recs boolean`
- *Returns*: `void`

##### create_additional_table
- *Full Identifier*: `srvc.create_additional_table`
- *Arguments*: `table_schema text, table_name text`
- *Returns*: `boolean`

##### find_table_dependencies
- *Full Identifier*: `srvc.find_table_dependencies`
- *Arguments*: `p_schema_name text, p_table_name text`
- *Returns*: `TABLE(function_name name, function_schema name, parameters text, return_type text, found_in text)`

##### generate_coalesce_update
- *Full Identifier*: `srvc.generate_coalesce_update`
- *Arguments*: `p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text, p_target_type text DEFAULT 'table'::text`
- *Returns*: `text`

##### generate_function_parameters
- *Full Identifier*: `srvc.generate_function_parameters`
- *Arguments*: `p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text`
- *Returns*: `text`

##### generate_set_clauses
- *Full Identifier*: `srvc.generate_set_clauses`
- *Arguments*: `p_schema_name text, p_table_name text, p_primary_key text DEFAULT 'id'::text`
- *Returns*: `text`

##### get_aggregate_ddl
- *Full Identifier*: `srvc.get_aggregate_ddl`
- *Arguments*: `p_schema_name text, p_aggregate_name text DEFAULT NULL::text`
- *Returns*: `TABLE(aggregate_name text, drop_script text, create_script text)`

##### get_all_functions_ddl
- *Full Identifier*: `srvc.get_all_functions_ddl`
- *Arguments*: `p_schema_name text, p_function_name text DEFAULT NULL::text, p_include_aggregates boolean DEFAULT true`
- *Returns*: `TABLE(function_name text, function_type text, drop_script text, create_script text)`

##### get_custom_types_info
- *Full Identifier*: `srvc.get_custom_types_info`
- *Arguments*: `p_schema_name text DEFAULT NULL::text`
- *Returns*: `TABLE(type_schema text, type_name text, type_category character, type_description text)`

##### get_function_ddl
- *Full Identifier*: `srvc.get_function_ddl`
- *Arguments*: `p_schema_name text, p_function_name text DEFAULT NULL::text, p_function_type text DEFAULT NULL::text`
- *Returns*: `TABLE(function_name text, function_type text, drop_script text, create_script text)`

##### get_schema_funciton_definition
- *Full Identifier*: `srvc.get_schema_funciton_definition`
- *Arguments*: `schamas_where_search text`
- *Returns*: `jsonb`

##### get_schema_package
- *Full Identifier*: `srvc.get_schema_package`
- *Arguments*: `schemas_where_search text`
- *Returns*: `jsonb`

##### get_schema_package_md
- *Full Identifier*: `srvc.get_schema_package_md`
- *Arguments*: `schemas_where_search text`
- *Returns*: `text`

##### get_window_function_ddl
- *Full Identifier*: `srvc.get_window_function_ddl`
- *Arguments*: `p_schema_name text, p_function_name text DEFAULT NULL::text`
- *Returns*: `TABLE(function_name text, function_type text, drop_script text, create_script text)`

##### is_updatable_view
- *Full Identifier*: `srvc.is_updatable_view`
- *Arguments*: `p_schema_name text, p_view_name text`
- *Returns*: `boolean`

##### refact_function_call
- *Full Identifier*: `srvc.refact_function_call`
- *Arguments*: `text_to_search text, text_to_replace text, schamas_where_search text DEFAULT NULL::text, simulation boolean DEFAULT true, print_query boolean DEFAULT false`
- *Returns*: `jsonb`

##### search_func_ddl
- *Full Identifier*: `srvc.search_func_ddl`
- *Arguments*: `p_current_schema text, p_func_er text DEFAULT '.+'::text, p_target_schema text DEFAULT NULL::text`
- *Returns*: `text`

---
[main](main.md) - [readme](../README.md)

## Schema: vrsn

Package Count: 21

### Package: admin

Package wrapper for user.
 Every function thought to be used for a user is wrapped in this package.
 If you wish to add functionallity... probabily you're wrong....


Method Count: 9

#### Public Functions

##### bitemporal_entity_register
Easiast way to register a bitemporal table.
All the parameters as treathed in standard way.

- *Full Identifier*: `vrsn.admin__bitemporal_entity_register`
- *Arguments*: `p_current_table_schema text, p_current_table_name text, p_execute boolean DEFAULT false`
- *Returns*: `text`

##### bitemporal_entity_register (1)
You can pass an object in the format of admin__get_bitemporal_entity_conf_param
or an jsonb array of the same element.

With this method you can define many parameters for each entity
- *Full Identifier*: `vrsn.admin__bitemporal_entity_register`
- *Arguments*: `p_conf jsonb, p_execute boolean DEFAULT false`
- *Returns*: `text`

##### entity_change_behavior
- *Full Identifier*: `vrsn.admin__entity_change_behavior`
- *Arguments*: `p_entity_schema text, p_entity_name text, p_modify_user_id text, p_historice_entity vrsn.historice_entity_behaviour DEFAULT NULL::vrsn.historice_entity_behaviour, p_enable_history_attributes boolean DEFAULT NULL::boolean, p_main_fields_list text DEFAULT NULL::text, p_cached_fields_list text DEFAULT NULL::text, p_mitigate_conflicts boolean DEFAULT NULL::boolean, p_ignore_unchanged_values boolean DEFAULT NULL::boolean, p_enable_attribute_to_fields_replacement boolean DEFAULT NULL::boolean`
- *Returns*: `void`

##### get_bitemporal_entity_conf_param
Retrieve a  TABLE(input_example jsonb, json_schema jsonb)
With an input example and relative json_schema

Plese, remove all null parameters
- *Full Identifier*: `vrsn.admin__get_bitemporal_entity_conf_param`
- *Arguments*: ``
- *Returns*: `TABLE(input_example jsonb, json_schema jsonb)`

##### init
Destructive method.
Use only when you want to regenerate a clean configuration.
- *Full Identifier*: `vrsn.admin__init`
- *Arguments*: `only_get_query boolean`
- *Returns*: `text`

##### insert_global_attribute
- *Full Identifier*: `vrsn.admin__insert_global_attribute`
- *Arguments*: `p_attribute_name text, p_modify_user_id text, p_json_schema_plus jsonb DEFAULT NULL::jsonb`
- *Returns*: `bigint`

##### insert_local_attribute
- *Full Identifier*: `vrsn.admin__insert_local_attribute`
- *Arguments*: `p_attribute_name text, p_schema_name text, p_entity_name text, p_modify_user_id text, p_json_schema_plus jsonb DEFAULT NULL::jsonb`
- *Returns*: `bigint`

##### readme
- *Full Identifier*: `vrsn.admin__readme`
- *Arguments*: ``
- *Returns*: `text`

##### reserve_attribute
- *Full Identifier*: `vrsn.admin__reserve_attribute`
- *Arguments*: `p_attribute_id bigint, p_schema_name text, p_entity_name text, p_modify_user_id text`
- *Returns*: `bigint`

### Package: audit_record

Manage audit_record object.
It manage username, touchTs and other audit information on record stored.

Method Count: 9

#### Public Functions

##### build
- *Full Identifier*: `vrsn.audit_record__build`
- *Arguments*: ``
- *Returns*: `jsonb`

##### close
- *Full Identifier*: `vrsn.audit_record__close`
- *Arguments*: `user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT NULL::timestamp with time zone`
- *Returns*: `jsonb`

##### deactivate
Deactivate record.
This record will be outside of timeline from user perspective
- *Full Identifier*: `vrsn.audit_record__deactivate`
- *Arguments*: `user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT now()`
- *Returns*: `jsonb`

##### get_deactiovation_ts
- *Full Identifier*: `vrsn.audit_record__get_deactiovation_ts`
- *Arguments*: `audit_record jsonb`
- *Returns*: `timestamp with time zone`

##### is_active
- *Full Identifier*: `vrsn.audit_record__is_active`
- *Arguments*: `audit_record jsonb`
- *Returns*: `boolean`

##### readme
- *Full Identifier*: `vrsn.audit_record__readme`
- *Arguments*: ``
- *Returns*: `text`

##### reopen
- *Full Identifier*: `vrsn.audit_record__reopen`
- *Arguments*: `user_id text, audit_record jsonb, when_appens timestamp with time zone DEFAULT NULL::timestamp with time zone`
- *Returns*: `jsonb`

##### set
- *Full Identifier*: `vrsn.audit_record__set`
- *Arguments*: `value_to_set anycompatible, key_to_set text DEFAULT 'user_id'::text, audit_record jsonb DEFAULT NULL::jsonb`
- *Returns*: `jsonb`

##### validate
- *Full Identifier*: `vrsn.audit_record__validate`
- *Arguments*: `jb jsonb`
- *Returns*: `boolean`

### Package: bitemporal_entity

Manage objects under historicizaiton.
Giving an existing table:
- generate history table
- generate standard view (entity)
- register the behaviour of the entity, including if use the historicization by attributes
- generate entity for attribute (curren and history table and view).
Also provide method to customize in deep the attribute behaviour.

Method Count: 2

#### Private Functions

##### build_ddl
- *Full Identifier*: `vrsn.__bitemporal_entity__build_ddl`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### complete_conf_param
Complete missing value of conf parameter
- *Full Identifier*: `vrsn.__bitemporal_entity__complete_conf_param`
- *Arguments*: `p_conf jsonb`
- *Returns*: `jsonb`

##### get_attribute_entity_name
return name for the attribute entity starting from a bitemporal table or view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_attribute_entity_name`
- *Arguments*: `object_name text`
- *Returns*: `text`

##### get_attribute_table_name
return name for the attribute table
- *Full Identifier*: `vrsn.__bitemporal_entity__get_attribute_table_name`
- *Arguments*: `table_name text`
- *Returns*: `text`

##### get_current_table_name
return name for the current table starting from a bitemporal table or view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_current_table_name`
- *Arguments*: `object_name text`
- *Returns*: `text`

##### get_ddl_attribute_table
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_attribute_table`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### get_ddl_complete
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_complete`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### get_ddl_complete_attribute
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_complete_attribute`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### get_ddl_history_table
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_history_table`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### get_ddl_tsrange_idx
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_tsrange_idx`
- *Arguments*: `p_conf jsonb, p_entity text DEFAULT NULL::text`
- *Returns*: `text`

##### get_ddl_view
Get the standard defintion of view ready for manage bitemporal storage.
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_view`
- *Arguments*: `p_conf jsonb`
- *Returns*: `text`

##### get_ddl_view (1)
Get the standard defintion of view ready for manage bitemporal storage.
- *Full Identifier*: `vrsn.__bitemporal_entity__get_ddl_view`
- *Arguments*: `table_schema text, table_name text, full_view_name text DEFAULT NULL::text`
- *Returns*: `text`

##### get_entity_name
return  name for the entity starting from a bitemporal table or view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_entity_name`
- *Arguments*: `object_name text`
- *Returns*: `text`

##### get_history_table_name
return name for the history table starting from a bitemporal table or view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_history_table_name`
- *Arguments*: `object_name text`
- *Returns*: `text`

##### get_view_name
return name for the view starting from a bitemporal table or view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_view_name`
- *Arguments*: `object_name text`
- *Returns*: `text`

##### get_view_name_from_current_table
return name for the view
- *Full Identifier*: `vrsn.__bitemporal_entity__get_view_name_from_current_table`
- *Arguments*: `table_name text`
- *Returns*: `text`

#### Public Functions

##### change
- *Full Identifier*: `vrsn.bitemporal_entity__change`
- *Arguments*: `p_entity_schema text, p_entity_name text, p_modify_user_id text, p_historice_entity vrsn.historice_entity_behaviour DEFAULT NULL::vrsn.historice_entity_behaviour, p_enable_history_attributes boolean DEFAULT NULL::boolean, p_main_fields_list text DEFAULT NULL::text, p_cached_fields_list text DEFAULT NULL::text, p_mitigate_conflicts boolean DEFAULT NULL::boolean, p_ignore_unchanged_values boolean DEFAULT NULL::boolean, p_enable_attribute_to_fields_replacement boolean DEFAULT NULL::boolean`
- *Returns*: `void`

##### readme
- *Full Identifier*: `vrsn.bitemporal_entity__readme`
- *Arguments*: ``
- *Returns*: `text`

### Package: bitemporal_record

Method Count: 3

#### Public Functions

##### build
- *Full Identifier*: `vrsn.bitemporal_record__build`
- *Arguments*: `user_id text DEFAULT NULL::text, user_ts_start timestamp with time zone DEFAULT NULL::timestamp with time zone, db_ts_start timestamp with time zone DEFAULT NULL::timestamp with time zone`
- *Returns*: `vrsn.bitemporal_record`

##### get_deactiovation_ts
- *Full Identifier*: `vrsn.bitemporal_record__get_deactiovation_ts`
- *Arguments*: `bt_info vrsn.bitemporal_record`
- *Returns*: `timestamp with time zone`

##### is_active
- *Full Identifier*: `vrsn.bitemporal_record__is_active`
- *Arguments*: `bt_info vrsn.bitemporal_record`
- *Returns*: `boolean`

### Package: bitemporal_tsrange

Method Count: 2

#### Public Functions

##### close
- *Full Identifier*: `vrsn.bitemporal_tsrange__close`
- *Arguments*: `ts_range tstzrange, ts_end timestamp with time zone DEFAULT clock_timestamp()`
- *Returns*: `tstzrange`

##### create
- *Full Identifier*: `vrsn.bitemporal_tsrange__create`
- *Arguments*: `ts_start timestamp with time zone`
- *Returns*: `tstzrange`

### Package: entity_fullname_type

Boring collection of method to properly manage the user type: entity_fullname_type

Method Count: 1

#### Private Functions

##### array_agg_finalfn
- *Full Identifier*: `vrsn.__entity_fullname_type__array_agg_finalfn`
- *Arguments*: `state vrsn.entity_fullname_type[]`
- *Returns*: `vrsn.entity_fullname_type[]`

##### array_agg_transfn
- *Full Identifier*: `vrsn.__entity_fullname_type__array_agg_transfn`
- *Arguments*: `state vrsn.entity_fullname_type[], elem vrsn.entity_fullname_type`
- *Returns*: `vrsn.entity_fullname_type[]`

##### cmp
- *Full Identifier*: `vrsn.__entity_fullname_type__cmp`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `integer`

##### eq
- *Full Identifier*: `vrsn.__entity_fullname_type__eq`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### from_hstore
- *Full Identifier*: `vrsn.__entity_fullname_type__from_hstore`
- *Arguments*: `hs hstore`
- *Returns*: `vrsn.entity_fullname_type`

##### from_json
- *Full Identifier*: `vrsn.__entity_fullname_type__from_json`
- *Arguments*: `js json`
- *Returns*: `vrsn.entity_fullname_type`

##### from_jsonb
- *Full Identifier*: `vrsn.__entity_fullname_type__from_jsonb`
- *Arguments*: `js jsonb`
- *Returns*: `vrsn.entity_fullname_type`

##### from_string
- *Full Identifier*: `vrsn.__entity_fullname_type__from_string`
- *Arguments*: `input_string text`
- *Returns*: `vrsn.entity_fullname_type`

##### ge
- *Full Identifier*: `vrsn.__entity_fullname_type__ge`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### gt
- *Full Identifier*: `vrsn.__entity_fullname_type__gt`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### hash
- *Full Identifier*: `vrsn.__entity_fullname_type__hash`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `integer`

##### le
- *Full Identifier*: `vrsn.__entity_fullname_type__le`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### lt
- *Full Identifier*: `vrsn.__entity_fullname_type__lt`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### ne
- *Full Identifier*: `vrsn.__entity_fullname_type__ne`
- *Arguments*: `a vrsn.entity_fullname_type, b vrsn.entity_fullname_type`
- *Returns*: `boolean`

##### string_agg_transfn
- *Full Identifier*: `vrsn.__entity_fullname_type__string_agg_transfn`
- *Arguments*: `state text, elem vrsn.entity_fullname_type, delimiter text`
- *Returns*: `text`

##### test_extended
- *Full Identifier*: `vrsn.__entity_fullname_type__test_extended`
- *Arguments*: ``
- *Returns*: `void`

##### to_hstore
- *Full Identifier*: `vrsn.__entity_fullname_type__to_hstore`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `hstore`

##### to_ident
- *Full Identifier*: `vrsn.__entity_fullname_type__to_ident`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `text`

##### to_json
- *Full Identifier*: `vrsn.__entity_fullname_type__to_json`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `json`

##### to_jsonb
- *Full Identifier*: `vrsn.__entity_fullname_type__to_jsonb`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `jsonb`

##### to_string
- *Full Identifier*: `vrsn.__entity_fullname_type__to_string`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `text`

##### validate
- *Full Identifier*: `vrsn.__entity_fullname_type__validate`
- *Arguments*: `st vrsn.entity_fullname_type`
- *Returns*: `boolean`

#### Public Functions

##### readme
- *Full Identifier*: `vrsn.entity_fullname_type__readme`
- *Arguments*: ``
- *Returns*: `text`

### Package: jsonb_table_structure

Method Count: 11

#### Deprecated Functions

##### build
- *Full Identifier*: `vrsn._d_jsonb_table_structure__build`
- *Arguments*: `name_of_table text, name_of_schema text DEFAULT 'public'::text`
- *Returns*: `jsonb`

#### Public Functions

##### build
- *Full Identifier*: `vrsn.jsonb_table_structure__build`
- *Arguments*: `entity_full_name vrsn.entity_fullname_type, table_full_name vrsn.entity_fullname_type`
- *Returns*: `jsonb`

##### build (1)
- *Full Identifier*: `vrsn.jsonb_table_structure__build`
- *Arguments*: `p_fields_data vrsn.table_field_details[]`
- *Returns*: `jsonb`

##### build (2)
- *Full Identifier*: `vrsn.jsonb_table_structure__build`
- *Arguments*: `name_of_table text, name_of_schema text DEFAULT 'public'::text`
- *Returns*: `jsonb`

##### build (3)
- *Full Identifier*: `vrsn.jsonb_table_structure__build`
- *Arguments*: `table_full_name vrsn.entity_fullname_type`
- *Returns*: `jsonb`

##### build_uks
retrieve unique keys (also primary) in a jsonb setting:
- type (pk|uk)
- name and 
- list of fields.

Primary key is always the first occurence
- *Full Identifier*: `vrsn.jsonb_table_structure__build_uks`
- *Arguments*: `table_full_name vrsn.entity_fullname_type`
- *Returns*: `jsonb`

##### build_uks (1)
retrieve unique keys (also primary) in a jsonb setting:
- type (pk|uk)
- name and 
- list of fields.

Primary key is always the first occurence
- *Full Identifier*: `vrsn.jsonb_table_structure__build_uks`
- *Arguments*: `name_of_table text, name_of_schema text DEFAULT 'public'::text`
- *Returns*: `jsonb`

##### get_insert
- *Full Identifier*: `vrsn.jsonb_table_structure__get_insert`
- *Arguments*: `rec hstore, columns_list jsonb`
- *Returns*: `text`

##### get_pk_where
- *Full Identifier*: `vrsn.jsonb_table_structure__get_pk_where`
- *Arguments*: `rec hstore, columns_list jsonb`
- *Returns*: `text`

##### get_pk_where (1)
Wrapper for hstore version
- *Full Identifier*: `vrsn.jsonb_table_structure__get_pk_where`
- *Arguments*: `rec record, columns_list jsonb`
- *Returns*: `text`

##### get_uk_where
- *Full Identifier*: `vrsn.jsonb_table_structure__get_uk_where`
- *Arguments*: `rec hstore, columns_list jsonb, uk_list jsonb, uk_index integer DEFAULT NULL::integer`
- *Returns*: `text`

##### get_update
- *Full Identifier*: `vrsn.jsonb_table_structure__get_update`
- *Arguments*: `rec hstore, columns_list jsonb`
- *Returns*: `text`

### Package: lock

Method Count: 1

#### Private Functions

##### get_advsory
- *Full Identifier*: `vrsn.__lock__get_advsory`
- *Arguments*: `p_table_full_name text, p_table_key text, is_shared boolean DEFAULT false, exception_on_fail boolean DEFAULT true`
- *Returns*: `boolean`

### Package: parameters

Method Count: 3

#### Public Functions

##### get
- *Full Identifier*: `vrsn.parameters__get`
- *Arguments*: `p_context text, p_sub_context text DEFAULT NULL::text`
- *Returns*: `jsonb`

##### get_subset
- *Full Identifier*: `vrsn.parameters__get_subset`
- *Arguments*: `p_context text, p_sub_context text DEFAULT NULL::text, p_search_keys text[] DEFAULT NULL::text[]`
- *Returns*: `jsonb`

##### get_value
- *Full Identifier*: `vrsn.parameters__get_value`
- *Arguments*: `p_context text, p_search_key text, p_sub_context text DEFAULT NULL::text`
- *Returns*: `jsonb`

### Package: table

Method Count: 1

#### Public Functions

##### get_fields_details
- *Full Identifier*: `vrsn.table__get_fields_details`
- *Arguments*: `p_schema_name text, p_table_name text`
- *Returns*: `SETOF vrsn.table_field_details`

### Package: table_field_details

Method Count: 1

#### Private Functions

##### to_jsonb_transfn
- *Full Identifier*: `vrsn.__table_field_details__to_jsonb_transfn`
- *Arguments*: `state jsonb, field_data vrsn.table_field_details`
- *Returns*: `jsonb`

### Package: tar_h

Trigger Activation Record Handler
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



Method Count: 2

#### Private Functions

##### add_changelog
- *Full Identifier*: `vrsn.__tar_h__add_changelog`
- *Arguments*: `tar vrsn.trigger_activation_record_base`
- *Returns*: `void`

##### bind_action
- *Full Identifier*: `vrsn.__tar_h__bind_action`
- *Arguments*: `sqlstr text, hrec hstore`
- *Returns*: `text`

##### build
- *Full Identifier*: `vrsn.__tar_h__build`
- *Arguments*: `entity_full_name vrsn.entity_fullname_type, force_rebuild boolean, argv anycompatiblearray`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### build_actions
- *Full Identifier*: `vrsn.__tar_h__build_actions`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_base`
- *Returns*: `vrsn.trigger_activation_record_base`

##### config_func_build
- *Full Identifier*: `vrsn.__tar_h__config_func_build`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_base`
- *Returns*: `vrsn.trigger_activation_record_base`

##### config_func_init
- *Full Identifier*: `vrsn.__tar_h__config_func_init`
- *Arguments*: ``
- *Returns*: `jsonb`

##### config_func_update
- *Full Identifier*: `vrsn.__tar_h__config_func_update`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_stack`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### constant
- *Full Identifier*: `vrsn.__tar_h__constant`
- *Arguments*: ``
- *Returns*: `text`

##### get_def_behavior
- *Full Identifier*: `vrsn.__tar_h__get_def_behavior`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_base`
- *Returns*: `vrsn.trigger_activation_record_base`

##### handle_attribute_field
- *Full Identifier*: `vrsn.__tar_h__handle_attribute_field`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_stack`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### handle_trigger
- *Full Identifier*: `vrsn.__tar_h__handle_trigger`
- *Arguments*: `entity_full_name vrsn.entity_fullname_type, trigger_operation text, oldrec record, newrec record, argv anycompatiblearray DEFAULT ARRAY[]::text[]`
- *Returns*: `hstore`

##### prepare_record
- *Full Identifier*: `vrsn.__tar_h__prepare_record`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_stack`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### trace
- *Full Identifier*: `vrsn.__tar_h__trace`
- *Arguments*: `tar vrsn.trigger_activation_record_stack_trace_parent`
- *Returns*: `void`

##### user_far_past_handling
- *Full Identifier*: `vrsn.__tar_h__user_far_past_handling`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_stack`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### user_near_past_handling
- *Full Identifier*: `vrsn.__tar_h__user_near_past_handling`
- *Arguments*: `INOUT tar vrsn.trigger_activation_record_stack`
- *Returns*: `vrsn.trigger_activation_record_stack`

#### Public Functions

##### get
- *Full Identifier*: `vrsn.tar_h__get`
- *Arguments*: `entity_full_name vrsn.entity_fullname_type, argv anycompatiblearray DEFAULT ARRAY[]::text[]`
- *Returns*: `vrsn.trigger_activation_record_stack`

##### readme
- *Full Identifier*: `vrsn.tar_h__readme`
- *Arguments*: ``
- *Returns*: `text`

### Package: test

Method Count: 3

#### Public Functions

##### tar_check
Check the result of test
- *Full Identifier*: `vrsn.test__tar_check`
- *Arguments*: `step_number integer, step_description text`
- *Returns*: `boolean`

##### tar_exec
- *Full Identifier*: `vrsn.test__tar_exec`
- *Arguments*: `recreate boolean DEFAULT false`
- *Returns*: `boolean`

##### tar_init
- *Full Identifier*: `vrsn.test__tar_init`
- *Arguments*: ``
- *Returns*: `boolean`

---

### Functions Without Package



Method Count: 3

#### Private Functions

##### get_table_inheritance_ancestors
- *Full Identifier*: `vrsn.__get_table_inheritance_ancestors`
- *Arguments*: `input_schema text, input_table text`
- *Returns*: `TABLE(ancestor_schema text, ancestor_table text, level integer)`

#### Public Functions

##### entity_fullname_type_agg
- *Full Identifier*: `vrsn.entity_fullname_type_agg`
- *Arguments*: `vrsn.entity_fullname_type`
- *Returns*: `vrsn.entity_fullname_type[]`

##### entity_fullname_type_string_agg
- *Full Identifier*: `vrsn.entity_fullname_type_string_agg`
- *Arguments*: `vrsn.entity_fullname_type, text`
- *Returns*: `text`

##### get_resolved_default_value
- *Full Identifier*: `vrsn.get_resolved_default_value`
- *Arguments*: `p_default_value_str text`
- *Returns*: `text`

##### json_schema_ts_formatter
- *Full Identifier*: `vrsn.json_schema_ts_formatter`
- *Arguments*: `ts timestamp with time zone DEFAULT now(), format_to_use text DEFAULT 'data-time'::text`
- *Returns*: `text`

##### table_field_details_to_jts_agg
- *Full Identifier*: `vrsn.table_field_details_to_jts_agg`
- *Arguments*: `vrsn.table_field_details`
- *Returns*: `jsonb`

##### trace_ddl
- *Full Identifier*: `vrsn.trace_ddl`
- *Arguments*: `enable boolean`
- *Returns*: `void`

##### trigger_handler
- *Full Identifier*: `vrsn.trigger_handler`
- *Arguments*: ``
- *Returns*: `trigger`

##### trigger_inhibit_dml
- *Full Identifier*: `vrsn.trigger_inhibit_dml`
- *Arguments*: ``
- *Returns*: `trigger`

---
[main](main.md) - [readme](../README.md)
