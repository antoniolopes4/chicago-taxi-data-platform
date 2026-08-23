USE ChicagoTaxiDW;
GO


/* ============================================================
    cfg.DataSource

    Logical definition of a source system.

    SourceType (e.g. DATABASE, API, STREAM, etc)

    ProviderType (e.g. SQLSERVER, KAFKA, etc)
   ============================================================ */

IF OBJECT_ID('cfg.DataSource', 'U') IS NULL
BEGIN

    CREATE TABLE cfg.DataSource
    (
        DataSourceID INT IDENTITY(1,1) NOT NULL,

        Code INT NOT NULL,

        TechnicalName VARCHAR(100) NOT NULL,

        Name NVARCHAR(150) NOT NULL,

        Description NVARCHAR(500) NULL,

        SourceType VARCHAR(30) NOT NULL,

        ProviderType VARCHAR(50) NOT NULL,

        IsActive BIT NOT NULL
            CONSTRAINT DF_DataSource_IsActive
            DEFAULT (1),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_DataSource_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        UpdatedAtUtc DATETIME2(0) NULL,


        CONSTRAINT PK_DataSource
            PRIMARY KEY (DataSourceID),

        CONSTRAINT UQ_DataSource_Code
            UNIQUE (Code),

        CONSTRAINT UQ_DataSource_TechnicalName
            UNIQUE (TechnicalName),

        CONSTRAINT CK_DataSource_Code
            CHECK (Code > 0),

        CONSTRAINT CK_DataSource_SourceType
            CHECK
            (
                SourceType IN
                (
                    'DATABASE',
                    'API',
                    'FILE',
                    'OBJECT_STORAGE',
                    'STREAM',
                    'OTHER'
                )
            )
    );

END;
GO


/* ============================================================
    cfg.DataSourceConnection

    Physical/environment-specific information required to
    connect to a datasource.


    IMPORTANT:
    Passwords, API keys and tokens must NOT be stored here.
    SecretReference contains only a reference to a secret.
   ============================================================ */

IF OBJECT_ID('cfg.DataSourceConnection', 'U') IS NULL
BEGIN

    CREATE TABLE cfg.DataSourceConnection
    (
        DataSourceConnectionID INT IDENTITY(1,1) NOT NULL,

        DataSourceID INT NOT NULL,

        Code INT NOT NULL,

        TechnicalName VARCHAR(100) NOT NULL,

        EnvironmentCode VARCHAR(10) NOT NULL,


        /* ====================================================
           Database / server / SFTP / file server
           ==================================================== */

        ServerName NVARCHAR(255) NULL,

        InstanceName NVARCHAR(255) NULL,

        DatabaseName SYSNAME NULL,

        Port INT NULL,


        /* ====================================================
           API
           ==================================================== */

        BaseUrl NVARCHAR(1000) NULL,


        /* ====================================================
           Shared / local / remote files

           Example:
           \\FILESRV01\finance\incoming

           ServerName = FILESRV01
           ShareName  = finance
           BasePath   = incoming
           ==================================================== */

        ShareName NVARCHAR(255) NULL,

        BasePath NVARCHAR(1000) NULL,


        /* ====================================================
           Authentication
           ==================================================== */

        AuthenticationType VARCHAR(30) NOT NULL,

        DomainName NVARCHAR(255) NULL,

        UserName NVARCHAR(255) NULL,

        /*
            Example:

            ERP_PRD_ETL_PASSWORD
            FINANCE_SHARE_PASSWORD

            This field stores the reference/name of the secret,
            NOT the password itself.
        */
        SecretReference NVARCHAR(255) NULL,


        ConnectionTimeoutSeconds INT NOT NULL
            CONSTRAINT DF_DataSourceConnection_Timeout
            DEFAULT (30),

        IsActive BIT NOT NULL
            CONSTRAINT DF_DataSourceConnection_IsActive
            DEFAULT (1),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_DataSourceConnection_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        UpdatedAtUtc DATETIME2(0) NULL,


        CONSTRAINT PK_DataSourceConnection
            PRIMARY KEY (DataSourceConnectionID),

        CONSTRAINT FK_DataSourceConnection_DataSource
            FOREIGN KEY (DataSourceID)
            REFERENCES cfg.DataSource(DataSourceID),

        CONSTRAINT UQ_DataSourceConnection_Code
            UNIQUE
            (
                DataSourceID,
                EnvironmentCode,
                Code
            ),

        CONSTRAINT UQ_DataSourceConnection_TechnicalName
            UNIQUE
            (
                DataSourceID,
                EnvironmentCode,
                TechnicalName
            ),

        CONSTRAINT CK_DataSourceConnection_Code
            CHECK (Code > 0),

        CONSTRAINT CK_DataSourceConnection_Environment
            CHECK
            (
                EnvironmentCode IN
                (
                    'DEV',
                    'QA',
                    'PRD'
                )
            ),

        CONSTRAINT CK_DataSourceConnection_Authentication
            CHECK
            (
                AuthenticationType IN
                (
                    'NONE',
                    'WINDOWS',
                    'SQL',
                    'BASIC',
                    'API_KEY',
                    'TOKEN',
                    'SFTP_PASSWORD',
                    'SFTP_KEY'
                )
            ),

        CONSTRAINT CK_DataSourceConnection_Port
            CHECK
            (
                Port IS NULL
                OR Port BETWEEN 1 AND 65535
            ),

        CONSTRAINT CK_DataSourceConnection_Timeout
            CHECK
            (
                ConnectionTimeoutSeconds > 0
            )
    );

