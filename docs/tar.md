# PostgreSQL Bitemporal Solution: trigger activation record (tar)

[main](main.md) - [readme](../README.md)

-----

## vrsn.trigger_activation_record_base

The `vrsn.trigger_activation_record_base` table is a crucial table within the PostgreSQL bitemporal framework. It acts as a **unique session-level context record** that stores the details of the highest-level DML (Data Manipulation Language) operation currently in progress. It serves as a central point for the configuration and state of the trigger handler (`vrsn.trigger_handler()`).

-----

### Purpose

The primary purpose of `vrsn.trigger_activation_record_base` is to:

  * **Entity Configuration:** Store specific bitemporal entity settings and metadata, such as current and history table names, column lists, and field configurations. This record is built or retrieved at the beginning of a DML operation on a bitemporal view.
  * **Operational Context:** Provide quick and consistent access to key information about the active DML operation (e.g., full table names, column lists, unique indexes) to all functions involved in trigger handling.
  * **Trigger State:** Contain state variables (`func_state_var`) and parameters (`func_param`) that influence the behavior of the `vrsn.trigger_handler()`, including flags like `versioning_active`, `mitigate_conflicts`, and `enable_attribute_to_fields_replacement`.
  * **Information Caching:** As a per-session table (or for on-demand reconstruction), it reduces the need to repeatedly recalculate complex metadata (like table structures and predefined SQL actions) during multiple operations within the same session.

This table is not a "stack" in the traditional sense (for which `vrsn.trigger_activation_record_stack` exists), but rather a **configuration and state register for the current DML context.**

-----

### Key Fields

