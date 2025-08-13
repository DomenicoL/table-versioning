# PostgreSQL Bitemporal Solution: Attribute versioning

## Attribute Management

When the `enable_history_attributes` flag is set to `TRUE` for an entity, the bitemporal framework activates a powerful mechanism for managing attribute data separately from the main entity table. This feature is particularly useful for entities with complex or dynamic attribute sets often stored in `jsonb` columns.

At the time of entity registration, if `enable_history_attributes` is active, the framework proposes to create a dedicated set of tables and views to store attributes in a normalized key-value format. This attribute history system mirrors the bitemporal structure of the main entity, ensuring that attribute changes are also versioned over time.

-----

 Core Attribute Data Model

The attribute data is managed in a separate bitemporal structure consisting of two tables and a view. The primary key of the current and history attribute tables is a composite key, which includes:

  * The **primary key of the main entity** (`entity_id`).
  * The **attribute's unique ID** (`attribute_id`).
  * An **index** (`idx`), which is used specifically to handle attributes originating from arrays within JSON structures.

This design ensures that each unique attribute value for a given entity can be tracked and historicized individually.

-----

## DML and Historicization of Attributes

When a DML operation is invoked on the main entity's view, the bitemporal trigger analyzes the designated `vrsn.cached_attribute` fields (those defined in `cached_fields_list`) one at a time. The core process is as follows:

1.  **Linearization:** The system first flattens, or linearizes, the complex `jsonb` structure of the `vrsn.cached_attribute` field into a simple key-value structure. For arrays, the `idx` field from the primary key is used to represent the position of the element. This process converts a hierarchical JSON document into a flat, relational format for bitemporal tracking.

2.  **Comparison and Action:** The linearized attributes are then compared with the previous version's attributes. Based on this comparison, the system determines whether to:

      * **INSERT:** Create a new record for a newly added attribute.
      * **UPDATE:** Create a new version of an attribute if its value has changed.
      * **CLOSE:** Logically close a historical record for an attribute that has been removed or modified.

3.  **Attribute Lineage:** During this process, the system interacts with `vrsn.attribute_lineage`. If an attribute name is encountered for the first time, a new record is created in `attribute_lineage`, and a unique `attribute_id` is assigned. Otherwise, the existing `attribute_id` is used. This allows attributes to be globally referenced and managed.

4.  **Attribute Mapping:** Similarly, `vrsn.attribute_mapping_to_entity` is used to track which attributes are utilized in which fields of which tables, ensuring type-safe attribute overwrites and data integrity.

The attributes are, therefore, historicized bitemporally in the same manner as the main entity table.

-----

## Synergy with `cached_attribute` Overwriting

Combining the bitemporal attribute management with the `enable_attribute_to_fields_replacement` feature leads to a powerful and optimized data management scenario:

  * **Document-like Interface:** By activating attribute overwriting, you can update entity attributes by simply passing a payload of `vrsn.cached_attribute` to the view. This provides a flexible, document-like database interface where you pass in the attributes you want to update without needing to specify individual column names in your DML statement.

  * **Optimized Historicization:** When attribute-level historicization is active, you can significantly reduce the overhead on the main entity table. In this scenario, it is often not necessary to historicize the main table on every attribute change. You can set the main entity's behavior to `historice_entity = 'on_main_fields'` or even `'never'`, triggering a new version only when critical, non-attribute-related fields change. This prevents redundant historicization and keeps the main table's history cleaner and more performant.

For details on managing global vs. local attribute definitions, see the [Attribute Maintenance Section](https://www.google.com/search?q=%23attribute-maintenance).