END;
GO


/* ============================================================
    cfg.SourceTable

    Defines each logical object to be ingested from a datasource.
   ============================================================ */

IF OBJECT_ID('cfg.SourceTable', 'U') IS NULL
BEGIN

    CREATE TABLE cfg.SourceTable
    (
        SourceTableID INT IDENTITY(1,1) NOT NULL,

        DataSourceID INT NOT NULL,

        Code INT NOT NULL,

        TechnicalName VARCHAR(100) NOT NULL,

        Name NVARCHAR(150) NOT NULL,

        Description NVARCHAR(1000) NULL,

        /*
            TABLE
            VIEW
            ENDPOINT
            FILE
            OTHER
        */
        SourceObjectType VARCHAR(20) NOT NULL,

        SourceObjectName NVARCHAR(500) NOT NULL,

        LoadType VARCHAR(10) NOT NULL,

        /*
            Static filter only.

            Do not store D-1 dates here.
        */
        QueryFilter NVARCHAR(2000) NULL,

        RawSchemaName SYSNAME NOT NULL
            CONSTRAINT DF_SourceTable_RawSchemaName
            DEFAULT ('raw'),

        RawTableName SYSNAME NOT NULL,

        IsMandatory BIT NOT NULL
            CONSTRAINT DF_SourceTable_IsMandatory
            DEFAULT (1),

        IsActive BIT NOT NULL
            CONSTRAINT DF_SourceTable_IsActive
            DEFAULT (1),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SourceTable_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        UpdatedAtUtc DATETIME2(0) NULL,


        CONSTRAINT PK_SourceTable
            PRIMARY KEY (SourceTableID),

        CONSTRAINT FK_SourceTable_DataSource
            FOREIGN KEY (DataSourceID)
            REFERENCES cfg.DataSource(DataSourceID),

        CONSTRAINT UQ_SourceTable_Code
            UNIQUE (Code),

        CONSTRAINT UQ_SourceTable_DataSource_TechnicalName
            UNIQUE
            (
                DataSourceID,
                TechnicalName
            ),

        CONSTRAINT UQ_SourceTable_RawTarget
            UNIQUE
            (
                RawSchemaName,
                RawTableName
            ),

        CONSTRAINT CK_SourceTable_Code
            CHECK (Code > 0),

        CONSTRAINT CK_SourceTable_LoadType
            CHECK
            (
                LoadType IN
                (
                    'FULL',
                    'INCR'
                )
            ),

        CONSTRAINT CK_SourceTable_ObjectType
            CHECK
            (
                SourceObjectType IN
                (
                    'TABLE',
                    'VIEW',
                    'ENDPOINT',
                    'FILE',
                    'OTHER'
                )
            )
    );

END;
GO


/* ============================================================
   cfg.DataDictionary

   Describes source columns and how they are physically stored
   in the RAW / Bronze layer.

   Design principles:

   - Source metadata describes what the source declares.
   - RAW metadata describes how the value is stored in Bronze.
   - RAW column names remain identical to SourceColumnName.
   - RAW is intentionally tolerant.
   - Strong typing, renaming and data-quality enforcement belong
     to ODS / Silver.
   ============================================================ */

