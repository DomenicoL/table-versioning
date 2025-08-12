# PostgreSQL Bitemporal Solution: `vrsn.trigger_activation_record_base`
# PostgreSQL Bitemporal Solution: `vrsn.trigger_activation_record_base`

The `vrsn.trigger_activation_record_base` table is a crucial table within the PostgreSQL bitemporal framework. It acts as a **unique session-level context record** that stores the details of the highest-level DML (Data Manipulation Language) operation currently in progress. It serves as a central point for the configuration and state of the trigger handler (`vrsn.trigger_handler()`).

---

### Purpose

The primary purpose of `vrsn.trigger_activation_record_base` is to:

* **Entity Configuration:** Store specific bitemporal entity settings and metadata, such as current and history table names, column lists, and field configurations. This record is built or retrieved at the beginning of a DML operation on a bitemporal view.
* **Operational Context:** Provide quick and consistent access to key information about the active DML operation (e.g., full table names, column lists, unique indexes) to all functions involved in trigger handling.
* **Trigger State:** Contain state variables (`func_state_var`) and parameters (`func_param`) that influence the behavior of the `vrsn.trigger_handler()`, including flags like `versioning_active`, `mitigate_conflicts`, and `enable_attribute_to_fields_replacement`.
* **Information Caching:** As a per-session table (or for on-demand reconstruction), it reduces the need to repeatedly recalculate complex metadata (like table structures and predefined SQL actions) during multiple operations within the same session.

This table is not a "stack" in the traditional sense (for which `vrsn.trigger_activation_record_stack` exists), but rather a **configuration and state register for the current DML context.**

---

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

---

### Interaction and Usage

`vrsn.trigger_activation_record_base` is primarily managed by the `vrsn.__tar_h__build` function, which is called by `vrsn.tar_h__get` (the public function to obtain the activation record).

When a DML operation hits an entity's view:

1.  `vrsn.trigger_handler()` calls `vrsn.tar_h__get`.
2.  `vrsn.tar_h__get` in turn calls `vrsn.__tar_h__build`.
3.  `vrsn.__tar_h__build` checks if a record for the entity already exists in `trigger_activation_record_base` and if it is still valid (not too old, or if a forced rebuild is not requested).
4.  If invalid or not present, `vrsn.__tar_h__build` constructs a new record, populates all fields with entity metadata, configuration parameters, and predefined SQL actions, and then inserts (or updates) it into `vrsn.trigger_activation_record_base`.
5.  This record is then used by `vrsn.__tar_h__handle_trigger` (which receives a copy of `vrsn.trigger_activation_record_stack`, which *inherits* from `vrsn.trigger_activation_record_base`) to execute the appropriate bitemporal logic.

In summary, `vrsn.trigger_activation_record_base` serves as a **centralized cache and configuration source** for the trigger handler, optimizing performance and ensuring consistent behavior for all bitemporal operations on a given entity.

# PostgreSQL Bitemporal Solution: `vrsn.trigger_activation_record_stack`

While `vrsn.trigger_activation_record_base` provides the overarching session-level context for DML operations, `vrsn.trigger_activation_record_stack` functions as the **actual execution stack or call stack** for the bitemporal trigger handler (`vrsn.trigger_handler()`). This table records the details of each nested bitemporal operation, ensuring proper flow control and re-entrancy management during complex data manipulations.

---

### Purpose

The `trigger_activation_record_stack` is crucial because bitemporal operations can sometimes trigger further DML internally (e.g., when moving records to history tables or applying retroactive changes). The stack allows the system to:

* **Manage Nested Operations:** Keep track of the current DML operation and any sub-operations it initiates, creating a hierarchical view of the execution.
* **Prevent Re-entrancy Issues:** Ensure that internal DML operations (e.g., on `_current` or `_history` tables) do not inadvertently re-trigger the main `INSTEAD OF` trigger on the view, which could lead to infinite loops or incorrect data states.
* **Contextual Control:** Provide specific context for each level of the "call" to the trigger handler, allowing for nuanced behavior based on whether the operation is a top-level user DML or an internal system action.
* **DML Inhibition:** Temporarily inhibit (block) direct DML operations on underlying tables (`_current`, `_history`) when the bitemporal logic is actively manipulating them, guaranteeing that all changes flow through the controlled trigger mechanism. This is managed by the `vrsn.trigger_inhibit_dml()` function, which relies on the state in this stack.

