USE ChicagoTaxiDW;
GO

/* ============================================================
    Technical schemas
    ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'cfg'
)
BEGIN
    EXEC('CREATE SCHEMA [cfg] AUTHORIZATION [dbo]');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'ctr'
)
BEGIN 
    EXEC('CREATE SCHEMA [ctr] AUTHORIZATION [dbo]');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'adt'
)
BEGIN 
    EXEC('CREATE SCHEMA [adt] AUTHORIZATION [dbo]');
END;
GO


/* ============================================================
   Data architecture schemas
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'raw'
)
BEGIN 
    EXEC('CREATE SCHEMA [raw] AUTHORIZATION [dbo]');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'ods'
)
BEGIN 
    EXEC('CREATE SCHEMA [ods] AUTHORIZATION [dbo]');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'edw'
)
BEGIN 
    EXEC('CREATE SCHEMA [edw] AUTHORIZATION [dbo]');
END;
GO

-- IF NOT EXISTS (
--     SELECT 1
--     FROM sys.schemas
--     WHERE name = 'dm'
-- )
-- BEGIN 
--     EXEC('CREATE SCHEMA [dm] AUTHORIZATION [dbo]');
-- END;
-- GO

SELECT
    name AS SchemaName,
    schema_id AS SchemaID
FROM sys.schemas
WHERE name IN (
    'cfg',
    'ctr',
    'adt',
    'raw',
    'ods',
    'edw',
    'dm'
)
ORDER BY schema_id;


