USE ChicagoTaxiDW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    /* ============================================================
       DataSource
       Code: 100
       Technical Name: CHICAGO_OPEN_DATA

       Code is the stable functional identifier.
       DataSourceID is the local surrogate/technical key.
       ============================================================ */

    UPDATE cfg.DataSource
    SET
        TechnicalName = 'CHICAGO_OPEN_DATA',
        Name = 'Chicago Open Data',
        Description = 'Public open data platform provided by the City of Chicago.',
        SourceType = 'API',
        ProviderType = 'SOCRATA',
        IsActive = 1,
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE Code = 100;


    IF @@ROWCOUNT = 0
    BEGIN

        INSERT INTO cfg.DataSource
        (
            Code,
            TechnicalName,
            Name,
            Description,
            SourceType,
            ProviderType,
            IsActive
        )
        VALUES
        (
            100,
            'CHICAGO_OPEN_DATA',
            'Chicago Open Data',
            'Public open data platform provided by the City of Chicago.',
            'API',
            'SOCRATA',
            1
        );

    END;


    /* ============================================================
       Resolve the local surrogate key.

       Never assume:
           DataSourceID = 1

       Always resolve it using the stable Code.
       ============================================================ */

    DECLARE @ChicagoDataSourceID INT;

    SELECT
        @ChicagoDataSourceID = DataSourceID
    FROM cfg.DataSource
    WHERE Code = 100;


    IF @ChicagoDataSourceID IS NULL
    BEGIN
        THROW 50001,
              'Unable to resolve CHICAGO_OPEN_DATA datasource.',
              1;
    END;


    /* ============================================================
       DEV connection

       Connection Code = 1
       TechnicalName   = DEFAULT

       Chicago Open Data is public, so no credentials are needed.
       ============================================================ */

    UPDATE cfg.DataSourceConnection
    SET
        TechnicalName = 'DEFAULT',
        BaseUrl = 'https://data.cityofchicago.org/resource',
        ServerName = NULL,
        InstanceName = NULL,
        DatabaseName = NULL,
        Port = 443,
        ShareName = NULL,
        BasePath = NULL,
        AuthenticationType = 'NONE',
        DomainName = NULL,
        UserName = NULL,
        SecretReference = NULL,
        ConnectionTimeoutSeconds = 30,
        IsActive = 1,
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE DataSourceID = @ChicagoDataSourceID
      AND EnvironmentCode = 'DEV'
      AND Code = 1;


    IF @@ROWCOUNT = 0
    BEGIN

        INSERT INTO cfg.DataSourceConnection
        (
            DataSourceID,
            Code,
            TechnicalName,
            EnvironmentCode,

            ServerName,
            InstanceName,
            DatabaseName,
            Port,

            BaseUrl,

            ShareName,
            BasePath,

            AuthenticationType,
            DomainName,
            UserName,
            SecretReference,

            ConnectionTimeoutSeconds,
            IsActive
        )
        VALUES
        (
            @ChicagoDataSourceID,
            1,
            'DEFAULT',
            'DEV',

            NULL,
            NULL,
            NULL,
            443,

            'https://data.cityofchicago.org/resource',

            NULL,
            NULL,

            'NONE',
            NULL,
            NULL,
            NULL,

            30,
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