Essentially, `vrsn.trigger_activation_record_stack` ensures a disciplined and safe execution environment for bitemporal logic, allowing complex operations to proceed without interfering with the integrity of the data model.

---

### Key Fields

The `vrsn.trigger_activation_record_stack` table typically mirrors many fields from `vrsn.trigger_activation_record_base` but with the critical addition of stack-specific properties like `id` and `activated_by` to build the hierarchy. Its definition, as found in `vrsn.sql`, includes:

* **`id` (`bigint` NOT NULL):** A unique identifier for this specific activation record within the stack. This serves as the primary key.
* **`activated_by` (`bigint`):** A foreign key referencing the `id` of the *parent* activation record on the stack. If this record represents a top-level DML operation initiated by a user, this field will typically be `NULL`. This field is fundamental for reconstructing the call hierarchy.
* **`entity_full_name` (`vrsn.entity_fullname_type`):** The full name of the bitemporal entity (schema and view name) currently being operated on at this level of the stack.
* **`entity_schema` (`text`):** The schema name of the entity.
* **`entity_name` (`text`):** The name of the entity (view name).
* **`action_type` (`text`):** The specific type of DML action being performed at this stack level (e.g., `'INSERT'`, `'UPDATE'`, `'DELETE'`).
* **`target_schema` (`text`):** The schema of the target table (`_current` or `_history`) affected by the DML at this level.
* **`target_name` (`text`):** The name of the target table (`_current` or `_history`).
* **`is_dml_inhibited` (`boolean` NOT NULL):** A flag indicating whether DML operations are inhibited for the current context. When `TRUE`, it means direct DML on underlying tables is blocked, forcing all operations through the trigger handler.
* **`start_ts` (`timestamptz` NOT NULL, DEFAULT `clock_timestamp()`):** The timestamp when this specific activation record was pushed onto the stack.
* **`end_ts` (`timestamptz`):** The timestamp when this activation record was popped from the stack, indicating the completion of the operation it represents. This is `NULL` for active records.
* **`func_param` (`jsonb`):** Parameters passed to the trigger handler for this specific activation, including some configuration overrides from `action_hints` or the field name used to accept user-id.
* **`func_state_var` (`vrsn.tar_state_variables`):** State variables relevant to the execution context of this stack level, such as `versioning_active`, `ignore_unchanged_values`, etc.

The presence of `vrsn.trigger_activation_record_stack` ensures that the bitemporal framework can handle complex, multi-layered data changes with precision, preventing conflicts and maintaining data integrity through a well-defined internal state machine.


# PostgreSQL Bitemporal Solution: `vrsn.tar_state_variables` Type

The `vrsn.tar_state_variables` is a **composite type** that serves as a collection of **boolean "switches"** or flags within the `vrsn.trigger_activation_record_stack`. These flags are crucial for controlling the execution flow and behavior of the `vrsn.trigger_handler()` function during DML operations on bitemporal entities. They are initially set based on the entity's configuration but can change dynamically at runtime due to the specific DML action, detected data changes, or `action_hints` provided by the user.

---

## Fields of `func_state_var implements vrsn.tarstate_variables`

Here are the fields defined within the `vrsn.tar_state_variables` type, along with their purpose in the bitemporal framework:

* **`mitigate_conflicts` (`boolean`):**
    * **Purpose:** If `TRUE`, the system attempts to resolve timestamp conflicts automatically (e.g., by slightly adjusting `user_ts_range` boundaries to avoid overlaps) rather than raising an immediate error. This makes the system more tolerant to potentially conflicting historical data inputs.

* **`ignore_unchanged_values` (`boolean`):**
    * **Purpose:** If `TRUE`, an `UPDATE` operation will not trigger a new historical version (i.e., `versioning_active` might be set to `FALSE` internally) if no significant data fields (excluding internal `bt_info` or audit fields) have actually changed between the `OLD` and `NEW` records. If `FALSE`, even a "touch" without data change might create a new version.

* **`versioning_active` (`boolean`):**
    * **Purpose:** This is the primary control flag for whether a new historical record should be created for the current DML operation. It is initially set by the `historice_entity` behavior defined for the entity (e.g., `'always'`, `'never'`) but can be overridden by `action_hints` (e.g., `"versioning": "off"`).

* **`allow_full_deactivation_by_past_close_ts` (`boolean`):**
    * **Purpose:** If `TRUE`, it permits a logical "close" or deactivation of all existing records for an entity when a `modify_ts` is provided that is earlier than all current historical records. This is used for very deep retroactive corrections where the past state needs to be entirely rewritten or "deactivated."