Based on the definition found in `vrsn.sql`, here are the primary fields of the `vrsn.trigger_activation_record_base` table:

  * **`last_update_ts` (`timestamp with time zone`, DEFAULT `now()`):** The last time this configuration record was updated. Used by `vrsn.__tar_h__build` to determine if the record needs to be rebuilt (e.g., if it's too old, or if a forced rebuild is requested).
  * **`entity_full_name` (`vrsn.entity_fullname_type` NOT NULL):** The full name of the bitemporal entity (schema and view name) to which this activation record refers. It is the primary key of the table.
  * **`current_view_full_name` (`vrsn.entity_fullname_type`):** The full name of the view representing the bitemporal entity.
  * **`current_table_full_name` (`vrsn.entity_fullname_type`):** The full name of the underlying `_current` table associated with the entity.
  * **`history_table_full_name` (`vrsn.entity_fullname_type`):** The full name of the `_history` table associated with the entity.
  * **`attribute_entity_full_name` (`vrsn.entity_fullname_type`):** The full name of the attribute entity (if enabled).
  * **`current_entity_columns_list` (`jsonb`):** A JSONB object describing the column structure of the `_current` table (names, types, if PK, etc.).
  * **`history_entity_columns_list` (`jsonb`):** A JSONB object describing the column structure of the `_history` table.
  * **`unique_index_list` (`jsonb`):** A JSONB object listing the unique indexes (including the primary key) of the `_current` table.
  * **`history_attributes_info` (`jsonb`):** Contains information related to attribute historicization, including `main_fields_list` and `cached_fields_list`.
  * **`bt_info_name` (`text` NOT NULL, DEFAULT `'bt_info'`):** The name of the `vrsn.bitemporal_record` type column in the entity table.
  * **`func_state_var` (`vrsn.tar_state_variables`):** A composite type that stores various boolean state flags controlling the trigger's behavior (e.g., `versioning_active`, `ignore_unchanged_values`, `found_changed_value`).
  * **`func_param` (`jsonb`):** A JSONB object for trigger configuration parameters, often derived from `vrsn.parameters__get_list` and `action_hints`.
  * **`actions` (`extensions.hstore`):** An hstore that contains precompiled SQL fragments for different DML operations (INSERT, UPDATE, DELETE) on current and history data. These fragments are dynamic and are "bound" with actual values at execution time.
  * **`table_old_rec` (`extensions.hstore`):** An hstore representation of the record **before** the modification, enriched with all table fields.
  * **`table_new_rec` (`extensions.hstore`):** An hstore representation of the record **after** the modification, enriched with all table fields.

-----

### Interaction and Usage

`vrsn.trigger_activation_record_base` is primarily managed by the `vrsn.__tar_h__build` function, which is called by `vrsn.tar_h__get` (the public function to obtain the activation record).

When a DML operation hits an entity's view:

1.  `vrsn.trigger_handler()` calls `vrsn.tar_h__get`.
2.  `vrsn.tar_h__get` in turn calls `vrsn.__tar_h__build`.
3.  `vrsn.__tar_h__build` checks if a record for the entity already exists in `trigger_activation_record_base` and if it is still valid (not too old, or if a forced rebuild is requested).
4.  If invalid or not present, `vrsn.__tar_h__build` constructs a new record, populates all fields with entity metadata, configuration parameters, and predefined SQL actions, and then inserts (or updates) it into `vrsn.trigger_activation_record_base`.
5.  This record is then used by `vrsn.__tar_h__handle_trigger` (which receives a copy of `vrsn.trigger_activation_record_stack`, which *inherits* from `vrsn.trigger_activation_record_base`) to execute the appropriate bitemporal logic.

In summary, `vrsn.trigger_activation_record_base` serves as a **centralized cache and configuration source** for the trigger handler, optimizing performance and ensuring consistent behavior for all bitemporal operations on a given entity.

-----

## `vrsn.trigger_activation_record_stack`

While `vrsn.trigger_activation_record_base` provides the overarching session-level context for DML operations, `vrsn.trigger_activation_record_stack` functions as the **actual execution stack or call stack** for the bitemporal trigger handler (`vrsn.trigger_handler()`). This table records the details of each nested bitemporal operation, ensuring proper flow control and re-entrancy management during complex data manipulations.

-----

### Purpose

The `trigger_activation_record_stack` is crucial because bitemporal operations can sometimes trigger further DML internally (e.g., when moving records to history tables or applying retroactive changes). The stack allows the system to:

  * **Manage Nested Operations:** Keep track of the current DML operation and any sub-operations it initiates, creating a hierarchical view of the execution.
  * **Prevent Re-entrancy Issues:** Ensure that internal DML operations (e.g., on `_current` or `_history` tables) do not inadvertently re-trigger the main `INSTEAD OF` trigger on the view, which could lead to infinite loops or incorrect data states.
  * **Contextual Control:** Provide specific context for each level of the "call" to the trigger handler, allowing for nuanced behavior based on whether the operation is a top-level user DML or an internal system action.
  * **DML Inhibition:** Temporarily inhibit (block) direct DML operations on underlying tables (`_current`, `_history`) when the bitemporal logic is actively manipulating them, guaranteeing that all changes flow through the controlled trigger mechanism. This is managed by the `vrsn.trigger_inhibit_dml()` function, which relies on the state in this stack.

Essentially, `vrsn.trigger_activation_record_stack` ensures a disciplined and safe execution environment for bitemporal logic, allowing complex operations to proceed without interfering with the integrity of the data model.

-----

### Key Fields

The `vrsn.trigger_activation_record_stack` table **inherits from `vrsn.trigger_activation_record_base`**, meaning it includes all the fields described in the `vrsn.trigger_activation_record_base` section. In addition, it defines the following fields specific to its role as a call stack:

  * **`bt_info` (`vrsn.bitemporal_record`):** The `vrsn.bitemporal_record` from the `OLD` record of the current DML operation being processed by the trigger.
  * **`bt_info_old` (`vrsn.bitemporal_record`):** A derived `vrsn.bitemporal_record` for the `OLD` record, typically with its `user_ts_range` and `db_ts_range` explicitly closed at the point of the modification, prepared for insertion into the history table.
  * **`bt_info_new` (`vrsn.bitemporal_record`):** A derived `vrsn.bitemporal_record` for the `NEW` record, with its `user_ts_range` and `db_ts_range` typically starting at the `new_valid_ts` and `time_stamp_to_use` respectively, extending to infinity.
  * **`time_stamp_to_use` (`timestamp with time zone`):** The database transaction timestamp to be used for the `db_ts_range` (usually `clock_timestamp()` when the trigger fires).
  * **`new_valid_ts` (`timestamp with time zone`):** The user-provided or derived valid-time timestamp to be used for the `user_ts_range`. This often comes from a `modify_ts` field in the `NEW` record.
  * **`wrkn_new_rec` (`extensions.hstore`):** A working copy of the `NEW` record's fields as an hstore, potentially modified by the trigger logic before being applied to the underlying table.
  * **`wrkn_old_rec` (`extensions.hstore`):** A working copy of the `OLD` record's fields as an hstore, used for comparison and historicization.
  * **`status` (`jsonb` DEFAULT `'{}'::jsonb NOT NULL`):** A JSONB field for storing internal status flags and temporary data during the trigger's execution.

-----

## `vrsn.tar_state_variables` Type

The `func_state_var` field within `vrsn.trigger_activation_record_base` and `vrsn.trigger_activation_record_stack` is of type **`vrsn.tar_state_variables`**, a composite type that contains a series of **boolean "switches" or flags** and other values that control the execution flow and behavior of the `vrsn.trigger_handler()` function during DML operations on bitemporal entities. These flags are initially set based on the entity's configuration but can change dynamically at runtime due to the specific DML action, detected data changes, or `action_hints` provided by the user.

-----

### Definition of `vrsn.tar_state_variables`

```sql
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
```

-----

### Explanation of Key Flags

#### mitigate_conflicts

If `TRUE`, the system attempts to resolve timestamp conflicts automatically (e.g., by slightly adjusting `user_ts_range` boundaries to avoid overlaps) rather than raising an immediate error. This makes the system more tolerant of potentially conflicting historical data inputs.

#### ignore_unchanged_values

If `TRUE`, an `UPDATE` operation will not trigger a new historical version (i.e., `versioning_active` might be set internally to `FALSE`) if no significant data fields (excluding internal `bt_info` or audit fields) have actually changed between the `OLD` and `NEW` records. If `FALSE`, even a "touch" without data change might create a new version.

#### versioning_active

This is the primary control flag for whether a new historical record should be created for the current DML operation. It's initially set by the `historice_entity` behavior defined for the entity (e.g., `'always'`, `'never'`) but can be overridden by `action_hints` (e.g., `"versioning": "off"`).

#### allow_full_deactivation_by_past_close_ts

If `TRUE`, it permits a logical "close" or deactivation of all existing records for an entity when a `modify_ts` is provided that precedes all current historical records. This is used for very deep retroactive corrections where the past state needs to be entirely rewritten or "deactivated."

#### action_close

`TRUE` if the current `UPDATE` operation is specifically intended to logically close/delete a record (e.g., by setting the `is_closed` field on the view to `TRUE`). This triggers specific logic to end the `user_ts_range` and `db_ts_range` for the record and update its `audit_record`.

#### action_new

`TRUE` if the current operation is an `INSERT`. This flag guides the trigger handler to perform logic related to creating new active records.

#### action_mod

`TRUE` if the current operation is an `UPDATE` that is *not* an `action_close`. This indicates a standard modification to an existing record.

#### deactivate_all

If `TRUE`, all records related to the entity are deactivated.

#### found_changed_value

Dynamically set to `TRUE` during the trigger's execution if the `NEW` record has a material difference from the `OLD` record (excluding internal metadata). This flag is crucial when `ignore_unchanged_values` is `TRUE`.

#### past_time

`TRUE` if the `new_valid_ts` provided by the user (the intended `user_ts_start` for the new version) falls significantly in the **far past** relative to existing historical records. This triggers complex retroactive handling logic.

#### near_past_time

`TRUE` if the `new_valid_ts` is in the **recent past** (e.g., within a configurable "near past" window, like a few hours or seconds). This is often used for asynchronous bulk updates where the `user_ts_start` might be slightly behind the actual `db_ts_start`.

#### near_real_time

It isn't an actual flag, but if the **recent past** is very near to current time (e.g., within a configurable "near real-time" window, few seconds), the framework use this timestamp as acceptable as it is the current timestamp.


#### on_dup_key_update

If `TRUE` during an `INSERT` operation and a record with a duplicate unique key is found, the `INSERT` will be automatically converted into an `UPDATE` operation instead of raising a `unique_violation` error.

#### on_dup_key_exit

If `TRUE` during an `INSERT` operation and a record with a duplicate unique key is found, the trigger will simply exit without performing any action (neither insert nor update), effectively discarding the incoming row.

#### ignore_null_on_update

If `TRUE` during an `UPDATE`, `NULL` values in the fields provided in the `NEW` record for non-primary key columns will be ignored, meaning they will not overwrite existing non-NULL values in the database. Only non-NULL values from the `NEW` record will be applied.

#### lock_main_table

If `TRUE`, the trigger attempts to acquire a row-level lock on the underlying `_current` table during its operation. This is typically used to prevent concurrent modifications that could lead to race conditions.

#### enable_version_only_on_main_change

If `TRUE`, a new historical version is only created if there's a change detected in the "main fields" (as defined in `vrsn.def_entity_behavior`). If only non-main fields change, a new version might not be generated even if `versioning_active` is generally `TRUE`.

#### enable_history_attributes

If `TRUE`, the system will attempt to historicize attributes stored in `vrsn.cached_attribute` columns, creating new versions in a dedicated attribute history table.

#### enable_attribute_to_fields_replacement

If `TRUE`, the trigger will attempt to "flatten" attributes from a `vrsn.cached_attribute` column (e.g., `many_fields`) directly into scalar fields of the main entity if their keys match column names.

#### is_ready

This flag is crucial and indicates whether the record being processed (`NEW` record) is considered in a "ready" or "final" state for versioning.

  * **`is_ready = TRUE`**: The record is complete and valid for bitemporal versioning. Changes will be historicized.
  * **`is_ready = FALSE`**: The record is in a "draft" or "temporary" state. In this case, bitemporal versioning (the creation of historical records) **will not make sense** and will be deactivated for this specific operation. This prevents creating historical records for intermediate or non-final data states.

#### trace_call_stack

If `TRUE`, enables logging of the internal trigger call stack, which is invaluable for debugging complex bitemporal logic and understanding nested operations.

#### tar_changelog

If `TRUE`, changes to the `vrsn.trigger_activation_record_base` itself (the session-level configuration) are logged to a changelog table, providing an audit of how entity configurations are managed and updated.

These flags work in concert to provide a highly configurable and robust bitemporal system, allowing administrators to fine-tune behavior for various data management scenarios.

---
[main](main.md) - [readme](../README.md)
