USE master;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'ChicagoTaxiDW'
)
BEGIN
    EXEC('CREATE DATABASE [ChicagoTaxiDW]');
END;
GO

ALTER DATABASE [ChicagoTaxiDW]
SET RECOVERY SIMPLE
GO

SELECT
    database_id,
    name,
    create_date,
    recovery_model_desc
FROM sys.databases
WHERE name = 'ChicagoTaxiDW';