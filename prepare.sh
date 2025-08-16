#!/bin/bash

# --- File e directory di configurazione ---
SOURCE_COMMON_SQL="common.sql"
SOURCE_VRSN_SQL="vrsn.sql"

# Nuovi nomi per i file generati localmente
COMMON_INSTALL_SQL="LOCAL_INSTALL_common.sql"
VRSN_INSTALL_SQL="LOCAL_INSTALL_vrsn.sql"
LOCAL_CHANGELOG_FILE="LOCAL_INSTALL_CHANGELOG.md" # Nuovo nome per il changelog locale

LAST_INSTALL_DIR="LAST_INSTALL"

# --- Funzioni di utilità ---
function display_help() {
    echo "Utilizzo: $0 [-c <schema_common>] [-v <schema_vrsn>]"
    echo "  -c, --common <schema_name>  Nome per lo schema 'common'. Default: common"
    echo "  -v, --vrsn <schema_name>    Nome per lo schema 'vrsn'. Default: vrsn"
    exit 0
}

# --- Gestione dei parametri da linea di comando ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -c|--common) COMMON_SCHEMA="$2"; shift ;;
        -v|--vrsn) VRSN_SCHEMA="$2"; shift ;;
        -h|--help) display_help ;;
        *) echo "Parametro non valido: $1"; exit 1 ;;
    esac
    shift
done

# --- Richiesta interattiva se i parametri non sono stati passati ---
if [ -z "$COMMON_SCHEMA" ]; then
    read -p "Inserisci il nome per lo schema 'common' [common]: " COMMON_SCHEMA
    COMMON_SCHEMA=${COMMON_SCHEMA:-"common"}
fi
if [ -z "$VRSN_SCHEMA" ]; then
    read -p "Inserisci il nome per lo schema 'vrsn' [vrsn]: " VRSN_SCHEMA
    VRSN_SCHEMA=${VRSN_SCHEMA:-"vrsn"}
fi

# --- Logica principale ---
echo "--- Preparazione degli script di installazione ---"
echo "Nomi schema scelti: common -> $COMMON_SCHEMA, vrsn -> $VRSN_SCHEMA"

if [ ! -f "$SOURCE_COMMON_SQL" ] || [ ! -f "$SOURCE_VRSN_SQL" ]; then
    echo "Errore: File sorgente '$SOURCE_COMMON_SQL' o '$SOURCE_VRSN_SQL' non trovati."
    echo "Assicurati di essere nella directory root del progetto."
    exit 1
fi

# Sostituzione dei placeholder nei file originali e creazione dei nuovi file prefissati
sed "s/__SCHEMA_COMMON__/${COMMON_SCHEMA}/g" "$SOURCE_COMMON_SQL" > "$COMMON_INSTALL_SQL"
sed "s/__SCHEMA_VRSN__/${VRSN_SCHEMA}/g" "$SOURCE_VRSN_SQL" > "$VRSN_INSTALL_SQL"

echo "✅ Creati i file di installazione personalizzati: '$COMMON_INSTALL_SQL' e '$VRSN_INSTALL_SQL'."

echo "--- Generazione del changelog locale ---"
if [ ! -d "$LAST_INSTALL_DIR" ]; then
    echo "⚠️ Attenzione: La directory '$LAST_INSTALL_DIR' non esiste. Il changelog completo non può essere generato."
    mkdir -p "$LAST_INSTALL_DIR"
fi

# Chiamata allo script Python per la generazione del changelog locale
python3 compare_schemas.py --mode local --last-install-dir "$LAST_INSTALL_DIR"

echo "--- Prossimi passi ---"
echo "1. Un changelog specifico per questo aggiornamento è stato salvato in '$LOCAL_CHANGELOG_FILE'."
echo "2. Rivedi '$LOCAL_CHANGELOG_FILE' per comprendere le modifiche prima di procedere con l'installazione, prestando molta attenzione alle rimozioni (❌)."
echo "3. Esegui i file di installazione usando psql."
echo "   Esempio: psql -d tuo_nome_db -f $COMMON_INSTALL_SQL"
echo "            psql -d tuo_nome_db -f $VRSN_INSTALL_SQL"
echo "4. Dopo un'installazione riuscita, copia i *file di installazione generati* nella directory '$LAST_INSTALL_DIR' per i futuri confronti."
echo "   Esempio: cp $COMMON_INSTALL_SQL $LAST_INSTALL_DIR/"
echo "            cp $VRSN_INSTALL_SQL $LAST_INSTALL_DIR/"
