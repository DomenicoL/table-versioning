#!/bin/bash

# --- File e directory di configurazione ---
SOURCE_COMMON_SQL="common.sql"
SOURCE_VRSN_SQL="vrsn.sql"
COMMON_INSTALL_SQL="install_common.sql"
VRSN_INSTALL_SQL="install_vrsn.sql"
LAST_INSTALL_DIR="LAST_INSTALL"

# --- Funzioni di utilità ---
function display_help() {
    echo "Usage: $0 [-c <schema_common>] [-v <schema_vrsn>]"
    echo "  -c, --common <schema_name>  Name for the 'common' schema. Default: common"
    echo "  -v, --vrsn <schema_name>    Name for the 'vrsn' schema. Default: vrsn"
    exit 0
}

# --- Gestione dei parametri da linea di comando ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -c|--common) COMMON_SCHEMA="$2"; shift ;;
        -v|--vrsn) VRSN_SCHEMA="$2"; shift ;;
        -h|--help) display_help ;;
        *) echo "Invalid parameter: $1"; exit 1 ;;
    esac
    shift
done

# --- Richiesta interattiva se i parametri non sono stati passati ---
if [ -z "$COMMON_SCHEMA" ]; then
    read -p "Enter the name for the 'common' schema [common]: " COMMON_SCHEMA
    COMMON_SCHEMA=${COMMON_SCHEMA:-"common"}
fi
if [ -z "$VRSN_SCHEMA" ]; then
    read -p "Enter the name for the 'vrsn' schema [vrsn]: " VRSN_SCHEMA
    VRSN_SCHEMA=${VRSN_SCHEMA:-"vrsn"}
fi

# --- Logica principale ---
echo "--- Preparing installation scripts ---"
echo "Chosen schema names: common -> $COMMON_SCHEMA, vrsn -> $VRSN_SCHEMA"

if [ ! -f "$SOURCE_COMMON_SQL" ] || [ ! -f "$SOURCE_VRSN_SQL" ]; then
    echo "Error: Source files '$SOURCE_COMMON_SQL' or '$SOURCE_VRSN_SQL' not found."
    echo "Please ensure you are in the project's root directory."
    exit 1
fi

# Sostituzione dei placeholder
sed "s/__SCHEMA_COMMON__/${COMMON_SCHEMA}/g" "$SOURCE_COMMON_SQL" > "$COMMON_INSTALL_SQL"
sed "s/__SCHEMA_VRSN__/${VRSN_SCHEMA}/g" "$SOURCE_VRSN_SQL" > "$VRSN_INSTALL_SQL"

echo "✅ Created personalized installation files: '$COMMON_INSTALL_SQL' and '$VRSN_INSTALL_SQL'."

echo "--- Generating local changelog ---"
if [ ! -d "$LAST_INSTALL_DIR" ]; then
    echo "⚠️ Warning: The '$LAST_INSTALL_DIR' directory does not exist. A full changelog cannot be generated."
    mkdir -p "$LAST_INSTALL_DIR"
fi

python3 compare_schemas.py local --last-install-dir "$LAST_INSTALL_DIR"

echo "--- Next steps ---"
echo "1. A specific changelog for this update has been saved to 'CHANGELOG_generated.md'."
echo "2. Review 'CHANGELOG_generated.md' to understand the changes before proceeding with installation, paying close attention to removals (❌)."
echo "3. Run the installation files using psql."
echo "   Example: psql -d your_db_name -f $COMMON_INSTALL_SQL"
echo "            psql -d your_db_name -f $VRSN_INSTALL_SQL"
echo "4. After a successful installation, copy the generated files to the '$LAST_INSTALL_DIR' directory for future comparisons."
echo "   Example: cp $COMMON_INSTALL_SQL $VRSN_INSTALL_SQL $LAST_INSTALL_DIR/"