IF OBJECT_ID('cfg.DataDictionary', 'U') IS NULL
BEGIN

    CREATE TABLE cfg.DataDictionary
    (
        DataDictionaryID INT IDENTITY(1,1) NOT NULL,

        SourceTableID INT NOT NULL,

        /*
            Stable column code within the source table.
        */
        Code INT NOT NULL,


        /* ====================================================
           Source metadata
           ==================================================== */

        /*
            Exact column name as exposed by the source.

            This will also be the physical column name in RAW.
        */
        SourceColumnName NVARCHAR(150) NOT NULL,

        /*
            Datatype declared by the source.

            Examples:
                text
                number
                timestamp
                multipolygon
                varchar(50)

            NULL is allowed because some sources, such as CSV,
            may not expose an explicit datatype.
        */
        SourceDataType NVARCHAR(100) NULL,

        /*
            Nullability declared by the source.

            NULL means:
                unknown / not supplied by source metadata.
        */
        SourceIsNullable BIT NULL,

        Description NVARCHAR(1000) NULL,


        /* ====================================================
           RAW / Bronze physical storage
           ==================================================== */

        /*
            SQL Server datatype used to store the raw value.

            This may intentionally be more tolerant than the
            datatype declared by the source.

            Example:

                SourceDataType = number
                RawSqlDataType = NVARCHAR
        */
        RawSqlDataType VARCHAR(30) NOT NULL,

        RawDataTypeLength INT NULL,

        RawDataTypePrecision TINYINT NULL,

        RawDataTypeScale TINYINT NULL,

        /*
            RAW is designed to accept malformed or unexpected
            source values without blocking ingestion.

            Therefore the normal value is 1.
        */
        RawIsNullable BIT NOT NULL
            CONSTRAINT DF_DataDictionary_RawIsNullable
            DEFAULT (1),


        /* ====================================================
           Column semantics
           ==================================================== */

        OrdinalPosition INT NOT NULL,

        IsBusinessKey BIT NOT NULL
            CONSTRAINT DF_DataDictionary_IsBusinessKey
            DEFAULT (0),

        IsIncrementalColumn BIT NOT NULL
            CONSTRAINT DF_DataDictionary_IsIncrementalColumn
            DEFAULT (0),

        IsActive BIT NOT NULL
            CONSTRAINT DF_DataDictionary_IsActive
            DEFAULT (1),


        /* ====================================================
           Audit metadata
           ==================================================== */

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_DataDictionary_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        UpdatedAtUtc DATETIME2(0) NULL,


        /* ====================================================
           Keys
           ==================================================== */

        CONSTRAINT PK_DataDictionary
            PRIMARY KEY (DataDictionaryID),

        CONSTRAINT FK_DataDictionary_SourceTable
            FOREIGN KEY (SourceTableID)
            REFERENCES cfg.SourceTable(SourceTableID),


        /* ====================================================
           Uniqueness
           ==================================================== */

        CONSTRAINT UQ_DataDictionary_Table_Code
            UNIQUE
            (
                SourceTableID,
                Code
            ),

        CONSTRAINT UQ_DataDictionary_Table_SourceColumn
            UNIQUE
            (
                SourceTableID,
                SourceColumnName
            ),

        CONSTRAINT UQ_DataDictionary_Table_Ordinal
            UNIQUE
            (
                SourceTableID,
                OrdinalPosition
            ),


        /* ====================================================
           Validation
           ==================================================== */

        CONSTRAINT CK_DataDictionary_Code
            CHECK (Code > 0),

        CONSTRAINT CK_DataDictionary_OrdinalPosition
            CHECK (OrdinalPosition > 0),

        CONSTRAINT CK_DataDictionary_RawDataTypeLength
            CHECK
            (
                RawDataTypeLength IS NULL
                OR RawDataTypeLength = -1
                OR RawDataTypeLength > 0
            ),

        CONSTRAINT CK_DataDictionary_RawPrecision
            CHECK
            (
                RawDataTypePrecision IS NULL
                OR RawDataTypePrecision BETWEEN 1 AND 38
            ),

        CONSTRAINT CK_DataDictionary_RawScale
            CHECK
            (
                RawDataTypeScale IS NULL
                OR RawDataTypeScale BETWEEN 0 AND 38
            ),

        CONSTRAINT CK_DataDictionary_RawScalePrecision
            CHECK
            (
                RawDataTypeScale IS NULL
                OR RawDataTypePrecision IS NULL
                OR RawDataTypeScale <= RawDataTypePrecision
            ),

        CONSTRAINT CK_DataDictionary_RawSqlDataType
            CHECK
            (
                RawSqlDataType IN
                (
                    'BIT',
                    'TINYINT',
                    'SMALLINT',
                    'INT',
                    'BIGINT',

                    'DECIMAL',
                    'NUMERIC',
                    'FLOAT',
                    'REAL',

                    'CHAR',
                    'VARCHAR',
                    'NCHAR',
                    'NVARCHAR',

                    'DATE',
                    'TIME',
                    'DATETIME',
                    'DATETIME2',

                    'UNIQUEIDENTIFIER',

                    'BINARY',
                    'VARBINARY'
                )
            )
    );

END;
GO