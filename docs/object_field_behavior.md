# PostgreSQL Bitemporal Solution: Updating Entity Attributes with `cached_attribute`

[main](main.md) - [readme](../README.md)

This section describes a specialized mechanism within the bitemporal framework that allows for **overwriting multiple entity attributes by providing a payload of type `vrsn.cached_attribute`**. This approach offers flexibility for applications that manage dynamic sets of attributes or need a generalized update interface, particularly for fields that might store semi-structured data.

The `vrsn.cached_attribute` is a domain defined as `jsonb` (`CREATE DOMAIN vrsn.cached_attribute AS jsonb;`). This means you provide a `jsonb` object, and the system uses its structure to update corresponding entity attributes. This functionality is processed by the `vrsn.trigger_handler()` when an update operation is performed on the entity's view, provided the feature is enabled for that entity.

---

### Enabling and Disabling Attribute Overwrite

The ability to overwrite attributes via a `vrsn.cached_attribute` column is controlled at the entity level through the `vrsn.def_entity_behavior` table. This behavior is managed by the `enable_attribute_to_fields_replacement` flag.

To **activate** or **deactivate** this feature, you use the `vrsn.bitemporal_entity__change` function, which updates the configuration for a specific entity.

* **Activating the feature:**

    ```sql
    SELECT vrsn.bitemporal_entity__change(
        p_entity_schema                  => 'your_schema_name',
        p_entity_name                    => 'your_entity_view_name', -- The view name, not the _current table
        p_modify_user_id                 => 'your_user_id',
        p_enable_attribute_to_fields_replacement => TRUE
    );
    ```

* **Deactivating the feature:**

    ```sql
    SELECT vrsn.bitemporal_entity__change(
        p_entity_schema                  => 'your_schema_name',
        p_entity_name                    => 'your_entity_view_name',
        p_modify_user_id                 => 'your_user_id',
        p_enable_attribute_to_fields_replacement => FALSE
    );
    ```
    After changing this setting, the `trigger_activation_record_base` for the entity will be rebuilt automatically, or you can force a rebuild if necessary.

---

### How Attribute Overwrite Works

Once `enable_attribute_to_fields_replacement` is set to `TRUE` for an entity, the `vrsn.trigger_handler()` (invoked by the `INSTEAD OF` trigger on your entity's view) will look for specific columns typed as `vrsn.cached_attribute` in the `NEW` record. Let's assume your entity view has a column named `many_fields` of type `vrsn.cached_attribute`.

When this `many_fields` column is provided in an `UPDATE` statement on the view, the trigger handler performs the following:

1.  **Parsing the `vrsn.cached_attribute` (JSONB):** It iterates through the key-value pairs within the provided `vrsn.cached_attribute` object.
2.  **Attribute Matching and Overwrite:** For each key in the `vrsn.cached_attribute` payload, it checks if a corresponding column name exists in the underlying `_current` table of the entity.
3.  **Value Application:** If a match is found and the target column is *not* one of the `cached_attribute` fields themselves (to prevent infinite loops or unintended overwrites of the `cached_attribute` field itself), the value from the `vrsn.cached_attribute` is cast to the appropriate column type and applied to that column in the record being updated. This effectively "overwrites" the existing data in those specific columns.
4.  **Bitemporal Processing:** After applying these attribute overwrites, the standard bitemporal logic (versioning, `db_ts_range` management, `audit_record` updates) proceeds as usual for the modified record.

**Important Note on Deprecation:**
While it was technically possible to influence this behavior or other trigger aspects via `action_hints` in earlier versions or for specific debugging scenarios, using `action_hints` for activating/deactivating the attribute overwrite feature is **deprecated and will likely be removed in future updates**. The `vrsn.bitemporal_entity__change` function is the **canonical and recommended** method for managing this entity-level configuration.

---

### Example Usage (Assuming `many_fields` is a `vrsn.cached_attribute` column on your view)

```sql
-- Example: Updating 'your_entity_view' and overwriting 'field_02', 'somevalue', and 'sometext'
-- by providing values in the 'many_fields' (vrsn.cached_attribute) column.
-- The 'modify_user_id' is mandatory for audit purposes.

UPDATE your_schema_name.your_entity_view
SET
    -- You can still update other columns directly
    some_other_scalar_field = 'new_scalar_value',
    -- Provide the vrsn.cached_attribute payload for attribute overwrites
    -- The keys in this JSONB will attempt to overwrite corresponding columns in the entity.
    many_fields = '{
        "field_02": 4,
        "somevalue": 32,
        "sometext": "new text from cached_attribute"
    }'::vrsn.cached_attribute,
    -- Mandatory audit fields
    modify_user_id = 'your_application_user_id',
    modify_ts = '2025-08-12 10:30:00+00' -- Or `clock_timestamp()` for current time
WHERE entity_id = 123;
```


---
[main](main.md) - [readme](../README.md)
