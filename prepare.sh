#!/bin/bash

# --- Configurazione e Variabili ---
# Nomi dei file sorgente con i placeholder
SOURCE_COMMON_SQL="common.sql"
SOURCE_VRSN_SQL="vrsn.sql"
# Nomi dei file utente da generare
COMMON_INSTALL_SQL="install_common.sql"
VRSN_INSTALL_SQL="install_vrsn.sql"
# Directory per i file della precedente installazione
LAST_INSTALL_DIR="LAST_INSTALL"

# --- Funzioni ---
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

# --- Richiesta interattiva se non passati da linea di comando ---
if [ -z "$COMMON_SCHEMA" ]; then
    read -p "Inserisci il nome per lo schema 'common' [common]: " COMMON_SCHEMA
    COMMON_SCHEMA=${COMMON_SCHEMA:-"common"}
fi
if [ -z "$VRSN_SCHEMA" ]; then
    read -p "Inserisci il nome per lo schema 'vrsn' [vrsn]: " VRSN_SCHEMA
    VRSN_SCHEMA=${VRSN_SCHEMA:-"vrsn"}
fi

# --- Preparazione dei file ---
echo "--- Preparazione degli script di installazione ---"
# Sostituzione dei placeholder e creazione dei file di installazione
sed "s/__SCHEMA_COMMON__/${COMMON_SCHEMA}/g" "$SOURCE_COMMON_SQL" > "$COMMON_INSTALL_SQL"
sed "s/__SCHEMA_VRSN__/${VRSN_SCHEMA}/g" "$SOURCE_VRSN_SQL" > "$VRSN_INSTALL_SQL"
echo "Creati i file: $COMMON_INSTALL_SQL e $VRSN_INSTALL_SQL"

# --- Confronto e Changelog ---
echo "--- Confronto degli schemi ---"
# Verifica l'esistenza della cartella LAST_INSTALL e istruzioni per l'utente
if [ ! -d "$LAST_INSTALL_DIR" ]; then
    echo "⚠️ Avviso: La cartella '$LAST_INSTALL_DIR' non esiste."
    echo "Per un confronto affidabile, posiziona gli ultimi script installati qui."
    mkdir -p "$LAST_INSTALL_DIR"
fi

# Esegui lo script Python per il confronto e la generazione del changelog
python3 compare_schemas.py \
    --source-common "$SOURCE_COMMON_SQL" \
    --source-vrsn "$SOURCE_VRSN_SQL" \
    --last-install-dir "$LAST_INSTALL_DIR"

# Aggiungi un messaggio informativo per il prossimo passo
echo "--- Prossimi passi ---"
echo "1. I file '$COMMON_INSTALL_SQL', '$VRSN_INSTALL_SQL' e 'CHANGELOG.md' sono pronti."
echo "2. Suggeriamo di leggere 'CHANGELOG.md' e prestare particolare attenzione alle rimozioni (❌)."
echo "3. Procedi con l'installazione manuale usando i file generati."
echo "4. A installazione completata, copia i file '$COMMON_INSTALL_SQL' e '$VRSN_INSTALL_SQL' in '$LAST_INSTALL_DIR' per le prossime esecuzioni."
echo "   Esempio: cp $COMMON_INSTALL_SQL $VRSN_INSTALL_SQL $LAST_INSTALL_DIR/"
