-- ========================================
-- CAST DA/PER UNKNOWN (necessario per literal stringa)
-- ========================================

-- Il cast da text dovrebbe essere IMPLICIT per gestire unknown
-- Modifichiamo il cast esistente per essere IMPLICIT
DROP CAST IF EXISTS (text AS vrsn.entity_fullname_type);
CREATE CAST (text AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_string(text)
AS IMPLICIT;

-- ========================================
-- CAST DA/PER HSTORE
-- ========================================

-- Funzione per convertire da hstore a entity_fullname_type
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__from_hstore(hs hstore)
RETURNS vrsn.entity_fullname_type
LANGUAGE plpgsql
AS $body$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF hs IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(hs->'schema_name', hs->'schema', 'public');
    result.table_name := COALESCE(hs->'table_name', hs->'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in hstore';
    END IF;
    
    RETURN result;
END;
$body$;

-- Funzione per convertire da entity_fullname_type a hstore
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__to_hstore(st vrsn.entity_fullname_type)
RETURNS hstore
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::hstore
        ELSE hstore(ARRAY['schema_name', 'table_name'], 
                   ARRAY[COALESCE(st.schema_name, 'public'), COALESCE(st.table_name, '')])
    END;
$body$;

-- Cast da hstore
CREATE CAST (hstore AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_hstore(hstore)
AS ASSIGNMENT;

-- Cast verso hstore
CREATE CAST (vrsn.entity_fullname_type AS hstore)
WITH FUNCTION vrsn.__entity_fullname_type__to_hstore(vrsn.entity_fullname_type)
AS ASSIGNMENT;

-- ========================================
-- CAST DA/PER JSON
-- ========================================

-- Funzione per convertire da json a entity_fullname_type
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__from_json(js json)
RETURNS vrsn.entity_fullname_type
LANGUAGE plpgsql
AS $body$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF js IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(js->>'schema_name', js->>'schema', 'public');
    result.table_name := COALESCE(js->>'table_name', js->>'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in JSON';
    END IF;
    
    RETURN result;
END;
$body$;

-- Funzione per convertire da entity_fullname_type a json
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__to_json(st vrsn.entity_fullname_type)
RETURNS json
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::json
        ELSE json_build_object(
            'schema_name', COALESCE(st.schema_name, 'public'),
            'table_name', COALESCE(st.table_name, '')
        )
    END;
$body$;

-- Cast da json
CREATE CAST (json AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_json(json)
AS ASSIGNMENT;

-- Cast verso json
CREATE CAST (vrsn.entity_fullname_type AS json)
WITH FUNCTION vrsn.__entity_fullname_type__to_json(vrsn.entity_fullname_type)
AS ASSIGNMENT;

-- ========================================
-- CAST DA/PER JSONB
-- ========================================

-- Funzione per convertire da jsonb a entity_fullname_type
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__from_jsonb(js jsonb)
RETURNS vrsn.entity_fullname_type
LANGUAGE plpgsql
AS $body$
DECLARE
    result vrsn.entity_fullname_type;
BEGIN
    IF js IS NULL THEN
        RETURN NULL;
    END IF;
    
    result.schema_name := COALESCE(js->>'schema_name', js->>'schema', 'public');
    result.table_name := COALESCE(js->>'table_name', js->>'table');
    
    IF result.table_name IS NULL THEN
        RAISE EXCEPTION 'Missing table_name in JSONB';
    END IF;
    
    RETURN result;
END;
$body$;

-- Funzione per convertire da entity_fullname_type a jsonb
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__to_jsonb(st vrsn.entity_fullname_type)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN st IS NULL THEN NULL::jsonb
        ELSE jsonb_build_object(
            'schema_name', COALESCE(st.schema_name, 'public'),
            'table_name', COALESCE(st.table_name, '')
        )
    END;
$body$;

-- Cast da jsonb
CREATE CAST (jsonb AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_jsonb(jsonb)
AS ASSIGNMENT;

-- Cast verso jsonb
CREATE CAST (vrsn.entity_fullname_type AS jsonb)
WITH FUNCTION vrsn.__entity_fullname_type__to_jsonb(vrsn.entity_fullname_type)
AS ASSIGNMENT;

-- ========================================
-- OPERATORI DI CONFRONTO
-- ========================================

-- Funzione di confronto per uguaglianza
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__eq(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT COALESCE(a.schema_name, 'public') = COALESCE(b.schema_name, 'public')
       AND COALESCE(a.table_name, '') = COALESCE(b.table_name, '');
$body$;

-- Funzione di confronto per disuguaglianza
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__ne(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT NOT vrsn.__entity_fullname_type__eq(a, b);
$body$;

-- Funzione di confronto per btree
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__cmp(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN (COALESCE(a.schema_name, 'public') || '.' || COALESCE(a.table_name, '')) < 
             (COALESCE(b.schema_name, 'public') || '.' || COALESCE(b.table_name, '')) THEN -1
        WHEN (COALESCE(a.schema_name, 'public') || '.' || COALESCE(a.table_name, '')) > 
             (COALESCE(b.schema_name, 'public') || '.' || COALESCE(b.table_name, '')) THEN 1
        ELSE 0
    END;
$body$;

-- Funzioni per operatori di confronto
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__lt(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) < 0;
$body$;

CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__le(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) <= 0;
$body$;

CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__gt(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) > 0;
$body$;

CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__ge(a vrsn.entity_fullname_type, b vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT vrsn.__entity_fullname_type__cmp(a, b) >= 0;
$body$;

-- Operatori di confronto
CREATE OPERATOR = (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__eq,
    COMMUTATOR = =,
    NEGATOR = <>,
    RESTRICT = eqsel,
    JOIN = eqjoinsel,
    HASHES,
    MERGES
);

CREATE OPERATOR <> (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__ne,
    COMMUTATOR = <>,
    NEGATOR = =,
    RESTRICT = neqsel,
    JOIN = neqjoinsel
);

CREATE OPERATOR < (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__lt,
    COMMUTATOR = >,
    NEGATOR = >=,
    RESTRICT = scalarltsel,
    JOIN = scalarltjoinsel
);

CREATE OPERATOR <= (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__le,
    COMMUTATOR = >=,
    NEGATOR = >,
    RESTRICT = scalarlesel,
    JOIN = scalarlejoinsel
);

CREATE OPERATOR > (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__gt,
    COMMUTATOR = <,
    NEGATOR = <=,
    RESTRICT = scalargtsel,
    JOIN = scalargtjoinsel
);

CREATE OPERATOR >= (
    LEFTARG = vrsn.entity_fullname_type,
    RIGHTARG = vrsn.entity_fullname_type,
    FUNCTION = vrsn.__entity_fullname_type__ge,
    COMMUTATOR = <=,
    NEGATOR = <,
    RESTRICT = scalargesel,
    JOIN = scalargejoinsel
);

-- ========================================
-- FUNZIONI DI HASH E SERIALIZZAZIONE
-- ========================================

-- Funzione hash per supportare indici hash
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__hash(st vrsn.entity_fullname_type)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT hashtext(COALESCE(st.schema_name, 'public') || '.' || COALESCE(st.table_name, ''));
$body$;

-- ========================================
-- NOTA: Funzioni di serializzazione omesse
-- ========================================
-- Le funzioni send/recv richiedono il tipo 'internal' che può essere
-- gestito solo da funzioni scritte in C. PostgreSQL userà automaticamente
-- le funzioni di serializzazione del tipo text grazie ai cast impliciti.

-- ========================================
-- NOTA: Operator class omesse (richiedono superuser)
-- ========================================
-- Le operator class per hash e btree richiedono privilegi di superuser.
-- PostgreSQL userà automaticamente le funzioni di confronto definite
-- per gli operatori quando necessario. Gli indici funzioneranno comunque
-- anche senza operator class esplicite.

-- ========================================
-- SUPPORTO AGGREGAZIONE
-- ========================================

-- Funzione di transizione per array_agg personalizzato
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__array_agg_transfn(
    state vrsn.entity_fullname_type[], 
    elem vrsn.entity_fullname_type
)
RETURNS vrsn.entity_fullname_type[]
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN state IS NULL THEN ARRAY[elem]
        ELSE state || elem
    END;
$body$;

-- Funzione finale per array_agg
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__array_agg_finalfn(state vrsn.entity_fullname_type[])
RETURNS vrsn.entity_fullname_type[]
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT COALESCE(state, ARRAY[]::vrsn.entity_fullname_type[]);
$body$;

-- Aggregato personalizzato per entity_fullname_type
CREATE AGGREGATE vrsn.entity_fullname_type_agg(vrsn.entity_fullname_type) (
    SFUNC = vrsn.__entity_fullname_type__array_agg_transfn,
    STYPE = vrsn.entity_fullname_type[],
    FINALFUNC = vrsn.__entity_fullname_type__array_agg_finalfn,
    INITCOND = '{}'
);

-- Funzione per string_agg delle entity
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__string_agg_transfn(
    state text, 
    elem vrsn.entity_fullname_type,
    delimiter text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT CASE 
        WHEN state IS NULL OR state = '' THEN elem::text
        ELSE state || delimiter || elem::text
    END;
$body$;

-- String aggregato per entity_fullname_type
CREATE AGGREGATE vrsn.entity_fullname_type_string_agg(vrsn.entity_fullname_type, text) (
    SFUNC = vrsn.__entity_fullname_type__string_agg_transfn,
    STYPE = text,
    INITCOND = ''
);

-- ========================================
-- FUNZIONI DI VALIDAZIONE
-- ========================================

-- Validazione più robusta
CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__validate(st vrsn.entity_fullname_type)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $body$
    SELECT st.schema_name ~ '^[a-zA-Z_][a-zA-Z0-9_]*$' 
       AND st.table_name ~ '^[a-zA-Z_][a-zA-Z0-9_]*$';
$body$;

-- Dominio con constraint
CREATE DOMAIN vrsn.valid_entity_fullname AS vrsn.entity_fullname_type
CHECK (vrsn.__entity_fullname_type__validate(VALUE));

-- ========================================
-- FUNZIONE DI TEST ESTESA
-- ========================================

CREATE OR REPLACE FUNCTION vrsn.__entity_fullname_type__test_extended()
RETURNS void
LANGUAGE plpgsql
AS $body$
DECLARE
    myVar vrsn.entity_fullname_type;
    myVar2 vrsn.entity_fullname_type;
    hs hstore;
    js json;
    jsb jsonb;
    result_array vrsn.entity_fullname_type[];
    result_string text;
BEGIN
    -- Test cast da literal stringa (ora dovrebbe funzionare)
    myVar := 'inventory.products';
    RAISE NOTICE 'Da literal stringa: %', myVar;
    
    -- Test cast da hstore
    hs := 'schema_name=>sales, table_name=>orders';
    myVar := hs::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da hstore: %', myVar;
    
    -- Test cast verso hstore
    hs := myVar::hstore;
    RAISE NOTICE 'Verso hstore: %', hs;
    
    -- Test cast da json
    js := '{"schema_name": "logs", "table_name": "access_log"}';
    myVar := js::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da JSON: %', myVar;
    
    -- Test cast verso json
    js := myVar::json;
    RAISE NOTICE 'Verso JSON: %', js;
    
    -- Test cast da jsonb
    jsb := '{"schema": "public", "table": "users"}';
    myVar := jsb::vrsn.entity_fullname_type;
    RAISE NOTICE 'Da JSONB: %', myVar;
    
    -- Test cast verso jsonb
    jsb := myVar::jsonb;
    RAISE NOTICE 'Verso JSONB: %', jsb;
    
    -- Test operatori di confronto
    myVar2 := 'public.users';
    RAISE NOTICE 'Confronto uguaglianza: % = % -> %', myVar, myVar2, myVar = myVar2;
    RAISE NOTICE 'Confronto ordinamento: % < % -> %', myVar, myVar2, myVar < myVar2;
    
    -- Test aggregazione (simulazione)
    result_array := ARRAY[myVar, myVar2];
    RAISE NOTICE 'Array aggregato: %', result_array;
    
    -- Test validazione
    RAISE NOTICE 'Validazione: %', vrsn.__entity_fullname_type__validate(myVar);
    
END;
$body$;

-- ========================================
-- ESEMPI DI UTILIZZO
-- ========================================

-- Esempio di utilizzo completo:
/*
-- Test della funzione
SELECT vrsn.__entity_fullname_type__test_extended();

-- Ora questi dovrebbero funzionare:
DECLARE
    myVar vrsn.entity_fullname_type;
BEGIN
    -- Assegnazione da literal stringa
    myVar := 'public.users';
    
    -- Conversioni
    myVar := '{"schema_name": "inventory", "table_name": "products"}'::json;
    myVar := 'schema_name=>logs, table_name=>access_log'::hstore;
    
    -- Confronti
    IF myVar = 'public.users' THEN
        RAISE NOTICE 'Uguali!';
    END IF;
END;

-- Uso di aggregati
SELECT vrsn.entity_fullname_type_string_agg(column_name, ', ')
FROM (VALUES 
    ('public.users'::vrsn.entity_fullname_type),
    ('inventory.products'::vrsn.entity_fullname_type)
) AS t(column_name);

-- Indici (funzioneranno anche senza operator class esplicite)
CREATE TABLE test_table (
    id serial PRIMARY KEY,
    entity_ref vrsn.entity_fullname_type
);

-- PostgreSQL userà automaticamente le funzioni di confronto degli operatori
CREATE INDEX idx_entity_ref_btree ON test_table USING btree (entity_ref);
-- Gli indici hash potrebbero non funzionare senza operator class specifica
-- CREATE INDEX idx_entity_ref_hash ON test_table USING hash (entity_ref);
*/