* **`action_close` (`boolean`):**
    * **Purpose:** `TRUE` if the current `UPDATE` operation is specifically intended to logically close/delete a record (e.g., by setting the `is_closed` field on the view to `TRUE`). This triggers specific logic to end the `user_ts_range` and `db_ts_range` for the record and update its `audit_record`.

* **`action_new` (`boolean`):**
    * **Purpose:** `TRUE` if the current operation is an `INSERT`. This flag guides the trigger handler to perform logic related to creating new active records.

* **`action_mod` (`boolean`):**
    * **Purpose:** `TRUE` if the current operation is an `UPDATE` that is *not* an `action_close`. This indicates a standard modification to an existing record.

* **`deactivate_all` (`boolean`):**
    * **Purpose:** `TRUE` if the current operation (typically due to `allow_full_deactivation_by_past_close_ts`) requires all current records for the entity to be logically deactivated.

* **`found_changed_value` (`boolean`):**
    * **Purpose:** Dynamically set to `TRUE` during the trigger's execution if the `NEW` record has a material difference from the `OLD` record (excluding internal metadata). This flag is crucial when `ignore_unchanged_values` is `TRUE`.

* **`past_time` (`boolean`):**
    * **Purpose:** `TRUE` if the `modify_ts` provided by the user (the intended `user_ts_start` for the new version) falls significantly in the *far past* relative to existing historical records. This triggers complex retroactive handling logic.

* **`near_past_time` (`boolean`):**
    * **Purpose:** `TRUE` if the `modify_ts` is in the *recent past* (e.g., within a configured "near real-time" window, like a few hours or seconds). This is often used for asynchronous bulk updates where the `user_ts_start` might be slightly behind the actual `db_ts_start`.

* **`on_dup_key_update` (`boolean`):**
    * **Purpose:** If `TRUE` during an `INSERT` operation and a record with a duplicate unique key is found, the `INSERT` will be automatically converted into an `UPDATE` operation instead of raising a `unique_violation` error.

* **`on_dup_key_exit` (`boolean`):**
    * **Purpose:** If `TRUE` during an `INSERT` operation and a record with a duplicate unique key is found, the trigger will simply exit without performing any action (neither insert nor update), effectively discarding the incoming row.

* **`ignore_null_on_update` (`boolean`):**
    * **Purpose:** If `TRUE` during an `UPDATE`, `NULL` values in the `NEW` record for non-primary key columns will be ignored, meaning they will not overwrite existing non-NULL values in the database. Only non-NULL values from `NEW` will be applied.

* **`lock_main_table` (`boolean`):**
    * **Purpose:** If `TRUE`, the trigger attempts to acquire a row-level lock on the underlying `_current` table during its operation. This is typically used to prevent concurrent modifications that could lead to race conditions.

* **`enable_version_only_on_main_change` (`boolean`):**
    * **Purpose:** If `TRUE`, a new historical version is only created if there's a change detected in the "main fields" (as defined in `vrsn.def_entity_behavior`). If only non-main fields change, a new version might not be generated even if `versioning_active` is generally `TRUE`.

* **`enable_history_attributes` (`boolean`):**
    * **Purpose:** If `TRUE`, the system will attempt to historicize attributes stored in `vrsn.cached_attribute` columns, creating new versions in a dedicated attribute history table.

* **`enable_attribute_to_fields_replacement` (`boolean`):**
    * **Purpose:** If `TRUE`, the trigger will attempt to "flatten" attributes from a `vrsn.cached_attribute` column (e.g., `many_fields`) directly into scalar fields of the main entity if their keys match column names.

* **`is_ready` (`boolean`):**
    * **Purpose:** A general status flag, often indicating if the `trigger_activation_record` has been fully initialized and is ready for use by the trigger handler.

* **`trace_call_stack` (`boolean`):**
    * **Purpose:** If `TRUE`, enables logging of the internal trigger call stack, which is invaluable for debugging complex bitemporal logic and understanding nested operations.

* **`tar_changelog` (`boolean`):**
    * **Purpose:** If `TRUE`, changes to the `vrsn.trigger_activation_record_base` itself (the session-level configuration) are logged to a changelog table, providing an audit of how entity configurations are managed and updated.

These flags work in concert to provide a highly configurable and robust bitemporal system, allowing administrators to fine-tune behavior for various data management scenarios.

---
