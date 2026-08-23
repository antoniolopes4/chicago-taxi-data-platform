USE ChicagoTaxiDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    /* ============================================================
       Resolve COMMUNITY_AREAS

       Code is the stable functional identifier.
       SourceTableID is the local surrogate key.
       ============================================================ */

    DECLARE @SourceTableID INT;

    SELECT
        @SourceTableID = SourceTableID
    FROM cfg.SourceTable
    WHERE Code = 1002
      AND TechnicalName = 'COMMUNITY_AREAS'
      AND IsActive = 1;


    IF @SourceTableID IS NULL
    BEGIN
        THROW 50001,
              'Active SourceTable COMMUNITY_AREAS (Code 1002) was not found.',
              1;
    END;


    /* ============================================================
       Desired Data Dictionary state

       SourceDataType:
           Datatype declared by the source.

       SourceIsNullable:
           NULL = source does not provide/guarantee nullability
                  information that we want to enforce here.

       RawSqlDataType:
           Tolerant physical SQL Server datatype used in Bronze.

       RawIsNullable:
           Always 1 for source columns in the tolerant RAW layer.
       ============================================================ */

    DECLARE @Dictionary TABLE
    (
        Code                  INT             NOT NULL,
        SourceColumnName      NVARCHAR(150)   NOT NULL,

        SourceDataType        NVARCHAR(100)   NULL,
        SourceIsNullable      BIT             NULL,

        Description           NVARCHAR(1000)  NULL,

        RawSqlDataType        VARCHAR(30)     NOT NULL,
        RawDataTypeLength     INT             NULL,
        RawDataTypePrecision  TINYINT         NULL,
        RawDataTypeScale      TINYINT         NULL,
        RawIsNullable         BIT             NOT NULL,

        OrdinalPosition       INT             NOT NULL,

        IsBusinessKey         BIT             NOT NULL,
        IsIncrementalColumn   BIT             NOT NULL,
        IsActive              BIT             NOT NULL
    );


    INSERT INTO @Dictionary
    (
        Code,
        SourceColumnName,

        SourceDataType,
        SourceIsNullable,

        Description,

        RawSqlDataType,
        RawDataTypeLength,
        RawDataTypePrecision,
        RawDataTypeScale,
        RawIsNullable,

        OrdinalPosition,

        IsBusinessKey,
        IsIncrementalColumn,
        IsActive
    )
    VALUES

    /* ============================================================
       1. the_geom
       ============================================================ */

    (
        1,
        'the_geom',

        'multipolygon',
        NULL,

        'Geographic multipolygon geometry as exposed by the source.',

        'NVARCHAR',
        -1,
        NULL,
        NULL,
        1,

        1,

        0,
        0,
        1
    ),


    /* ============================================================
       2. area_numbe

       Business key for the Community Area.
       ============================================================ */

    (
        2,
        'area_numbe',

        'number',
        NULL,

        'Community area number as exposed by the source.',

        'NVARCHAR',
        50,
        NULL,
        NULL,
        1,

        2,

        1,
        0,
        1
    ),


    /* ============================================================
       3. community
       ============================================================ */

    (
        3,
        'community',

        'text',
        NULL,

        'Official community area name as exposed by the source.',

        'NVARCHAR',
        255,
        NULL,
        NULL,
        1,

        3,

        0,
        0,
        1
    ),


    /* ============================================================
       4. area_num_1
       ============================================================ */

    (
        4,
        'area_num_1',

        'text',
        NULL,

        'Text representation of the community area number as exposed by the source.',

        'NVARCHAR',
        50,
        NULL,
        NULL,
        1,

        4,

        0,
        0,
        1
    ),


    /* ============================================================
       5. shape_area
       ============================================================ */

    (
        5,
        'shape_area',

        'number',
        NULL,

        'Area measurement associated with the geographic shape.',

        'NVARCHAR',
        100,
        NULL,
        NULL,
        1,

        5,

        0,
        0,
        1
    ),


    /* ============================================================
       6. shape_len
       ============================================================ */

    (
        6,
        'shape_len',

        'number',
        NULL,

        'Length measurement associated with the geographic shape.',

        'NVARCHAR',
        100,
        NULL,
        NULL,
        1,

        6,

        0,
        0,
        1
    );


    /* ============================================================
       Update existing metadata
       ============================================================ */

    UPDATE target
    SET
        target.SourceColumnName =
            source.SourceColumnName,

        target.SourceDataType =
            source.SourceDataType,

        target.SourceIsNullable =
            source.SourceIsNullable,

        target.Description =
            source.Description,

        target.RawSqlDataType =
            source.RawSqlDataType,

        target.RawDataTypeLength =
            source.RawDataTypeLength,

        target.RawDataTypePrecision =
            source.RawDataTypePrecision,

        target.RawDataTypeScale =
            source.RawDataTypeScale,

        target.RawIsNullable =
            source.RawIsNullable,

        target.OrdinalPosition =
            source.OrdinalPosition,

        target.IsBusinessKey =
            source.IsBusinessKey,

        target.IsIncrementalColumn =
            source.IsIncrementalColumn,

        target.IsActive =
            source.IsActive,

        target.UpdatedAtUtc =
            SYSUTCDATETIME()

    FROM cfg.DataDictionary target

    INNER JOIN @Dictionary source
        ON source.Code = target.Code

    WHERE target.SourceTableID = @SourceTableID;


    /* ============================================================
       Insert metadata that does not exist
       ============================================================ */

    INSERT INTO cfg.DataDictionary
    (
        SourceTableID,

        Code,
        SourceColumnName,

        SourceDataType,
        SourceIsNullable,

        Description,

        RawSqlDataType,
        RawDataTypeLength,
        RawDataTypePrecision,
        RawDataTypeScale,
        RawIsNullable,

        OrdinalPosition,

        IsBusinessKey,
        IsIncrementalColumn,
        IsActive
    )

    SELECT
        @SourceTableID,

        source.Code,
        source.SourceColumnName,

        source.SourceDataType,
        source.SourceIsNullable,

        source.Description,

        source.RawSqlDataType,
        source.RawDataTypeLength,
        source.RawDataTypePrecision,
        source.RawDataTypeScale,
        source.RawIsNullable,

        source.OrdinalPosition,

        source.IsBusinessKey,
        source.IsIncrementalColumn,
        source.IsActive

    FROM @Dictionary source

    WHERE NOT EXISTS
    (
        SELECT 1
        FROM cfg.DataDictionary target
        WHERE target.SourceTableID = @SourceTableID
          AND target.Code = source.Code
    );


    COMMIT TRANSACTION;

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO