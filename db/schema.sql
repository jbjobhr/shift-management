/* =====================================================================
 * ShiftManagement - MSSQL Schema
 * 對應前端 localStorage 的 shiftMgmt:global / shiftMgmt:personal:{empId}
 * 來源檔案：index.html / shift-list.html / shift-setting-new.html /
 *           personal-shift.html / README.md
 * ===================================================================== */

IF DB_ID(N'ShiftManagement') IS NULL
    CREATE DATABASE ShiftManagement;
GO

USE ShiftManagement;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

/* ---------- 清空 (drop in dependency-safe order) ---------- */
IF OBJECT_ID(N'dbo.PersonalAssignment','U')      IS NOT NULL DROP TABLE dbo.PersonalAssignment;
IF OBJECT_ID(N'dbo.PersonalShiftConfig','U')     IS NOT NULL DROP TABLE dbo.PersonalShiftConfig;
IF OBJECT_ID(N'dbo.PersonalSetting','U')         IS NOT NULL DROP TABLE dbo.PersonalSetting;
IF OBJECT_ID(N'dbo.AttendanceGroupWeekday','U')  IS NOT NULL DROP TABLE dbo.AttendanceGroupWeekday;
IF OBJECT_ID(N'dbo.AttendanceGroupPunchLoc','U') IS NOT NULL DROP TABLE dbo.AttendanceGroupPunchLoc;
IF OBJECT_ID(N'dbo.AttendanceGroupMember','U')   IS NOT NULL DROP TABLE dbo.AttendanceGroupMember;
IF OBJECT_ID(N'dbo.AttendanceGroup','U')         IS NOT NULL DROP TABLE dbo.AttendanceGroup;
IF OBJECT_ID(N'dbo.SchedulePosition','U')        IS NOT NULL DROP TABLE dbo.SchedulePosition;
IF OBJECT_ID(N'dbo.Schedule','U')                IS NOT NULL DROP TABLE dbo.Schedule;
IF OBJECT_ID(N'dbo.HolidayGroupDate','U')        IS NOT NULL DROP TABLE dbo.HolidayGroupDate;
IF OBJECT_ID(N'dbo.HolidayGroup','U')            IS NOT NULL DROP TABLE dbo.HolidayGroup;
IF OBJECT_ID(N'dbo.IndividualHoliday','U')       IS NOT NULL DROP TABLE dbo.IndividualHoliday;
IF OBJECT_ID(N'dbo.EmployeeTag','U')             IS NOT NULL DROP TABLE dbo.EmployeeTag;
IF OBJECT_ID(N'dbo.Employee','U')                IS NOT NULL DROP TABLE dbo.Employee;
IF OBJECT_ID(N'dbo.Tag','U')                     IS NOT NULL DROP TABLE dbo.Tag;
IF OBJECT_ID(N'dbo.Position','U')                IS NOT NULL DROP TABLE dbo.Position;
IF OBJECT_ID(N'dbo.PunchLocation','U')           IS NOT NULL DROP TABLE dbo.PunchLocation;
IF OBJECT_ID(N'dbo.Department','U')              IS NOT NULL DROP TABLE dbo.Department;
IF OBJECT_ID(N'dbo.Branch','U')                  IS NOT NULL DROP TABLE dbo.Branch;
IF OBJECT_ID(N'dbo.Supervisor','U')              IS NOT NULL DROP TABLE dbo.Supervisor;
IF OBJECT_ID(N'dbo.Shift','U')                   IS NOT NULL DROP TABLE dbo.Shift;
IF OBJECT_ID(N'dbo.AppMeta','U')                 IS NOT NULL DROP TABLE dbo.AppMeta;
GO

/* ---------- 系統 / Meta ---------- */
CREATE TABLE dbo.AppMeta (
    [Key]        NVARCHAR(50)  NOT NULL PRIMARY KEY,
    [Value]      NVARCHAR(200) NOT NULL,
    UpdatedAt    DATETIME2     NOT NULL CONSTRAINT DF_AppMeta_UpdatedAt DEFAULT (SYSUTCDATETIME())
);
GO

