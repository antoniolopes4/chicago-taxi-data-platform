USE ChicagoTaxiDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    /* ============================================================
       Resolve COMMUNITY_AREAS using its stable Code.
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
              'Active source table COMMUNITY_AREAS (Code 1002) was not found.',
              1;
    END;


    /* ============================================================
       One row represents one source column.
       ============================================================ */

    DECLARE @Dictionary TABLE
    (
        Code                INT            NOT NULL,
        SourceColumnName    NVARCHAR(150)  NOT NULL,
        TargetColumnName    SYSNAME        NOT NULL,
        Description         NVARCHAR(1000) NULL,

        SqlDataType         VARCHAR(30)    NOT NULL,
        DataTypeLength      INT            NULL,
        DataTypePrecision   TINYINT        NULL,
        DataTypeScale       TINYINT        NULL,

        IsNullable          BIT            NOT NULL,
        OrdinalPosition     INT            NOT NULL,

        IsBusinessKey       BIT            NOT NULL,
        IsIncrementalColumn BIT            NOT NULL,
        IsActive            BIT            NOT NULL
    );


    INSERT INTO @Dictionary
    (
        Code,
        SourceColumnName,
        TargetColumnName,
        Description,
        SqlDataType,
        DataTypeLength,
        DataTypePrecision,
        DataTypeScale,
        IsNullable,
        OrdinalPosition,
        IsBusinessKey,
        IsIncrementalColumn,
        IsActive
    )
    VALUES

    /* ------------------------------------------------------------
       Geometry
       ------------------------------------------------------------ */

    (
        1,
        'the_geom',
        'GeometryRaw',
        'Raw multipolygon geometry received from the source.',
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

    /* ------------------------------------------------------------
       Community Area Number
       Official row identifier / business key
       ------------------------------------------------------------ */

    (
        2,
        'area_numbe',
        'CommunityAreaNumber',
        'Official numeric identifier of the Chicago community area.',
        'SMALLINT',
        NULL,
        NULL,
        NULL,
        0,
        2,
        1,
        0,
        1
    ),

    /* ------------------------------------------------------------
       Community Area Name
       ------------------------------------------------------------ */

    (
        3,
        'community',
        'CommunityAreaName',
        'Official name of the Chicago community area.',
        'NVARCHAR',
        100,
        NULL,
        NULL,
        1,
        3,
        0,
        0,
        1
    ),

    /* ------------------------------------------------------------
       Source textual representation of area number
       ------------------------------------------------------------ */

    (
        4,
        'area_num_1',
        'CommunityAreaNumberText',
        'Text representation of the community area number as provided by the source.',
        'NVARCHAR',
        10,
        NULL,
        NULL,
        1,
        4,
        0,
        0,
        1
    ),

    /* ------------------------------------------------------------
       Shape Area
       ------------------------------------------------------------ */

    (
        5,
        'shape_area',
        'ShapeArea',
        'Area measurement associated with the source geographic shape.',
        'DECIMAL',
        NULL,
        20,
        6,
        1,
        5,
        0,
        0,
        1
    ),

    /* ------------------------------------------------------------
       Shape Length
       ------------------------------------------------------------ */

    (
        6,
        'shape_len',
        'ShapeLength',
        'Length measurement associated with the source geographic shape.',
        'DECIMAL',
        NULL,
        20,
        6,
        1,
        6,
        0,
        0,
        1
    );


    /* ============================================================
       UPDATE existing metadata

       This makes changes to the seed deployable without changing
       the surrogate DataDictionaryID.
       ============================================================ */

    UPDATE target
    SET
        target.SourceColumnName = source.SourceColumnName,
        target.TargetColumnName = source.TargetColumnName,
        target.Description = source.Description,

        target.SqlDataType = source.SqlDataType,
        target.DataTypeLength = source.DataTypeLength,
        target.DataTypePrecision = source.DataTypePrecision,
        target.DataTypeScale = source.DataTypeScale,

        target.IsNullable = source.IsNullable,
        target.OrdinalPosition = source.OrdinalPosition,
        target.IsBusinessKey = source.IsBusinessKey,
        target.IsIncrementalColumn = source.IsIncrementalColumn,
        target.IsActive = source.IsActive,

        target.UpdatedAtUtc = SYSUTCDATETIME()

    FROM cfg.DataDictionary target

    INNER JOIN @Dictionary source
        ON source.Code = target.Code

    WHERE target.SourceTableID = @SourceTableID;


    /* ============================================================
       INSERT metadata that does not exist yet
       ============================================================ */

    INSERT INTO cfg.DataDictionary
    (
        SourceTableID,

        Code,
        SourceColumnName,
        TargetColumnName,
        Description,

        SqlDataType,
        DataTypeLength,
        DataTypePrecision,
        DataTypeScale,

        IsNullable,
        OrdinalPosition,
        IsBusinessKey,
        IsIncrementalColumn,
        IsActive
    )

    SELECT
        @SourceTableID,

        source.Code,
        source.SourceColumnName,
        source.TargetColumnName,
        source.Description,

        source.SqlDataType,
        source.DataTypeLength,
        source.DataTypePrecision,
        source.DataTypeScale,

        source.IsNullable,
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