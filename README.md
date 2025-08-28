# PostgreSQL Bitemporal Solution

Welcome to the repository for the PostgreSQL bitemporal solution.

This solution provides two schemas for managing bitemporal data:
- **`common`**: Contains contains general utility functions not strictly related to versioning.
- **`vrsn`**: Contains the specific logic for versioning and managing bitemporal tables.

Installation and upgrades are managed through scripts, which allow you to customize schema names and track changes.

---

## Installation and Upgrades

To install or upgrade the solution in your database, please follow the detailed instructions in the [install document](docs/install.md).

---

## Changelog

To see the schema changes across different project versions, refer to the `CHANGELOG.md` file, which is updated automatically.

---

## Documentation

To learn about this solution go to [documentation section](docs/main.md).
