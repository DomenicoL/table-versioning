# PostgreSQL Bitemporal Solution: Action Hints

Action hints provide a powerful mechanism to customize the behavior of the `vrsn.trigger_handler()` function on a per-operation basis. These hints are passed as a `jsonb` object within the `NEW` record of the view being manipulated (e.g., `NEW.action_hints`). The `vrsn.trigger_handler()` will then interpret these hints via the `vrsn.__tar_h__config_func_update` function, overriding default behaviors.

Here are the primary parameterizations available within the `action_hints` JSONB object and their effects:

* **`onDupKey` (`text`):** Controls behavior when an `INSERT` operation encounters an existing record with a conflicting unique key.
    * `"update"`: If a duplicate key is found, the `INSERT` operation will be converted into an `UPDATE` operation on the existing record.
    * `"do nothing"`: If a duplicate key is found, the `INSERT` operation will be ignored, and no action will be performed.
    * *(Default if not specified or unrecognized: Raises a `unique_violation` error)*

* **`versioning` (`text`):** Controls whether versioning is active for the current operation.
    * `"off"`: Disables versioning for the current `INSERT` or `UPDATE` operation, meaning no new history record will be created, and the `db_ts_range` of the `_current` record will not be closed.
    * *(Default if not specified or unrecognized: Versioning remains active as per entity configuration)*

* **`onUnchangedValue` (`text`):** Dictates behavior if an `UPDATE` operation detects no actual changes in the record's data (excluding `bt_info`).
    * `"update"`: Forces an update, even if no values have changed.
    * `"touch"`: Updates only the `touchTs` (touch timestamp) within the `audit_record` of the existing record, without creating a new historical version.
    * `"discard"`: Discards the operation entirely if no changes are detected.
    * *(Default if not specified or unrecognized: Behaves as if `"touch"` is specified)*

* **`onUpdate` (`text`):** Influences how `NULL` values in the `NEW` record are handled during an `UPDATE`.
    * `"ignore nulls"`: `NULL` values in the `NEW` record for fields that are not part of the primary key will be ignored, meaning they will not overwrite existing non-NULL values in the database. Only non-NULL values in the `NEW` record will be applied.
    * *(Default if not specified or unrecognized: `NULL` values in `NEW` record will overwrite existing values)*

* **`allowFullDeactivationByPastCloseTs` (`boolean`):** Used in conjunction with past-dated logical deletions.
    * `true`: Allows an operation (typically a logical deletion or a retroactive correction) to fully deactivate a record even if its `user_ts_range` extends far into the past, affecting all prior history.
    * `false`: Strict behavior, preventing deactivation if it would fully invalidate records far in the past without explicit range definition.
    * *(Default: `false`)*

* **`dbTs` (`timestamptz`):** Allows explicit control over the `db_ts_range` (transaction time) of the record.
    * By providing a timestamp here, you can override the system's `clock_timestamp()` for the `db_ts_range` for the current operation. This is an advanced feature primarily for data migration or specific synchronization scenarios.
    * *(Default: `clock_timestamp()`)*

* **`modify_user_id` (`text`):** While not explicitly part of `action_hints` as an *override*, the `vrsn.trigger_handler()` explicitly checks for this field in the `NEW` record as the source for the `user_id` in the `audit_record`. If not found, an exception is raised. It's the **mandatory** field for user tracking.

* **`modify_ts` (`timestamptz`):** Similar to `modify_user_id`, this field in the `NEW` record is used to set the `user_ts_range` (valid time) of the record. If provided and it's a past date, it triggers the complex temporal deactivation logic described in the main overview.

* **Other Parameters (`extraInfo`):** Any other key-value pairs present in the `action_hints` JSONB that are not recognized by the specific parameters listed above will be collected and stored in the `audit_record` under the `extraInfo` key. This allows for passing custom, application-specific metadata alongside the bitemporal operation without needing to modify the core trigger logic.ac