/* ---------- 字典類 ---------- */
CREATE TABLE dbo.Branch (
    BranchId   INT IDENTITY(1,1) PRIMARY KEY,
    Name       NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.Department (
    DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.Position (
    PositionId INT IDENTITY(1,1) PRIMARY KEY,
    Name       NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.PunchLocation (
    PunchLocationId INT IDENTITY(1,1) PRIMARY KEY,
    Name            NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.Tag (
    TagId INT IDENTITY(1,1) PRIMARY KEY,
    Name  NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.Supervisor (
    SupervisorId INT IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(50) NOT NULL UNIQUE
);
GO

/* ---------- 員工 ---------- */
CREATE TABLE dbo.Employee (
    EmployeeId    NVARCHAR(20)  NOT NULL PRIMARY KEY,        -- 例：EMP001
    Name          NVARCHAR(50)  NOT NULL,
    BranchId      INT NULL REFERENCES dbo.Branch(BranchId),
    DepartmentId  INT NULL REFERENCES dbo.Department(DepartmentId),
    IsActive      BIT NOT NULL CONSTRAINT DF_Employee_IsActive DEFAULT (1),
    CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_Employee_CreatedAt DEFAULT (SYSUTCDATETIME())
);

CREATE TABLE dbo.EmployeeTag (
    EmployeeId NVARCHAR(20) NOT NULL REFERENCES dbo.Employee(EmployeeId) ON DELETE CASCADE,
    TagId      INT          NOT NULL REFERENCES dbo.Tag(TagId)            ON DELETE CASCADE,
    CONSTRAINT PK_EmployeeTag PRIMARY KEY (EmployeeId, TagId)
);
GO

/* ---------- 班別 ---------- */
CREATE TABLE dbo.Shift (
    ShiftId    INT IDENTITY(1,1) PRIMARY KEY,
    Name       NVARCHAR(50) NOT NULL UNIQUE,           -- 早班
    ShortName  NVARCHAR(8)  NOT NULL,                  -- 早
    StartTime  TIME(0)      NOT NULL,
    EndTime    TIME(0)      NOT NULL,
    Hours      DECIMAL(4,2) NOT NULL,                  -- 計薪工時
    Rest       DECIMAL(4,2) NOT NULL CONSTRAINT DF_Shift_Rest DEFAULT (0),
    OtStart    TIME(0)      NULL,
    OtEnd      TIME(0)      NULL
);
GO

/* ---------- 假別組 / 個別假日 ---------- */
CREATE TABLE dbo.HolidayGroup (
    HolidayGroupId INT IDENTITY(1,1) PRIMARY KEY,
    Name           NVARCHAR(50) NOT NULL UNIQUE       -- 台灣國定假日 / 一例一休
);

CREATE TABLE dbo.HolidayGroupDate (
    HolidayGroupId INT  NOT NULL REFERENCES dbo.HolidayGroup(HolidayGroupId) ON DELETE CASCADE,
    [Date]         DATE NOT NULL,
    CONSTRAINT PK_HolidayGroupDate PRIMARY KEY (HolidayGroupId, [Date])
);

CREATE TABLE dbo.IndividualHoliday (
    [Date]    DATE          NOT NULL PRIMARY KEY,
    Note      NVARCHAR(100) NULL
);
GO

/* ---------- 班表 (Schedule) ---------- */
CREATE TABLE dbo.Schedule (
    ScheduleId  INT IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(100) NOT NULL,                -- 2026年1月排班
    StartDate   DATE          NOT NULL,
    EndDate     DATE          NOT NULL,
    BranchId    INT NULL REFERENCES dbo.Branch(BranchId),
    CreatedAt   DATETIME2 NOT NULL CONSTRAINT DF_Schedule_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_Schedule_DateRange CHECK (EndDate >= StartDate)
);

CREATE TABLE dbo.SchedulePosition (
    ScheduleId  INT NOT NULL REFERENCES dbo.Schedule(ScheduleId) ON DELETE CASCADE,
    PositionId  INT NOT NULL REFERENCES dbo.Position(PositionId) ON DELETE CASCADE,
    CONSTRAINT PK_SchedulePosition PRIMARY KEY (ScheduleId, PositionId)
);
GO

/* ---------- 考勤組 ---------- */
CREATE TABLE dbo.AttendanceGroup (
    AttendanceGroupId INT IDENTITY(1,1) PRIMARY KEY,
    Name              NVARCHAR(80) NOT NULL UNIQUE,
    ScheduleType      VARCHAR(10)  NOT NULL CONSTRAINT DF_AG_Type DEFAULT ('auto'),
    WorkOnHoliday     BIT          NOT NULL CONSTRAINT DF_AG_WOH  DEFAULT (0),
    CONSTRAINT CK_AG_Type CHECK (ScheduleType IN ('auto','manual'))
);

CREATE TABLE dbo.AttendanceGroupMember (
    AttendanceGroupId INT          NOT NULL REFERENCES dbo.AttendanceGroup(AttendanceGroupId) ON DELETE CASCADE,
    EmployeeId        NVARCHAR(20) NOT NULL REFERENCES dbo.Employee(EmployeeId)               ON DELETE CASCADE,
    CONSTRAINT PK_AGM PRIMARY KEY (AttendanceGroupId, EmployeeId)
);

CREATE TABLE dbo.AttendanceGroupPunchLoc (
    AttendanceGroupId INT NOT NULL REFERENCES dbo.AttendanceGroup(AttendanceGroupId) ON DELETE CASCADE,
    PunchLocationId   INT NOT NULL REFERENCES dbo.PunchLocation(PunchLocationId)     ON DELETE CASCADE,
    CONSTRAINT PK_AGPL PRIMARY KEY (AttendanceGroupId, PunchLocationId)
);

/* 考勤組週間排班：每組 + 星期 + 班別 (多班別於同日 -> 多列) */
CREATE TABLE dbo.AttendanceGroupWeekday (
    AttendanceGroupId INT         NOT NULL REFERENCES dbo.AttendanceGroup(AttendanceGroupId) ON DELETE CASCADE,
    DayOfWeek         VARCHAR(3)  NOT NULL,            -- sun/mon/tue/wed/thu/fri/sat
    ShiftId           INT         NOT NULL REFERENCES dbo.Shift(ShiftId),
    SortOrder         INT         NOT NULL CONSTRAINT DF_AGW_Sort DEFAULT (0),
    CONSTRAINT PK_AGW PRIMARY KEY (AttendanceGroupId, DayOfWeek, ShiftId),
    CONSTRAINT CK_AGW_DOW CHECK (DayOfWeek IN ('sun','mon','tue','wed','thu','fri','sat'))
);
GO

/* ---------- 個人班表 ---------- */
CREATE TABLE dbo.PersonalShiftConfig (
    EmployeeId  NVARCHAR(20) NOT NULL PRIMARY KEY REFERENCES dbo.Employee(EmployeeId) ON DELETE CASCADE,
    RangeStart  DATE NULL,
    RangeEnd    DATE NULL,
    UpdatedAt   DATETIME2 NOT NULL CONSTRAINT DF_PSC_UpdatedAt DEFAULT (SYSUTCDATETIME())
);

/* 個人指派：一日 + 一班別 一列；type=off 時 ShiftId 為 NULL */
CREATE TABLE dbo.PersonalAssignment (
    PersonalAssignmentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId  NVARCHAR(20) NOT NULL REFERENCES dbo.Employee(EmployeeId) ON DELETE CASCADE,
    [Date]      DATE          NOT NULL,
    AssignType  VARCHAR(8)    NOT NULL,        -- 'work' | 'off'
    ShiftId     INT           NULL REFERENCES dbo.Shift(ShiftId),
    Source      VARCHAR(10)   NULL,            -- 'manual' or NULL(auto)
    CONSTRAINT CK_PA_Type   CHECK (AssignType IN ('work','off')),
    CONSTRAINT CK_PA_Shift  CHECK (
        (AssignType = 'off'  AND ShiftId IS NULL) OR
        (AssignType = 'work' AND ShiftId IS NOT NULL)
    )
);
CREATE INDEX IX_PA_EmpDate ON dbo.PersonalAssignment(EmployeeId, [Date]);
-- 同員工同日同班別不重複；type='off' 之列以 ShiftId IS NULL 區分
CREATE UNIQUE INDEX UX_PA_EmpDateShift
    ON dbo.PersonalAssignment(EmployeeId, [Date], ShiftId)
    WHERE ShiftId IS NOT NULL;
CREATE UNIQUE INDEX UX_PA_EmpDateOff
    ON dbo.PersonalAssignment(EmployeeId, [Date])
    WHERE ShiftId IS NULL;
GO

/* 個人套用之假別組 / 考勤組 / 班別 / 崗位 / 標籤 (草稿之上一次套用結果) */
CREATE TABLE dbo.PersonalSetting (
    EmployeeId   NVARCHAR(20) NOT NULL REFERENCES dbo.Employee(EmployeeId) ON DELETE CASCADE,
    Category     VARCHAR(20)  NOT NULL,    -- 'holidayGroup'|'attendanceGroup'|'shift'|'position'|'tag'
    RefId        INT          NOT NULL,    -- 對應字典/實體的 PK
    CONSTRAINT PK_PersonalSetting PRIMARY KEY (EmployeeId, Category, RefId),
    CONSTRAINT CK_PS_Category CHECK (Category IN ('holidayGroup','attendanceGroup','shift','position','tag'))
);
GO

/* ---------- 寫入版本 ---------- */
MERGE dbo.AppMeta AS t
USING (VALUES (N'DataVersion', N'13')) AS s([Key],[Value])
ON t.[Key] = s.[Key]
WHEN MATCHED THEN UPDATE SET [Value] = s.[Value], UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT([Key],[Value]) VALUES (s.[Key], s.[Value]);
GO

PRINT 'ShiftManagement schema 建立完成';
GO
