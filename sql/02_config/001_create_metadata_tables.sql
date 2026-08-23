USE ChicagoTaxiDW;
GO

/* ============================================================
   cfg.DataSource

   Defines the source systems available to the ETL framework.
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
            CHECK (
                SourceType IN (
                    'API',
                    'SQLSERVER',
                    'MYSQL',
                    'DB2',
                    'POSTGRES',
                    'CSV',
                    'EXCEL',
                    'JSON',
                    'PARQUET',
                    'SFTP',
                    'OTHER'
                )
            )
    );

END;
GO


/* ============================================================
   cfg.SourceTable

   Defines the objects that can be ingested from each source.

   LoadType:
       FULL = complete reload
       INCR = incremental processing

   QueryFilter:
       Optional static source filter.
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

        LoadType VARCHAR(10) NOT NULL,

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
            UNIQUE (DataSourceID, TechnicalName),

        CONSTRAINT UQ_SourceTable_RawTarget
            UNIQUE (RawSchemaName, RawTableName),

        CONSTRAINT CK_SourceTable_Code
            CHECK (Code > 0),

        CONSTRAINT CK_SourceTable_LoadType
            CHECK (LoadType IN ('FULL', 'INCR'))
    );

END;
GO


/* ============================================================
   cfg.DataDictionary

   Describes the structure of every source object.

   Used by the metadata-driven framework.
   ============================================================ */

IF OBJECT_ID('cfg.DataDictionary', 'U') IS NULL
BEGIN

    CREATE TABLE cfg.DataDictionary
    (
        DataDictionaryID INT IDENTITY(1,1) NOT NULL,

        SourceTableID INT NOT NULL,

        Code INT NOT NULL,

        SourceColumnName NVARCHAR(150) NOT NULL,

        TargetColumnName SYSNAME NOT NULL,

        Description NVARCHAR(1000) NULL,

        SqlDataType VARCHAR(30) NOT NULL,

        DataTypeLength INT NULL,

        DataTypePrecision TINYINT NULL,

        DataTypeScale TINYINT NULL,

        IsNullable BIT NOT NULL
            CONSTRAINT DF_DataDictionary_IsNullable
            DEFAULT (1),

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

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_DataDictionary_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        UpdatedAtUtc DATETIME2(0) NULL,

        CONSTRAINT PK_DataDictionary
            PRIMARY KEY (DataDictionaryID),

        CONSTRAINT FK_DataDictionary_SourceTable
            FOREIGN KEY (SourceTableID)
            REFERENCES cfg.SourceTable(SourceTableID),

        CONSTRAINT UQ_DataDictionary_Table_Code
            UNIQUE (SourceTableID, Code),

        CONSTRAINT UQ_DataDictionary_Table_SourceColumn
            UNIQUE (SourceTableID, SourceColumnName),

        CONSTRAINT UQ_DataDictionary_Table_TargetColumn
            UNIQUE (SourceTableID, TargetColumnName),

        CONSTRAINT UQ_DataDictionary_Table_Ordinal
            UNIQUE (SourceTableID, OrdinalPosition),

        CONSTRAINT CK_DataDictionary_Code
            CHECK (Code > 0),

        CONSTRAINT CK_DataDictionary_OrdinalPosition
            CHECK (OrdinalPosition > 0),

        CONSTRAINT CK_DataDictionary_DataTypeLength
            CHECK
            (
                DataTypeLength IS NULL
                OR DataTypeLength = -1
                OR DataTypeLength > 0
            ),

        CONSTRAINT CK_DataDictionary_Precision
            CHECK
            (
                DataTypePrecision IS NULL
                OR DataTypePrecision BETWEEN 1 AND 38
            ),

        CONSTRAINT CK_DataDictionary_Scale
            CHECK
            (
                DataTypeScale IS NULL
                OR DataTypeScale BETWEEN 0 AND 38
            ),

        CONSTRAINT CK_DataDictionary_ScalePrecision
            CHECK
            (
                DataTypeScale IS NULL
                OR DataTypePrecision IS NULL
                OR DataTypeScale <= DataTypePrecision
            ),

        CONSTRAINT CK_DataDictionary_SqlDataType
            CHECK
            (
                SqlDataType IN
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

                    'UNIQUEIDENTIFIER'
                )
            )
    );

END;
GO