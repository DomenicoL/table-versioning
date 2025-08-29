# PostgreSQL Bitemporal Solution: Installation and Upgrade Instructions

[main](main.md) - [readme](../README.md)


This document guides you through the process of preparing and installing the bitemporal solution in your PostgreSQL environment.

## Prerequisites

Please ensure you have the following installed:
* **PostgreSQL** (version 11 or higher, developed with __15__)
* **`psql`**: The PostgreSQL command-line client.
* **`python3`**: The Python 3 interpreter.
* **`git`**: To clone the repository.


---

## 1. Preparation

The first step is to run the `prepare.sh` script, which handles the creation of personalized installation scripts and the changelog.


### 1.1.  Create schema and extensions (ONLY THE FIRST TIME)

```sql
create schema if not exists common    authorization __your-db-user__;
create schema if not exists extensions     authorization __your-db-user__;
create schema if not exists srvc     authorization __your-db-user__ -- just for non production environment;
create schema if not exists vrsn     authorization __your-db-user__;

create extension ltree with schema extensions cascade;
create extension btree_gist with schema extensions cascade;
create extension btree_gin with schema extensions cascade;
create extension tablefunc with schema extensions cascade;
create extension hstore with schema extensions cascade;

alter role __your-db-user__ set search_path to "$user", public, extensions;
alter database __your-db__ set search_path to "$user", public, extensions;

```


### 1.2.  Clone the repository and navigate to its directory

```bash
git clone [https://github.com/your-username/bitemporal-postgresql.git](https://github.com/your-username/bitemporal-postgresql.git)
cd bitemporal-postgresql
```
### 1.3.  Prepare the scripts

Run the `prepare.sh` script. You can customize the schema names using the `-c` and `-v` arguments, otherwise you will be prompted interactively.

**Example with default names:**
```bash
./prepare.sh
```

**Example with custom names:**
```bash
./prepare.sh -c my_common -v my_version
```

**What the script does:**
* Generates `install_common.sql` and `install_vrsn.sql` with your chosen schema names.
* Creates or updates the `CHANGELOG.md` file by comparing the new scripts with the ones in the `LAST_INSTALL` folder.

> ⚠️ **Important:** If this is the first run, the script will warn you to create the `LAST_INSTALL` folder. For subsequent runs, **ensure that the `LAST_INSTALL` folder contains the scripts from your previous installation** to get an accurate changelog.

---

## 2. Changelog Review

Before proceeding, it is **highly recommended** to check the `CHANGELOG.md` file to understand what changes will be applied to your database.

* Pay close attention to any objects that have been **removed** (`❌ Removed`), since these actions will have to be done manually (after backup).

---

## 3. Installation/Upgrade
After reviewing the changelog, you can't run the generated SQL files, you must disable check on function's body

### 3.1 Disable check for function's body

Add as first line of the file:

```sql
SET check_function_bodies = off;
```

And at end:

```sql
SET check_function_bodies = on;
```

### 3.2 Execute the sql
Use the `psql` commands to apply the changes to your database.

```bash
# Replace "your_db_name" with the name of your database
psql -v ON_ERROR_STOP=1 -d your_db_name -f install_common.sql
psql -v ON_ERROR_STOP=1 -d your_db_name -f install_vrsn.sql
psql -v ON_ERROR_STOP=1 -d your_db_name -f srvc.sql
```

The -v ON_ERROR_STOP=1 option will stop the installation on the first error, preventing partial schema corruption.
You can also load with your preferred software copying the contains of files.

### 3.3 Execute the sql for entity_fullname_type  (ONLY THE FIRST TIME)
```bash
# Replace "your_db_name" with the name of your database
psql -v ON_ERROR_STOP=1 -d your_db_name -f entity_fullname_type.sql
```


## 4. If installation goes ok

```bash
mkdir -p LAST_INSTALL
cp install_common.sql install_vrsn.sql LAST_INSTALL/
```

---
[main](main.md) - [readme](../README.md)
