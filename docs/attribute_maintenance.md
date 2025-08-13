# PostgreSQL Bitemporal Solution: Attribute maintenance

[main](main.md) - [readme](../README.md)

The `vrsn` schema includes several `admin` prefixed functions and views designed to simplify common management tasks for bitemporal entities and attributes. These functions act as convenient wrappers for more complex underlying `vrsn` operations.
-----

## `vrsn.admin__init`

This function is designed to **initialize or reset** the bitemporal framework's core tables, often used for testing or setting up a fresh environment.


  * **Purpose**: This function is primarily used for **setup and testing**. It truncates (empties) various bitemporal core tables and then re-inserts initial configuration data, effectively resetting the bitemporal state to a clean baseline.
  * **Parameters**:
      * `only_get_query`: (`boolean`) If `TRUE`, the function returns the SQL script as a text string without executing it. If `FALSE`, it executes the SQL script directly.
  * **Usage**: Be cautious when using this function, as it will **delete all data** from the specified bitemporal tables. It's intended for development, testing, or initial deployment scenarios where a complete reset is desired.
  
-----

## `vrsn.admin__entity_register`

This function is a wrapper for `vrsn.bitemporal_entity__register`, used to set up a new table or view for bitemporal management.


  * **Purpose**: Simplifies the process of configuring a table or view as a bitemporal entity, including generating necessary history tables and views, and defining its initial bitemporal behavior.
  * **Parameters**:
      * `table_schema`: The schema of the table/view to register.
      * `table_name`: The name of the table/view to register.
      * `historice_entity`: (`vrsn.historice_entity_behaviour`) Default historicization behavior for the new entity.
      * `enable_history_attributes`: (`boolean`) If `TRUE`, enables attribute historicization for this entity.
      * `main_fields_list`: (`text`) Comma-separated list of main fields.
      * `cached_fields_list`: (`text`) Comma-separated list of `vrsn.cached_attribute` fields.
      * `print_only`: (`boolean`) If `TRUE`, the function returns the DDL statements as text without executing them.


-----

## `vrsn.admin__entity_change_behavior`

This function allows you to modify the bitemporal behavior settings of an **already registered entity**. It's a wrapper around `vrsn.bitemporal_entity__change`.

  * **Purpose**: Provides a user-friendly interface to update settings like how an entity is historicized (`historice_entity`), whether attribute history is enabled, which fields are considered "main" for versioning, and other conflict resolution flags.
  * **Parameters**:
      * `p_entity_schema`: The schema of the entity view.
      * `p_entity_name`: The name of the entity view.
      * `p_modify_user_id`: The ID of the user performing the change (for audit purposes).
      * `p_historice_entity`: (`vrsn.historice_entity_behaviour`) Defines the historicization strategy (`'always'`, `'never'`, `'on_main_fields'`).
      * `p_enable_history_attributes`: (`boolean`) Enables or disables attribute-level historicization.
      * `p_main_fields_list`: (`text`) Comma-separated list of fields that, if changed, always trigger a new version when `historice_entity` is `'on_main_fields'`.
      * `p_cached_fields_list`: (`text`) Comma-separated list of `vrsn.cached_attribute` fields to be managed as attributes.
      * `p_mitigate_conflicts`: (`boolean`) If `TRUE`, attempts to auto-resolve timestamp conflicts.
      * `p_ignore_unchanged_values`: (`boolean`) If `TRUE`, an update won't create a new history record if no significant values changed.
      * `p_enable_attribute_to_fields_replacement`: (`boolean`) If `TRUE`, enables overwriting scalar fields from `cached_attribute` content.
  * **Caution**: This function works alse if there are data alreday inserted but doesn't armonize these inforamtion with new parameters.


-----

## `vrsn.admin__insert_global_attribute`

This function inserts a new **global attribute** into the `vrsn.attribute_lineage` table. Global attributes are those not tied to a specific schema or entity, making them universally usable.

  * **Purpose**: To register an attribute as a "global" concept within the bitemporal framework. This attribute can then be mapped to various entities and fields across different schemas.
  * **Parameters**:
      * `p_attribute_name`: (`text`) The unique name of the global attribute.
      * `p_modify_user_id`: (`text`) The user ID performing the operation.
      * `p_json_schema_plus`: (`jsonb`, optional) An optional JSON schema to describe the attribute's expected structure or data type.
  * **Returns**: `bigint` - The `attribute_id` of the newly created global attribute.
  * **Caution**: Normally new global attributes are inserted automatically.
-----

## `vrsn.admin__insert_local_attribute`

This function inserts a new **local attribute** into the `vrsn.attribute_lineage` table, associating it with a specific entity (view).

  * **Purpose**: To register an attribute that is specific or particularly relevant to a given entity (view). This allows for attributes that might have the same name but different meanings or contexts across various entities.
  * **Parameters**:
      * `p_attribute_name`: (`text`) The name of the local attribute.
      * `p_schema_name`: (`text`) The schema of the entity (view) this attribute is associated with.
      * `p_entity_name`: (`text`) The name of the entity (view) this attribute is associated with.
      * `p_modify_user_id`: (`text`) The user ID performing the operation.
      * `p_json_schema_plus`: (`jsonb`, optional) An optional JSON schema for the attribute.
  * **Returns**: `bigint` - The `attribute_id` of the newly created local attribute.
  * **Caution**: use this function if you really want to create local attributes to an entity.

-----

## `vrsn.admin__reserve_attribute`

This function **reserves an existing attribute ID** for use with a specific entity. This is particularly useful if you have a pre-existing `attribute_id` from a global attribute and want to explicitly link it to a new entity, preventing other entities from "claiming" it.

  * **Purpose**: To explicitly assign an `attribute_id` from `vrsn.attribute_lineage` to a specific entity (`schema_name.entity_name`), ensuring that this attribute is primarily managed by or associated with that entity. This prevents unexpected behavior where the same `attribute_id` might be inadvertently mapped differently.
  * **Parameters**:
      * `p_attribute_id`: (`bigint`) The ID of the attribute to reserve.
      * `p_schema_name`: (`text`) The schema of the entity view.
      * `p_entity_name`: (`text`) The name of the entity view.
      * `p_modify_user_id`: (`text`) The user ID performing the operation.
  * **Returns**: `bigint` - The `attribute_id` if the reservation is successful. Raises an exception if the attribute ID doesn't exist, the entity is invalid, or the attribute is already used by a *different* entity.

-----

## `vrsn.admin__attribute_defintion_and_usage` (View)

This is a **view** that provides a comprehensive overview of all attributes defined in `vrsn.attribute_lineage` and their mappings to entities via `vrsn.attribute_mapping_to_entity`.

  * **Purpose**: To provide a consolidated view of all attributes, indicating whether they are "global" (not tied to a specific entity) or "local" (tied to a specific schema.entity). It also shows the `json_schema_plus` for each attribute and, crucially, a `jsonb` representation (`attribute_mapping_json`) detailing which fields within which entities each attribute is mapped to. This view is invaluable for understanding the overall attribute landscape and debugging mapping issues.
  * **Key Columns**:
      * `attribute_id`: Unique identifier for the attribute.
      * `attribute_name`: The logical name of the attribute.
      * `attribute_scope`: Indicates `'global'` or the `schema.entity` if local.
      * `json_schema_plus`: The optional JSON schema for the attribute.
      * `attribute_mapping_json`: A JSONB object showing how this attribute is mapped to specific fields across different schemas/entities.

---
[main](main.md) - [readme](../README.md
