USE ChicagoTaxiDW;
GO


/* ============================================================
   ctr.BatchRun

   Represents one execution of the overall ETL pipeline.

   Examples:
       Scheduled D-1 execution
       Manual execution
       Historical backfill
       Reprocessing

   ParentBatchRunID:
       Links a reprocessing batch to the original batch.
   ============================================================ */

IF OBJECT_ID('ctr.BatchRun', 'U') IS NULL
BEGIN

    CREATE TABLE ctr.BatchRun
    (
        BatchRunID BIGINT IDENTITY(1,1) NOT NULL,

        ParentBatchRunID BIGINT NULL,

        EnvironmentCode VARCHAR(10) NOT NULL,

        /*
            Business/process date.

            Example:
            Pipeline runs on 2026-08-23
            ProcessDate = 2026-08-22
        */
        ProcessDate DATE NOT NULL,

        /*
            SCHEDULED
            MANUAL
            BACKFILL
            REPROCESS
        */
        RunType VARCHAR(20) NOT NULL,

        /*
            PENDING
            RUNNING
            SUCCESS
            PARTIAL_SUCCESS
            FAILED
            CANCELLED
        */
        Status VARCHAR(20) NOT NULL
            CONSTRAINT DF_BatchRun_Status
            DEFAULT ('PENDING'),

        RequestedBy NVARCHAR(255) NULL,

        Notes NVARCHAR(2000) NULL,

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_BatchRun_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        StartedAtUtc DATETIME2(0) NULL,

        EndedAtUtc DATETIME2(0) NULL,


        CONSTRAINT PK_BatchRun
            PRIMARY KEY (BatchRunID),

        CONSTRAINT FK_BatchRun_ParentBatchRun
            FOREIGN KEY (ParentBatchRunID)
            REFERENCES ctr.BatchRun(BatchRunID),

        CONSTRAINT CK_BatchRun_Environment
            CHECK
            (
                EnvironmentCode IN
                (
                    'DEV',
                    'QA',
                    'PRD'
                )
            ),

        CONSTRAINT CK_BatchRun_RunType
            CHECK
            (
                RunType IN
                (
                    'SCHEDULED',
                    'MANUAL',
                    'BACKFILL',
                    'REPROCESS'
                )
            ),

        CONSTRAINT CK_BatchRun_Status
            CHECK
            (
                Status IN
                (
                    'PENDING',
                    'RUNNING',
                    'SUCCESS',
                    'PARTIAL_SUCCESS',
                    'FAILED',
                    'CANCELLED'
                )
            ),

        CONSTRAINT CK_BatchRun_Dates
            CHECK
            (
                EndedAtUtc IS NULL
                OR StartedAtUtc IS NULL
                OR EndedAtUtc >= StartedAtUtc
            )
    );

END;
GO


/* ============================================================
   ctr.DataSourceRun

   Represents one execution attempt for a datasource within
   a BatchRun.

   A new row is created for every datasource retry.

   DataSourceConnectionID identifies exactry which physical
   environment connection was used.
   ============================================================ */

IF OBJECT_ID('ctr.DataSourceRun', 'U') IS NULL
BEGIN

    CREATE TABLE ctr.DataSourceRun
    (
        DataSourceRunID BIGINT IDENTITY(1,1) NOT NULL,

        BatchRunID BIGINT NOT NULL,

        DataSourceConnectionID INT NOT NULL,

        ParentDataSourceRunID BIGINT NULL,

        AttemptNumber INT NOT NULL
            CONSTRAINT DF_DataSourceRun_AttemptNumber
            DEFAULT (1),

        Status VARCHAR(20) NOT NULL
            CONSTRAINT DF_DataSourceRun_Status
            DEFAULT ('PENDING'),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_DataSourceRun_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        StartedAtUtc DATETIME2(0) NULL,

        EndedAtUtc DATETIME2(0) NULL,


        CONSTRAINT PK_DataSourceRun
            PRIMARY KEY (DataSourceRunID),

        CONSTRAINT FK_DataSourceRun_BatchRun
            FOREIGN KEY (BatchRunID)
            REFERENCES ctr.BatchRun(BatchRunID),

        CONSTRAINT FK_DataSourceRun_DataSourceConnection
            FOREIGN KEY (DataSourceConnectionID)
            REFERENCES cfg.DataSourceConnection
            (
                DataSourceConnectionID
            ),

        CONSTRAINT FK_DataSourceRun_ParentDataSourceRun
            FOREIGN KEY (ParentDataSourceRunID)
            REFERENCES ctr.DataSourceRun(DataSourceRunID),

        CONSTRAINT UQ_DataSourceRun_Attempt
            UNIQUE
            (
                BatchRunID,
                DataSourceConnectionID,
                AttemptNumber
            ),

        CONSTRAINT CK_DataSourceRun_AttemptNumber
            CHECK
            (
                AttemptNumber > 0
            ),

        CONSTRAINT CK_DataSourceRun_Status
            CHECK
            (
                Status IN
                (
                    'PENDING',
                    'RUNNING',
                    'SUCCESS',
                    'PARTIAL_SUCCESS',
                    'FAILED',
                    'SKIPPED',
                    'CANCELLED'
                )
            ),

        CONSTRAINT CK_DataSourceRun_Dates
            CHECK
            (
                EndedAtUtc IS NULL
                OR StartedAtUtc IS NULL
                OR EndedAtUtc >= StartedAtUtc
            )
    );

