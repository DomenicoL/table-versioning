# PostgreSQL Bitemporal Solution: Core Tables

[main](main.md) - [readme](../README.md)

This section details three key tables within the `vrsn` schema that are fundamental to the bitemporal framework's ability to manage entity behavior, track attribute lineage, and map attributes to their respective entities.

---

## `vrsn.attribute_lineage` (View based on `vrsn.attribute_lineage_current`)

This is a **view** that provides the primary interface for managing and querying the lineage of individual attributes within the bitemporal system. It's built on top of the `vrsn.attribute_lineage_current` table, meaning that all DML operations on this view are intercepted by `INSTEAD OF` triggers and processed by the bitemporal handler.

* **Purpose:** The main goal of `attribute_lineage` is to establish and track the unique identity and history of each distinct attribute (e.g., "customer_segment", "product_category") that might be stored across various entities or even in `vrsn.cached_attribute` fields. It serves as a central registry for attribute definitions, allowing the system to understand and manage how specific attribute values evolve over time and across different tables. This ensures consistency and proper historicization of dynamic attribute sets.

* **Key Fields (from `vrsn.attribute_lineage_current`):**

    * **`bt_info` (`vrsn.bitemporal_record`):** The bitemporal information record, including `user_ts_range`, `db_ts_range`, and `audit_record`.
    * **`attribute_id` (`bigint` NOT NULL):** A system-generated unique identifier for the attribute. This is the primary key.
    * **`attribute_name` (`text` NOT NULL):** The logical name of the attribute (e.g., 'color', 'size', 'configuration_option').
    * **`schema_name` (`text`):** The schema name of the entity that this attribute is primarily associated with (can be `NULL` if generic).
    * **`entity_name` (`text`):** The entity name (view name) that this attribute is primarily associated with (can be `NULL` if generic).
    * **`json_schema_plus` (`json`):** (Potentially) A JSON schema defining the expected structure or type of values for this attribute, allowing for validation and richer metadata.

---

## `vrsn.attribute_mapping_to_entity` (View based on `vrsn.attribute_mapping_to_entity_current`)

Similar to `attribute_lineage`, this is a **view** that acts as the DML interface for associating specific attributes (identified by `attribute_id`) with a particular field within a bitemporal entity.

* **Purpose:** This table maps a globally defined `attribute_id` (from `attribute_lineage`) to a specific `field_name` within a given `entity_name` and `schema_name`. It also records the `attribute_type` expected for this specific mapping. This is crucial for enabling the `vrsn.cached_attribute` functionality, where the system needs to know which logical attribute corresponds to which physical column in an entity, and what its data type should be for casting during the overwrite process.

* **Key Fields (from `vrsn.attribute_mapping_to_entity_current`):**

    * **`bt_info` (`vrsn.bitemporal_record`):** The bitemporal information record.
    * **`attribute_id` (`bigint` NOT NULL):** The ID of the attribute, referencing `vrsn.attribute_lineage`. Part of the primary key.
    * **`attribute_name` (`text` NOT NULL):** The logical name of the attribute (redundant with `attribute_id` but useful for readability/queries).
    * **`schema_name` (`text` NOT NULL):** The schema name of the entity this attribute is mapped to. Part of the primary key.
    * **`entity_name` (`text` NOT NULL):** The entity name (view name) this attribute is mapped to. Part of the primary key.
    * **`field_name` (`text` NOT NULL):** The specific column name within the `entity_name` that stores this attribute. Part of the primary key.
    * **`attribute_type` (`text`):** The expected data type of the attribute within this specific field mapping (e.g., `'text'`, `'integer'`, `'jsonb'`). This is used for type casting during attribute overwrites.

---

## `vrsn.def_entity_behavior_current` (Table, underlying `vrsn.def_entity_behavior` view)

This is a **physical table** that stores the core configuration for each bitemporal entity managed by the framework. The `vrsn.def_entity_behavior` view provides a bitemporal interface to this table, allowing its own configuration to be versioned.

* **Purpose:** This table defines the overall bitemporal behavior for each registered entity (view). It controls how historicization occurs, whether attribute handling is enabled, and various other behavioral flags that influence the `vrsn.trigger_handler()`. This centralized configuration allows for flexible and granular control over the bitemporal properties of each data entity.

* **Key Fields:**

    * **`bt_info` (`vrsn.bitemporal_record` NOT NULL):** The bitemporal information record for the configuration itself.
    * **`entity_full_name` (`vrsn.entity_fullname_dmn` NOT NULL):** The full name (schema and table/view name) of the bitemporal entity this configuration applies to. This is the primary key.
    * **`attribute_entity_full_name` (`vrsn.entity_fullname_dmn`):** The full name of the associated attribute entity (view) if `enable_history_attributes` is `TRUE`.
    * **`historice_entity` (`vrsn.historice_entity_behaviour` NOT NULL, DEFAULT `'always'`):** Defines the default historicization behavior:
        * `'always'`: Always create a new version on any detected change.
        * `'never'`: Never create new versions (useful for reference data).
        * `'on_main_fields'`: Only create a new version if fields listed in `main_fields_list` change.
    * **`enable_history_attributes` (`boolean` NOT NULL, DEFAULT `false`):** If `TRUE`, enables the historicization of attributes stored in `vrsn.cached_attribute` fields, utilizing `attribute_lineage` and `attribute_mapping_to_entity`.
    * **`main_fields_list` (`text`):** A comma-separated list of column names. If `historice_entity` is `'on_main_fields'`, only changes to these columns will trigger a new version of the entity.
    * **`cached_fields_list` (`text`):** A comma-separated list of `vrsn.cached_attribute` column names within the entity that should be parsed for attribute overwrites.
    * **`mitigate_conflicts` (`boolean` NOT NULL, DEFAULT `true`):** If `TRUE`, attempts to automatically mitigate timestamp conflicts (e.g., in `user_ts_range`) during updates.
    * **`ignore_unchanged_values` (`boolean` NOT NULL, DEFAULT `true`):** If `TRUE`, an `UPDATE` will not create a new history record if no significant values have changed.
    * **`enable_attribute_to_fields_replacement` (`boolean` NOT NULL, DEFAULT `false`):** If `TRUE`, enables the functionality to overwrite scalar entity fields using values from a `vrsn.cached_attribute` column (as described in a previous document).
    * **`field_special_behavior` (`jsonb`):** (Potentially) A JSONB field for more granular, field-specific behavior configurations that can override general settings.
    
---

[main](main.md) - [readme](../README.md)
