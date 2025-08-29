
-- ========================================
-- CAST DA/PER UNKNOWN (necessario per literal stringa)
-- NON POSSIBILE
-- ========================================

-- ========================================
-- DROP CAST IF EXIST
-- ========================================
DROP CAST IF EXISTS (text AS vrsn.entity_fullname_type);
DROP CAST IF EXISTS (vrsn.entity_fullname_type as text);
DROP CAST IF EXISTS  (hstore AS vrsn.entity_fullname_type);
DROP CAST IF EXISTS  (vrsn.entity_fullname_type AS hstore);
DROP CAST IF EXISTS  (json AS vrsn.entity_fullname_type);
DROP CAST IF EXISTS  (vrsn.entity_fullname_type AS json);
DROP CAST IF EXISTS  (vrsn.entity_fullname_type AS json);
DROP CAST IF EXISTS  (jsonb AS vrsn.entity_fullname_type);
DROP CAST IF EXISTS  (vrsn.entity_fullname_type AS jsonb);

-- ========================================
-- CAST DA/PER text IMPLICIT
-- ========================================

CREATE CAST (text AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_string(text)
AS IMPLICIT;

CREATE CAST (vrsn.entity_fullname_type as text)
WITH FUNCTION vrsn.__entity_fullname_type__to_string(vrsn.entity_fullname_type)
AS IMPLICIT;
-- ========================================
-- CAST DA/PER HSTORE
-- ========================================

-- Cast da hstore
CREATE CAST (hstore AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_hstore(hstore)
AS ASSIGNMENT;

-- Cast verso hstore
CREATE CAST (vrsn.entity_fullname_type AS hstore)
WITH FUNCTION vrsn.__entity_fullname_type__to_hstore(vrsn.entity_fullname_type)
AS ASSIGNMENT;

-- ========================================
-- CAST DA/PER JSON/b
-- ========================================
-- Cast da json
CREATE CAST (json AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_json(json)
AS ASSIGNMENT;

-- Cast verso json
CREATE CAST (vrsn.entity_fullname_type AS json)
WITH FUNCTION vrsn.__entity_fullname_type__to_json(vrsn.entity_fullname_type)
AS ASSIGNMENT;


-- Cast da jsonb
CREATE CAST (jsonb AS vrsn.entity_fullname_type)
WITH FUNCTION vrsn.__entity_fullname_type__from_jsonb(jsonb)
AS ASSIGNMENT;

-- Cast verso jsonb
CREATE CAST (vrsn.entity_fullname_type AS jsonb)
WITH FUNCTION vrsn.__entity_fullname_type__to_jsonb(vrsn.entity_fullname_type)
AS ASSIGNMENT;


-- ========================================
-- Operatori di confronto
-- ========================================

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

