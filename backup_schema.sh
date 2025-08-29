#!/bin/bash

# Configurazione
DB_USER="btmp"
DB_NAME="bitemporal"     # <-- sostituisci con il tuo utente
OUTPUT_DIR="."   # cartella di destinazione

# Schemi da esportare
SCHEMAS=("vrsn" "common" "srvc")

# Ciclo sugli schemi
for schema in "${SCHEMAS[@]}"; do
    echo "Esporto schema: $schema"
    
    TMP_FILE="$OUTPUT_DIR/${schema}_tmp.sql"
    OUT_FILE="$OUTPUT_DIR/${schema}.sql"

    
    
    pg_dump "postgres://$DB_USER@localhost/$DB_NAME" \
    	--format=p \
        --schema="$schema" \
        --schema-only \
        --encoding=UTF8 \
        --no-owner \
        --no-tablespaces \
        --section=pre-data \
        --section=post-data \
        -f "$TMP_FILE"

    if [ $? -eq 0 ]; then
       {
       		echo "-- Disable check on function's body"
            echo "SET check_function_bodies = off;"
            echo
            cat "$TMP_FILE"
            echo
            echo "SET check_function_bodies = on;"
        } > "$OUT_FILE"

        echo "✔ Dump creato: $OUT_FILE"
    else
        echo "❌ Errore nel dump dello schema $schema"
    fi
    rm "$TMP_FILE"
done

