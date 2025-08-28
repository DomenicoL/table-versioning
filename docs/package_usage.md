# PostgreSQL Bitemporal Solution: Package Usage Guide

[main](main.md) - [readme](../README.md)

This document outlines the two primary approaches for integrating and managing your data with the PostgreSQL bitemporal solution: a detailed manual setup, which offers granular control, and an automated method leveraging the `vrsn.bitemporal_entity__register_v2` function for simplified and flexible entity registration.

-----

## Introduction to Package Usage

The `vrsn` package provides a robust framework for bitemporal data management in PostgreSQL, allowing you to track both valid time (`user_ts_range`) and transaction time (`db_ts_range`). Whether you prefer a hands-on approach or a more automated setup, the package supports your needs by standardizing table structures, naming conventions, and trigger management.

-----

## Manual Setup Approach

The manual approach provides full control over the creation of your database objects. This method requires strict adherence to naming conventions and proper trigger setup.

### Step 1: Manual Table and View Creation

You are responsible for creating your entity's tables and its corresponding view.

  * **Current Table:** This table stores the active, valid records. It **must** include a `bt_info` column of type `vrsn.bitemporal_record NOT NULL`.

      * **Naming Convention:** It is **mandatory** to name this table using the format `[entity_name]_current`.
      * **Example:** For an entity named `customer`, the current table would be `customer_current`.

  * **History Table:** This table stores all historical versions of the records from the current table. It should have an identical structure to the current table, including the `bt_info` field.

      * **Naming Convention:** It is **mandatory** to name this table using the format `[entity_name]_history`.
      * **Inheritance (Optional):** You may choose to create the history table by inheriting from the current table for structural consistency, although this is not strictly required by the bitemporal framework itself.
      * **Example:** For an entity named `customer`, the history table would be `customer_history`.

  * **Current View:** This view serves as the primary interface for all Data Manipulation Language (DML) operations (INSERT, UPDATE, DELETE). Users should interact only with this view, never directly with the underlying `_current` or `_history` tables.

      * **Naming Convention:** It is **mandatory** to name this view simply `[entity_name]`.
      * **Example:** For an entity named `customer`, the view would be `customer`.

### Step 2: Trigger Deployment

After creating your tables and view, you must deploy the `INSTEAD OF` trigger on the current view. This trigger intercepts all DML operations and routes them through the bitemporal logic handled by `vrsn.trigger_handler()`.

  * The `vrsn` package provides private functions (`vrsn.bitemporal_entity__get_view_ddl`, `vrsn.bitemporal_entity__get_current_table_ddl`, etc.) that can help you generate the necessary DDL for tables, views, and particularly the trigger. While these are typically used internally by the automated registration, you can inspect them to understand the required trigger definition.
  * The trigger on your `[entity_name]` view will call `vrsn.trigger_handler()`.

### Deductive Management Activation

When performing a manual setup, the bitemporal solution activates its "deductive management" capabilities upon the **first DML call** to your manually configured view. At this point, the `vrsn.trigger_handler()` will:

  * Identify the view and its underlying `_current` and `_history` tables based on the mandatory naming conventions.
  * Internally configure the `vrsn.def_entity_behavior_current` table with default settings for your new entity.
  * Begin applying bitemporal logic to all subsequent DML operations.

-----

## Automated Setup with `vrsn.bitemporal_entity__register_v2`

For a more streamlined and flexible setup, the `vrsn.bitemporal_entity__register_v2` function provides a powerful automated registration mechanism. This is the **recommended approach** for integrating new entities into the bitemporal framework.

```sql
SELECT vrsn.bitemporal_entity__register_v2(
    p_config := '{
        "current_view": {"schema_name": "your_app_schema", "table_name": "your_entity_view_name"},
        -- Or use "current_table" to derive the view name:
        -- "current_table": {"schema_name": "your_app_schema", "table_name": "your_entity_table_current"},
        "historice_entity": "always",
        "enable_history_attributes": true,
        "main_fields_list": "field1,field2",
        "cached_fields_list": "cached_attr_column",
        "mitigate_conflicts": true,
        "print_only": false
    }'::jsonb
);
```

### Flexibility in Naming and Schemas

Unlike the manual approach, `vrsn.bitemporal_entity__register_v2` offers significant flexibility:

  * **Custom Naming:** You can provide custom names for your current table, history table, and attribute tables. The function will use these explicit names.
  * **Schema Separation:** It supports placing tables and views in different schemas, allowing for finer-grained access control and organization of your database objects. You would specify the `schema_name` within each `current_view`, `current_table`, `history_table`, and `attribute_table` JSON sub-object.
  * **Derivation (Default Behavior):** If specific table names (e.g., `history_table.table_name`) are not provided in the `p_config` JSONB, the function will automatically derive them based on the `[entity_name]` derived from `current_view` or `current_table`, using the standard suffixes (`_history`, `_current`, `_attribute`).

### Advanced Features: Attribute Management

`vrsn.bitemporal_entity__register_v2` provides direct control over advanced bitemporal features:

  * **Attribute Replacement (`enable_attribute_to_fields_replacement`):** Set this flag to `true` in `p_config` to enable the dynamic overwriting of scalar entity fields using values from `vrsn.cached_attribute` columns. This allows for a more document-like approach to updating data.
  * **Attribute Archiving with Lineage (`enable_history_attributes`):** Set this flag to `true` in `p_config` to activate attribute-level historicization. This includes the automatic creation of dedicated tables for attribute history and the utilization of `vrsn.attribute_lineage` to track individual attribute identities and their evolution over time. This is ideal for entities with frequently changing or complex sets of attributes.

-----

## Summary of Usage Recommendations

| Feature / Aspect          | Manual Setup                                           | Automated Setup (`vrsn.bitemporal_entity__register_v2`)       | Recommendation                                                                      |
| :------------------------ | :----------------------------------------------------- | :------------------------------------------------------------- | :---------------------------------------------------------------------------------- |
| **Object Creation** | Manual DDL statements                                  | Automated DDL generation and execution                         | **Automated** for speed and consistency.                                            |
| **Naming Conventions** | **Strictly enforced** (`_current`, `_history`, etc.)  | **Flexible** (derives if not specified, but conventions are advised). | **Automated** for flexibility; respect derived names or specify explicitly.           |
| **Schema Flexibility** | Possible with careful manual DDL                       | **Full support** for different schemas                         | **Automated** for multi-schema deployments.                                         |
| **Trigger Management** | Manual trigger creation                                | Automated trigger deployment                                   | **Automated** to prevent errors.                                                    |
| **Attribute Management** | Not directly supported by manual setup; requires custom logic. | **Integrated** (`enable_history_attributes`, `enable_attribute_to_fields_replacement`). | **Automated** for complex attribute scenarios.                                      |
| **Setup Complexity** | High (DDL, triggers, conventions)                      | Low (single `jsonb` function call)                             | **Automated** for ease of use and reduced error surface.                            |
| **Best For** | Very specific, non-standard needs; deep understanding of internals. | **Most use cases**, especially for evolving data models and attribute management.    | **`vrsn.bitemporal_entity__register_v2` is the recommended path for new entities.** |

---
[main](main.md) - [readme](../README.md)