END;
GO


/* ============================================================
   ctr.TableRun

   Granular execution control.

   One row represents ONE execution attempt of one SourceTable.

   Important:
       Retry does NOT overwrite the previous TableRun.
       A new TableRun row is created with AttemptNumber + 1.

   ParentTableRunID:
       Allows lineage between retries/reprocessing attempts.
   ============================================================ */

IF OBJECT_ID('ctr.TableRun', 'U') IS NULL
BEGIN

    CREATE TABLE ctr.TableRun
    (
        TableRunID BIGINT IDENTITY(1,1) NOT NULL,

        DataSourceRunID BIGINT NOT NULL,

        SourceTableID INT NOT NULL,

        ParentTableRunID BIGINT NULL,

        /*
            Snapshot of ProcessDate.

            Although ProcessDate also exists in BatchRun,
            keeping it here simplifies granular troubleshooting
            and allows future table-specific reprocessing.
        */
        ProcessDate DATE NOT NULL,

        AttemptNumber INT NOT NULL
            CONSTRAINT DF_TableRun_AttemptNumber
            DEFAULT (1),

        /*
            Snapshot of the configuration used during execution.
        */
        LoadType VARCHAR(10) NOT NULL,

        IsMandatory BIT NOT NULL,


        /* ====================================================
           Incremental execution range

           Stored as text intentionally because future sources
           may use:
               datetime
               integer
               sequence
               timestamp
               string watermarks

           Example for Taxi Trips:

           IncrementalStartValue =
               2026-08-22 00:00:00

           IncrementalEndValue =
               2026-08-23 00:00:00
           ==================================================== */

        IncrementalStartValue NVARCHAR(1000) NULL,

        IncrementalEndValue NVARCHAR(1000) NULL,


        /* ====================================================
           Row-level execution metrics
           ==================================================== */

        RowsRead BIGINT NOT NULL
            CONSTRAINT DF_TableRun_RowsRead
            DEFAULT (0),

        RowsInserted BIGINT NOT NULL
            CONSTRAINT DF_TableRun_RowsInserted
            DEFAULT (0),

        RowsUpdated BIGINT NOT NULL
            CONSTRAINT DF_TableRun_RowsUpdated
            DEFAULT (0),

        RowsDeleted BIGINT NOT NULL
            CONSTRAINT DF_TableRun_RowsDeleted
            DEFAULT (0),

        RowsRejected BIGINT NOT NULL
            CONSTRAINT DF_TableRun_RowsRejected
            DEFAULT (0),


        /* ====================================================
           Execution status
           ==================================================== */

        Status VARCHAR(20) NOT NULL
            CONSTRAINT DF_TableRun_Status
            DEFAULT ('PENDING'),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_TableRun_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        StartedAtUtc DATETIME2(0) NULL,

        EndedAtUtc DATETIME2(0) NULL,


        /* ====================================================
           Keys
           ==================================================== */

        CONSTRAINT PK_TableRun
            PRIMARY KEY (TableRunID),

        CONSTRAINT FK_TableRun_DataSourceRun
            FOREIGN KEY (DataSourceRunID)
            REFERENCES ctr.DataSourceRun(DataSourceRunID),

        CONSTRAINT FK_TableRun_SourceTable
            FOREIGN KEY (SourceTableID)
            REFERENCES cfg.SourceTable(SourceTableID),

        CONSTRAINT FK_TableRun_ParentTableRun
            FOREIGN KEY (ParentTableRunID)
            REFERENCES ctr.TableRun(TableRunID),


        /* ====================================================
           Uniqueness

           Same table can execute multiple times inside a
           DataSourceRun, but each attempt number is unique.
           ==================================================== */

        CONSTRAINT UQ_TableRun_Attempt
            UNIQUE
            (
                DataSourceRunID,
                SourceTableID,
                AttemptNumber
            ),


        /* ====================================================
           Validation
           ==================================================== */

        CONSTRAINT CK_TableRun_AttemptNumber
            CHECK
            (
                AttemptNumber > 0
            ),

        CONSTRAINT CK_TableRun_LoadType
            CHECK
            (
                LoadType IN
                (
                    'FULL',
                    'INCR'
                )
            ),

        CONSTRAINT CK_TableRun_Status
            CHECK
            (
                Status IN
                (
                    'PENDING',
                    'RUNNING',
                    'SUCCESS',
                    'FAILED',
                    'SKIPPED',
                    'CANCELLED'
                )
            ),

        CONSTRAINT CK_TableRun_RowsRead
            CHECK (RowsRead >= 0),

        CONSTRAINT CK_TableRun_RowsInserted
            CHECK (RowsInserted >= 0),

        CONSTRAINT CK_TableRun_RowsUpdated
            CHECK (RowsUpdated >= 0),

        CONSTRAINT CK_TableRun_RowsDeleted
            CHECK (RowsDeleted >= 0),

        CONSTRAINT CK_TableRun_RowsRejected
            CHECK (RowsRejected >= 0),

        CONSTRAINT CK_TableRun_Dates
            CHECK
            (
                EndedAtUtc IS NULL
                OR StartedAtUtc IS NULL
                OR EndedAtUtc >= StartedAtUtc
            )
    );

END;
GO