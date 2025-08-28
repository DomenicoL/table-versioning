# PostgreSQL Bitemporal Solution: The Audit Record

[main](main.md) - [readme](../README.md)

The `audit_record` is a critical `jsonb` field nestled within the `vrsn.bitemporal_record` composite type. Its primary function is to store essential traceability and auditing metadata for every modification made to a bitemporal entity. This record ensures that you can always ascertain who (or what process) made a change, when it occurred, and often, why.

-----

## Mandatory `modify_user_id`

Every DML operation that passes through the bitemporal trigger handler requires a **`modify_user_id`**. This field, typically provided in the `NEW` record of the view, is extracted and stored within the `audit_record`'s JSONB structure. It's the core identifier for tracking responsibility for data changes.

-----

## Attributing Changes to Automated Processes

Not all data modifications are directly performed by a human user. Many updates come from automated systems, batch jobs, or asynchronous processes. To correctly distinguish these, the framework allows for a special convention:

  * **Process Identification:** For updates driven by non-human actors, the `modify_user_id` should be set using the format: **`process:_process_name_`**.
      * **Example:** `modify_user_id = 'process:data_import_batch'` or `modify_user_id = 'process:async_evaluation_engine'`.
        This clearly indicates that the change originated from an automated system rather than a direct user interaction.

-----

## Complex Scenarios: User-Initiated Automated Processes

Some common scenarios introduce complexity in attributing changes, especially when a human user initiates an automated process. The key is to distinguish between **direct responsibility** for the data change and **causation** of an automated workflow.

1.  **Synchronous User-Driven Process:**

      * **Scenario:** A user clicks a button that immediately triggers a backend process, completing within the same session. The user is actively waiting for the result.
      * **Attribution:** In this case, it's appropriate to set `modify_user_id` to the **actual user's ID**. The user is fully responsible for directly initiating and observing the outcome of the change.

2.  **Asynchronous User-Initiated Process (Delayed Execution):**

      * **Scenario:** A user triggers a process (e.g., a complex report generation, a large data transformation) that runs in the background, potentially with long delays. The user might not even be logged in when the data is finally modified.
      * **Attribution:** It becomes less accurate to record the user as the direct modifier. Instead, `modify_user_id` should be set to the **process ID** (e.g., `'process:report_generator'`). The system managing the asynchronous task is the direct actor.

3.  **Automated Decision-Making Process:**

      * **Scenario:** A user configures an automated system (e.g., an AI-driven valuation engine, a rule-based anomaly detection system) that then "makes decisions" or applies changes to data autonomously, without immediate user intervention for each change.
      * **Attribution:** Recording the initiating user as the modifier for every subsequent change by the automated system is incorrect. Here, `modify_user_id` should clearly be the **process ID** (e.g., `'process:valuation_engine'`).

-----

## Leveraging `extra_info` for Comprehensive Traceability

For scenarios involving asynchronous or automated processes initiated by a user, it's highly recommended to use the `extra_info` field within the `audit_record`.

  * **`extra_info` (`jsonb`):** This sub-field in the `audit_record` (which can be populated via `action_hints` or directly by the trigger handler) is a generic `jsonb` object where you can store additional, application-specific metadata.

  * **Recommended Practice:**
    When `modify_user_id` is set to a `process:_process_name_`, you should include the **initiating user's identifier** within `extra_info`. This maintains the full chain of causality:

    ```json
    {
        "modify_user_id": "process:async_data_worker",        
        "extra_info": {
            "invoked_by_user_id": "user_12345",
            "source_event_id": "uuid_of_original_event",
            "invocation_ts": "2025-08-28 10:30:00+00",
            "task_id": "async_task_789"
        }
    }
    ```

    This approach accurately traces the direct modifier (`process:async_data_worker`) while also linking back to the human who ultimately invoked the chain of events (`user_12345`), providing a complete audit trail.

-----

## Summary of Audit Record Best Practices

  * **`modify_user_id` is Mandatory:** Always provide it.
  * **Use `process:_name_` for Automation:** Clearly identify automated actors.
  * **User for Direct Responsibility:** If a user directly triggers an immediate, synchronous change.
  * **`extra_info` for Causality:** For user-initiated asynchronous/automated processes, use `extra_info` to store the invoking user's ID and other relevant context (e.g., original event ID, task ID).
  * **Avoid Ambiguity:** Ensure `modify_user_id` accurately reflects the *direct agent* of the database change.

---
[main](main.md) - [readme](../README.md)
