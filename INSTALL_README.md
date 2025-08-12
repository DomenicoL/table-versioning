# Installation and Upgrade Instructions

This document guides you through the process of preparing and installing the bitemporal solution in your PostgreSQL environment.

### Prerequisites

Please ensure you have the following installed:
* **PostgreSQL** (version 11 or higher)
* **`psql`**: The PostgreSQL command-line client.
* **`python3`**: The Python 3 interpreter.
* **`git`**: To clone the repository.

---

### 1. Preparation

The first step is to run the `prepare.sh` script, which handles the creation of personalized installation scripts and the changelog.

1.  **Clone the repository and navigate to its directory:**
    ```bash
    git clone [https://github.com/your-username/bitemporal-postgresql.git](https://github.com/your-username/bitemporal-postgresql.git)
    cd bitemporal-postgresql
    ```
2.  **Prepare the scripts:**
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

### 2. Changelog Review

Before proceeding, it is **highly recommended** to check the `CHANGELOG.md` file to understand what changes will be applied to your database.

* Pay close attention to any objects that have been **removed** (`❌ Removed`), since these actions will have to be done manually (after backup).

---

### 3. Installation/Upgrade

After reviewing the changelog, you can run the generated SQL files. Use the `psql` commands to apply the changes to your database.

```bash
# Replace "your_db_name" with the name of your database
psql -v ON_ERROR_STOP=1 -d your_db_name -f install_common.sql
psql -v ON_ERROR_STOP=1 -d your_db_name -f install_vrsn.sql

The -v ON_ERROR_STOP=1 option will stop the installation on the first error, preventing partial schema corruption.
```

### 4. If installation goes ok

mkdir -p LAST_INSTALL
cp install_common.sql install_vrsn.sql LAST_INSTALL/
