USE ChicagoTaxiDW;
GO


CREATE OR ALTER PROCEDURE cfg.usp_CreateRawTable
(
    @SourceTableCode INT
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;


    /* ============================================================
       1. Resolve source table metadata
       ============================================================ */

    DECLARE
        @SourceTableID INT,
        @RawSchemaName SYSNAME,
        @RawTableName SYSNAME,
        @FullTableName NVARCHAR(300);


    SELECT
        @SourceTableID = SourceTableID,
        @RawSchemaName = RawSchemaName,
        @RawTableName = RawTableName
    FROM cfg.SourceTable
    WHERE Code = @SourceTableCode
      AND IsActive = 1;


    IF @SourceTableID IS NULL
    BEGIN
        THROW 50001,
              'Active SourceTable was not found for the supplied Code.',
              1;
    END;


    SET @FullTableName =
        QUOTENAME(@RawSchemaName)
        + '.'
        + QUOTENAME(@RawTableName);


    /* ============================================================
       2. Validate schema
       ============================================================ */

    IF SCHEMA_ID(@RawSchemaName) IS NULL
    BEGIN
        THROW 50002,
              'Configured RAW schema does not exist.',
              1;
    END;


    /* ============================================================
       3. Do not recreate an existing RAW table
       ============================================================ */

    IF OBJECT_ID(
            @RawSchemaName + '.' + @RawTableName,
            'U'
       ) IS NOT NULL
    BEGIN

        PRINT
            'Table '
            + @FullTableName
            + ' already exists. No action was performed.';

        RETURN;

    END;


    /* ============================================================
       4. Validate that column metadata exists
       ============================================================ */

    IF NOT EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1
    )
    BEGIN

        THROW 50003,
              'No active DataDictionary metadata was found for the SourceTable.',
              1;

    END;


    /* ============================================================
       5. Validate variable-length datatypes
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1
          AND SqlDataType IN
              (
                  'VARCHAR',
                  'NVARCHAR',
                  'CHAR',
                  'NCHAR'
              )
          AND DataTypeLength IS NULL
    )
    BEGIN

        THROW 50004,
              'Character datatype requires DataTypeLength.',
              1;

    END;


    /* ============================================================
       CHAR(MAX) and NCHAR(MAX) are not valid SQL Server types.
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1
          AND SqlDataType IN ('CHAR', 'NCHAR')
          AND DataTypeLength = -1
    )
    BEGIN

        THROW 50005,
              'CHAR and NCHAR do not support MAX length.',
              1;

    END;


    /* ============================================================
       6. Validate DECIMAL / NUMERIC
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1
          AND SqlDataType IN ('DECIMAL', 'NUMERIC')
          AND
          (
              DataTypePrecision IS NULL
              OR DataTypeScale IS NULL
          )
    )
    BEGIN

        THROW 50006,
              'DECIMAL and NUMERIC require Precision and Scale.',
              1;

    END;


    /* ============================================================
       7. Protect reserved ETL column names
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1
          AND SourceColumnName IN
              (
                  '__BatchRunID',
                  '__ProcessDate',
                  '__IngestedAtUtc'
              )
    )
    BEGIN

        THROW 50007,
              'Source metadata uses a reserved ETL column name.',
              1;

    END;


    /* ============================================================
       8. Generate column definitions
       ============================================================ */

    DECLARE @ColumnDefinitions NVARCHAR(MAX);


    SELECT
        @ColumnDefinitions =
            STRING_AGG
            (
                CAST
                (
                    '    '
                    + QUOTENAME(SourceColumnName)
                    + ' '
                    +
                    CASE

                        /* ------------------------------------------
                           Character types
                           ------------------------------------------ */

                        WHEN SqlDataType IN
                             (
                                 'VARCHAR',
                                 'NVARCHAR',
                                 'CHAR',
                                 'NCHAR'
                             )
                        THEN
                            SqlDataType
                            + '('
                            +
                            CASE
                                WHEN DataTypeLength = -1
                                    THEN 'MAX'
                                ELSE
                                    CAST(DataTypeLength AS VARCHAR(10))
                            END
                            + ')'


                        /* ------------------------------------------
                           Decimal / Numeric
                           ------------------------------------------ */

                        WHEN SqlDataType IN
                             (
                                 'DECIMAL',
                                 'NUMERIC'
                             )
                        THEN
                            SqlDataType
                            + '('
                            + CAST(
                                DataTypePrecision
                                AS VARCHAR(10)
                              )
                            + ','
                            + CAST(
                                DataTypeScale
                                AS VARCHAR(10)
                              )
                            + ')'


                        /* ------------------------------------------
                           DATETIME2 / TIME with optional precision
                           ------------------------------------------ */

                        WHEN SqlDataType IN
                             (
                                 'DATETIME2',
                                 'TIME'
                             )
                             AND DataTypeScale IS NOT NULL
                        THEN
                            SqlDataType
                            + '('
                            + CAST(
                                DataTypeScale
                                AS VARCHAR(10)
                              )
                            + ')'


                        /* ------------------------------------------
                           Types without additional parameters
                           ------------------------------------------ */

                        ELSE
                            SqlDataType

                    END
                    +
                    CASE
                        WHEN IsNullable = 1
                            THEN ' NULL'
                        ELSE
                            ' NOT NULL'
                    END

                    AS NVARCHAR(MAX)
                ),

                ',' + CHAR(13) + CHAR(10)

            )
            WITHIN GROUP
            (
                ORDER BY OrdinalPosition
            )

    FROM cfg.DataDictionary

    WHERE SourceTableID = @SourceTableID
      AND IsActive = 1;


    /* ============================================================
       9. Generate CREATE TABLE
       ============================================================ */

    DECLARE @Sql NVARCHAR(MAX);


    SET @Sql =
        'CREATE TABLE '
        + @FullTableName
        + CHAR(13) + CHAR(10)
        + '('
        + CHAR(13) + CHAR(10)

        + @ColumnDefinitions

        + ','
        + CHAR(13) + CHAR(10)
        + CHAR(13) + CHAR(10)

        + '    [__BatchRunID] BIGINT NOT NULL,'
        + CHAR(13) + CHAR(10)

        + '    [__ProcessDate] DATE NOT NULL,'
        + CHAR(13) + CHAR(10)

        + '    [__IngestedAtUtc] DATETIME2(0) NOT NULL'
        + ' DEFAULT (SYSUTCDATETIME())'

        + CHAR(13) + CHAR(10)
        + ');';


    /* ============================================================
       10. Show generated SQL
       ============================================================ */

    PRINT @Sql;


    /* ============================================================
       11. Execute generated SQL
       ============================================================ */

    EXEC sys.sp_executesql @Sql;

END;
GO