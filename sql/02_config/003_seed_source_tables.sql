USE ChicagoTaxiDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    /* ============================================================
       Resolve CHICAGO_OPEN_DATA
       ============================================================ */

    DECLARE @ChicagoDataSourceID INT;

    SELECT
        @ChicagoDataSourceID = DataSourceID
    FROM cfg.DataSource
    WHERE Code = 100
      AND IsActive = 1;


    IF @ChicagoDataSourceID IS NULL
    BEGIN
        THROW 50001,
              'Active datasource CHICAGO_OPEN_DATA (Code 100) was not found.',
              1;
    END;


    /* ============================================================
       1001 - TAXI_TRIPS

       Source:
           Chicago Open Data / Socrata
           Dataset ID: ajtu-isnz

       Load:
           Incremental

       RAW Target:
           raw.TaxiTrip
       ============================================================ */

    UPDATE cfg.SourceTable
    SET
        DataSourceID = @ChicagoDataSourceID,
        TechnicalName = 'TAXI_TRIPS',
        Name = 'Chicago Taxi Trips',
        Description = 'Taxi trips reported to the City of Chicago from January 2024 onward.',
        SourceObjectType = 'ENDPOINT',
        SourceObjectName = 'ajtu-isnz',
        LoadType = 'INCR',
        QueryFilter = NULL,
        RawSchemaName = 'raw',
        RawTableName = 'TaxiTrip',
        IsMandatory = 1,
        IsActive = 1,
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE Code = 1001;


    IF @@ROWCOUNT = 0
    BEGIN

        INSERT INTO cfg.SourceTable
        (
            DataSourceID,
            Code,
            TechnicalName,
            Name,
            Description,
            SourceObjectType,
            SourceObjectName,
            LoadType,
            QueryFilter,
            RawSchemaName,
            RawTableName,
            IsMandatory,
            IsActive
        )
        VALUES
        (
            @ChicagoDataSourceID,
            1001,
            'TAXI_TRIPS',
            'Chicago Taxi Trips',
            'Taxi trips reported to the City of Chicago from January 2024 onward.',
            'ENDPOINT',
            'ajtu-isnz',
            'INCR',
            NULL,
            'raw',
            'TaxiTrip',
            1,
            1
        );

    END;


    /* ============================================================
       1002 - COMMUNITY_AREAS

       Source:
           Chicago Open Data / Socrata
           Dataset ID: igwz-8jzy

       Load:
           Full

       RAW Target:
           raw.CommunityArea
       ============================================================ */

    UPDATE cfg.SourceTable
    SET
        DataSourceID = @ChicagoDataSourceID,
        TechnicalName = 'COMMUNITY_AREAS',
        Name = 'Chicago Community Areas',
        Description = 'Official current community area boundaries and reference data for Chicago.',
        SourceObjectType = 'ENDPOINT',
        SourceObjectName = 'igwz-8jzy',
        LoadType = 'FULL',
        QueryFilter = NULL,
        RawSchemaName = 'raw',
        RawTableName = 'CommunityArea',
        IsMandatory = 1,
        IsActive = 1,
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE Code = 1002;


    IF @@ROWCOUNT = 0
    BEGIN

        INSERT INTO cfg.SourceTable
        (
            DataSourceID,
            Code,
            TechnicalName,
            Name,
            Description,
            SourceObjectType,
            SourceObjectName,
            LoadType,
            QueryFilter,
            RawSchemaName,
            RawTableName,
            IsMandatory,
            IsActive
        )
        VALUES
        (
            @ChicagoDataSourceID,
            1002,
            'COMMUNITY_AREAS',
            'Chicago Community Areas',
            'Official current community area boundaries and reference data for Chicago.',
            'ENDPOINT',
            'igwz-8jzy',
            'FULL',
            NULL,
            'raw',
            'CommunityArea',
            1,
            1
        );

    END;


    COMMIT TRANSACTION;

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO