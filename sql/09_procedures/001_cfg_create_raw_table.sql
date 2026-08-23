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
       1. Resolve SourceTable metadata
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
       2. Validate target RAW schema
       ============================================================ */

    IF SCHEMA_ID(@RawSchemaName) IS NULL
    BEGIN

        THROW 50002,
              'Configured RAW schema does not exist.',
              1;

    END;


    /* ============================================================
       3. Idempotency

       An existing RAW table is not automatically recreated.

       Schema evolution will be handled separately later.
       ============================================================ */

    IF OBJECT_ID
    (
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
       4. Validate DataDictionary existence
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
       5. Validate character datatypes

       VARCHAR / NVARCHAR / CHAR / NCHAR require a length.
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1

          AND RawSqlDataType IN
          (
              'VARCHAR',
              'NVARCHAR',
              'CHAR',
              'NCHAR'
          )

          AND RawDataTypeLength IS NULL
    )
    BEGIN

        THROW 50004,
              'RAW character datatype requires RawDataTypeLength.',
              1;

    END;


    /* ============================================================
       6. CHAR(MAX) / NCHAR(MAX) are invalid
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1

          AND RawSqlDataType IN
          (
              'CHAR',
              'NCHAR'
          )

          AND RawDataTypeLength = -1
    )
    BEGIN

        THROW 50005,
              'CHAR and NCHAR do not support MAX length.',
              1;

    END;


    /* ============================================================
       7. Validate DECIMAL / NUMERIC
       ============================================================ */

    IF EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary
        WHERE SourceTableID = @SourceTableID
          AND IsActive = 1

          AND RawSqlDataType IN
          (
              'DECIMAL',
              'NUMERIC'
          )

          AND
          (
              RawDataTypePrecision IS NULL
              OR RawDataTypeScale IS NULL
          )
    )
    BEGIN

        THROW 50006,
              'RAW DECIMAL and NUMERIC require Precision and Scale.',
              1;

    END;


    /* ============================================================
       8. Protect ETL technical column names

       Source systems cannot use these names because the framework
       owns them.
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
       9. Generate RAW source-column definitions

       IMPORTANT:

       Physical RAW column name = SourceColumnName.

       No business renaming occurs in Bronze.
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

                        WHEN RawSqlDataType IN
                        (
                            'VARCHAR',
                            'NVARCHAR',
                            'CHAR',
                            'NCHAR'
                        )
                        THEN
                            RawSqlDataType
                            + '('
                            +
                            CASE
                                WHEN RawDataTypeLength = -1
                                    THEN 'MAX'

                                ELSE
                                    CAST(
                                        RawDataTypeLength
                                        AS VARCHAR(10)
                                    )
                            END
                            + ')'


                        /* ------------------------------------------
                           Binary types
                           ------------------------------------------ */

                        WHEN RawSqlDataType IN
                        (
                            'BINARY',
                            'VARBINARY'
                        )
                        THEN
                            RawSqlDataType
                            + '('
                            +
                            CASE
                                WHEN RawDataTypeLength = -1
                                    THEN 'MAX'

                                ELSE
                                    CAST(
                                        RawDataTypeLength
                                        AS VARCHAR(10)
                                    )
                            END
                            + ')'


                        /* ------------------------------------------
                           DECIMAL / NUMERIC
                           ------------------------------------------ */

                        WHEN RawSqlDataType IN
                        (
                            'DECIMAL',
                            'NUMERIC'
                        )
                        THEN
                            RawSqlDataType
                            + '('
                            + CAST(
                                RawDataTypePrecision
                                AS VARCHAR(10)
                              )
                            + ','
                            + CAST(
                                RawDataTypeScale
                                AS VARCHAR(10)
                              )
                            + ')'


                        /* ------------------------------------------
                           DATETIME2 / TIME

                           RawDataTypeScale represents fractional
                           seconds precision when supplied.
                           ------------------------------------------ */

                        WHEN RawSqlDataType IN
                        (
                            'DATETIME2',
                            'TIME'
                        )
                        AND RawDataTypeScale IS NOT NULL
                        THEN
                            RawSqlDataType
                            + '('
                            + CAST(
                                RawDataTypeScale
                                AS VARCHAR(10)
                              )
                            + ')'


                        /* ------------------------------------------
                           Types without parameters
                           ------------------------------------------ */

                        ELSE
                            RawSqlDataType

                    END

                    +

                    CASE
                        WHEN RawIsNullable = 1
                            THEN ' NULL'
                        ELSE
                            ' NOT NULL'
                    END

                    AS NVARCHAR(MAX)
                ),

                ','
                + CHAR(13)
                + CHAR(10)
            )

            WITHIN GROUP
            (
                ORDER BY OrdinalPosition
            )

    FROM cfg.DataDictionary

    WHERE SourceTableID = @SourceTableID
      AND IsActive = 1;


    IF @ColumnDefinitions IS NULL
    BEGIN

        THROW 50008,
              'Unable to generate RAW column definitions.',
              1;

    END;


    /* ============================================================
       10. Generate final CREATE TABLE statement
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

        /* --------------------------------------------------------
           Framework-owned technical metadata
           -------------------------------------------------------- */

        + '    [__BatchRunID] BIGINT NOT NULL,'
        + CHAR(13) + CHAR(10)

        + '    [__ProcessDate] DATE NOT NULL,'
        + CHAR(13) + CHAR(10)

        + '    [__IngestedAtUtc] DATETIME2(0) NOT NULL'
        + ' CONSTRAINT '
        + QUOTENAME(
              'DF_'
              + @RawTableName
              + '_IngestedAtUtc'
          )
        + ' DEFAULT (SYSUTCDATETIME())'
        + CHAR(13) + CHAR(10)

        + ');';


    /* ============================================================
       11. Show generated DDL
       ============================================================ */

    PRINT @Sql;


    /* ============================================================
       12. Execute generated DDL
       ============================================================ */

    EXEC sys.sp_executesql @Sql;

END;
GO