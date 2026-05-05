/* =====================================================================
 * ShiftManagement - Stored Procedures
 * 目的：將前端 DTO 直接同步到 MSSQL
 *   - dbo.usp_SyncGlobal(@Payload NVARCHAR(MAX))
 *   - dbo.usp_SyncPersonal(@Payload NVARCHAR(MAX))
 * ===================================================================== */

USE ShiftManagement;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncGlobal
    @Payload NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(@Payload) <> 1
        THROW 50001, N'Invalid JSON payload for usp_SyncGlobal', 1;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Version INT = TRY_CONVERT(INT, JSON_VALUE(@Payload, '$.version'));

        /* ---------------- 字典資料 ---------------- */
        CREATE TABLE #Branch (Name NVARCHAR(50) NOT NULL PRIMARY KEY);
        CREATE TABLE #Department (Name NVARCHAR(50) NOT NULL PRIMARY KEY);
        CREATE TABLE #Position (Name NVARCHAR(50) NOT NULL PRIMARY KEY);
        CREATE TABLE #Tag (Name NVARCHAR(50) NOT NULL PRIMARY KEY);
        CREATE TABLE #Supervisor (Name NVARCHAR(50) NOT NULL PRIMARY KEY);
        CREATE TABLE #PunchLocation (Name NVARCHAR(50) NOT NULL PRIMARY KEY);

        INSERT INTO #Branch(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.branches')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        INSERT INTO #Department(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.departments')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        INSERT INTO #Position(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.positions')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        INSERT INTO #Tag(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.tags')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        INSERT INTO #Supervisor(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.supervisors')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        INSERT INTO #PunchLocation(Name)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@Payload, '$.dictionary.punchLocations')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL;

        MERGE dbo.Branch AS t
        USING #Branch AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        MERGE dbo.Department AS t
        USING #Department AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        MERGE dbo.Position AS t
        USING #Position AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        MERGE dbo.Tag AS t
        USING #Tag AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        MERGE dbo.Supervisor AS t
        USING #Supervisor AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        MERGE dbo.PunchLocation AS t
        USING #PunchLocation AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        /* ---------------- 員工 ---------------- */
        CREATE TABLE #Person (
            EmployeeId   NVARCHAR(20) NOT NULL PRIMARY KEY,
            Name         NVARCHAR(50) NOT NULL,
            BranchName   NVARCHAR(50) NULL,
            DepartmentName NVARCHAR(50) NULL,
            IsActive     BIT NOT NULL
        );

        INSERT INTO #Person(EmployeeId, Name, BranchName, DepartmentName, IsActive)
        SELECT
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.id'))),
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))),
            NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.branch'))), N''),
            NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.department'))), N''),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(j.value, '$.isActive')), 1)
        FROM OPENJSON(@Payload, '$.persons') j
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.id'))), N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))), N'') IS NOT NULL;

        MERGE dbo.Employee AS t
        USING (
            SELECT p.EmployeeId,
                   p.Name,
                   b.BranchId,
                   d.DepartmentId,
                   p.IsActive
            FROM #Person p
            LEFT JOIN dbo.Branch b ON b.Name = p.BranchName
            LEFT JOIN dbo.Department d ON d.Name = p.DepartmentName
        ) AS s
          ON t.EmployeeId = s.EmployeeId
        WHEN MATCHED THEN
          UPDATE SET t.Name = s.Name,
                     t.BranchId = s.BranchId,
                     t.DepartmentId = s.DepartmentId,
                     t.IsActive = s.IsActive
        WHEN NOT MATCHED THEN
          INSERT (EmployeeId, Name, BranchId, DepartmentId, IsActive)
          VALUES (s.EmployeeId, s.Name, s.BranchId, s.DepartmentId, s.IsActive);

        /* ---------------- 班別 ---------------- */
        CREATE TABLE #Shift (
            Name       NVARCHAR(50) NOT NULL PRIMARY KEY,
            ShortName  NVARCHAR(8)  NOT NULL,
            StartTime  TIME(0)      NOT NULL,
            EndTime    TIME(0)      NOT NULL,
            Hours      DECIMAL(4,2) NOT NULL,
            Rest       DECIMAL(4,2) NOT NULL,
            OtStart    TIME(0)      NULL,
            OtEnd      TIME(0)      NULL
        );

        INSERT INTO #Shift(Name, ShortName, StartTime, EndTime, Hours, Rest, OtStart, OtEnd)
        SELECT
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))),
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.shortName'))),
            TRY_CONVERT(TIME(0), JSON_VALUE(j.value, '$.start')),
            TRY_CONVERT(TIME(0), JSON_VALUE(j.value, '$.end')),
            TRY_CONVERT(DECIMAL(4,2), JSON_VALUE(j.value, '$.hours')),
            ISNULL(TRY_CONVERT(DECIMAL(4,2), JSON_VALUE(j.value, '$.rest')), 0),
            TRY_CONVERT(TIME(0), NULLIF(JSON_VALUE(j.value, '$.otStart'), N'')),
            TRY_CONVERT(TIME(0), NULLIF(JSON_VALUE(j.value, '$.otEnd'), N''))
        FROM OPENJSON(@Payload, '$.shifts') j
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))), N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.shortName'))), N'') IS NOT NULL;

        MERGE dbo.Shift AS t
        USING #Shift AS s
          ON t.Name = s.Name
        WHEN MATCHED THEN
          UPDATE SET t.ShortName = s.ShortName,
                     t.StartTime = s.StartTime,
                     t.EndTime = s.EndTime,
                     t.Hours = s.Hours,
                     t.Rest = s.Rest,
                     t.OtStart = s.OtStart,
                     t.OtEnd = s.OtEnd
        WHEN NOT MATCHED THEN
          INSERT (Name, ShortName, StartTime, EndTime, Hours, Rest, OtStart, OtEnd)
          VALUES (s.Name, s.ShortName, s.StartTime, s.EndTime, s.Hours, s.Rest, s.OtStart, s.OtEnd);

        /* ---------------- 假別 ---------------- */
        CREATE TABLE #HolidayGroup (
            Name NVARCHAR(50) NOT NULL PRIMARY KEY,
            DatesJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #HolidayGroup(Name, DatesJson)
        SELECT
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))),
            JSON_QUERY(j.value, '$.dates')
        FROM OPENJSON(@Payload, '$.holidayGroups') j
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))), N'') IS NOT NULL;

        MERGE dbo.HolidayGroup AS t
        USING #HolidayGroup AS s
          ON t.Name = s.Name
        WHEN NOT MATCHED THEN
          INSERT (Name) VALUES (s.Name);

        CREATE TABLE #HolidayGroupMap (
            HolidayGroupId INT NOT NULL PRIMARY KEY,
            Name NVARCHAR(50) NOT NULL,
            DatesJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #HolidayGroupMap(HolidayGroupId, Name, DatesJson)
        SELECT hg.HolidayGroupId, src.Name, src.DatesJson
        FROM #HolidayGroup src
        JOIN dbo.HolidayGroup hg ON hg.Name = src.Name;

        DELETE d
        FROM dbo.HolidayGroupDate d
        JOIN #HolidayGroupMap m ON m.HolidayGroupId = d.HolidayGroupId;

        INSERT INTO dbo.HolidayGroupDate(HolidayGroupId, [Date])
        SELECT DISTINCT
            m.HolidayGroupId,
            TRY_CONVERT(DATE, jd.value)
        FROM #HolidayGroupMap m
        CROSS APPLY OPENJSON(m.DatesJson) jd
        WHERE TRY_CONVERT(DATE, jd.value) IS NOT NULL;

        DELETE FROM dbo.IndividualHoliday;
        INSERT INTO dbo.IndividualHoliday([Date])
        SELECT DISTINCT TRY_CONVERT(DATE, j.value)
        FROM OPENJSON(@Payload, '$.individualHolidays') j
        WHERE TRY_CONVERT(DATE, j.value) IS NOT NULL;

        /* ---------------- 考勤組 ---------------- */
        CREATE TABLE #AttendanceGroup (
            Name NVARCHAR(80) NOT NULL PRIMARY KEY,
            ScheduleType VARCHAR(10) NOT NULL,
            WorkOnHoliday BIT NOT NULL,
            MembersJson NVARCHAR(MAX) NULL,
            PunchLocationsJson NVARCHAR(MAX) NULL,
            WeekdayShiftsJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #AttendanceGroup(Name, ScheduleType, WorkOnHoliday, MembersJson, PunchLocationsJson, WeekdayShiftsJson)
        SELECT
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))),
            ISNULL(NULLIF(JSON_VALUE(j.value, '$.scheduleType'), ''), 'auto'),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(j.value, '$.workOnHoliday')), 0),
            JSON_QUERY(j.value, '$.members'),
            JSON_QUERY(j.value, '$.punchLocations'),
            JSON_QUERY(j.value, '$.weekdayShifts')
        FROM OPENJSON(@Payload, '$.attendanceGroups') j
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))), N'') IS NOT NULL;

        MERGE dbo.AttendanceGroup AS t
        USING #AttendanceGroup AS s
          ON t.Name = s.Name
        WHEN MATCHED THEN
          UPDATE SET t.ScheduleType = CASE WHEN s.ScheduleType IN ('auto','manual') THEN s.ScheduleType ELSE 'auto' END,
                     t.WorkOnHoliday = s.WorkOnHoliday
        WHEN NOT MATCHED THEN
          INSERT (Name, ScheduleType, WorkOnHoliday)
          VALUES (s.Name, CASE WHEN s.ScheduleType IN ('auto','manual') THEN s.ScheduleType ELSE 'auto' END, s.WorkOnHoliday);

        CREATE TABLE #AttendanceGroupMap (
            AttendanceGroupId INT NOT NULL PRIMARY KEY,
            Name NVARCHAR(80) NOT NULL,
            MembersJson NVARCHAR(MAX) NULL,
            PunchLocationsJson NVARCHAR(MAX) NULL,
            WeekdayShiftsJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #AttendanceGroupMap(AttendanceGroupId, Name, MembersJson, PunchLocationsJson, WeekdayShiftsJson)
        SELECT ag.AttendanceGroupId, src.Name, src.MembersJson, src.PunchLocationsJson, src.WeekdayShiftsJson
        FROM #AttendanceGroup src
        JOIN dbo.AttendanceGroup ag ON ag.Name = src.Name;

        DELETE m
        FROM dbo.AttendanceGroupMember m
        JOIN #AttendanceGroupMap am ON am.AttendanceGroupId = m.AttendanceGroupId;

        INSERT INTO dbo.AttendanceGroupMember(AttendanceGroupId, EmployeeId)
        SELECT DISTINCT
            am.AttendanceGroupId,
            e.EmployeeId
        FROM #AttendanceGroupMap am
        CROSS APPLY OPENJSON(am.MembersJson) jm
        JOIN dbo.Employee e ON e.EmployeeId = LTRIM(RTRIM(jm.value));

        DELETE p
        FROM dbo.AttendanceGroupPunchLoc p
        JOIN #AttendanceGroupMap am ON am.AttendanceGroupId = p.AttendanceGroupId;

        INSERT INTO dbo.AttendanceGroupPunchLoc(AttendanceGroupId, PunchLocationId)
        SELECT DISTINCT
            am.AttendanceGroupId,
            pl.PunchLocationId
        FROM #AttendanceGroupMap am
        CROSS APPLY OPENJSON(am.PunchLocationsJson) jp
        JOIN dbo.PunchLocation pl ON pl.Name = LTRIM(RTRIM(jp.value));

        DELETE w
        FROM dbo.AttendanceGroupWeekday w
        JOIN #AttendanceGroupMap am ON am.AttendanceGroupId = w.AttendanceGroupId;

        INSERT INTO dbo.AttendanceGroupWeekday(AttendanceGroupId, DayOfWeek, ShiftId, SortOrder)
        SELECT
            am.AttendanceGroupId,
            wd.[key] AS DayOfWeek,
            s.ShiftId,
            ISNULL(TRY_CONVERT(INT, sn.[key]), 0) AS SortOrder
        FROM #AttendanceGroupMap am
        CROSS APPLY OPENJSON(am.WeekdayShiftsJson) wd
        CROSS APPLY OPENJSON(wd.value) sn
        JOIN dbo.Shift s ON s.Name = LTRIM(RTRIM(sn.value))
        WHERE wd.[key] IN ('sun','mon','tue','wed','thu','fri','sat');

        /* ---------------- 班表 ---------------- */
        CREATE TABLE #Schedule (
            Name NVARCHAR(100) NOT NULL,
            StartDate DATE NOT NULL,
            EndDate DATE NOT NULL,
            BranchName NVARCHAR(50) NULL,
            DepartmentName NVARCHAR(50) NULL,
            PositionsJson NVARCHAR(MAX) NULL,
            SupervisorsJson NVARCHAR(MAX) NULL,
            TagsJson NVARCHAR(MAX) NULL,
            AllowedShiftNamesJson NVARCHAR(MAX) NULL,
            AllowedHolidayGroupNamesJson NVARCHAR(MAX) NULL,
            AllowedAttendanceGroupNamesJson NVARCHAR(MAX) NULL,
            CONSTRAINT PK__TempSchedule PRIMARY KEY (Name, StartDate, EndDate)
        );

        INSERT INTO #Schedule(Name, StartDate, EndDate, BranchName, DepartmentName,
                              PositionsJson, SupervisorsJson, TagsJson,
                              AllowedShiftNamesJson, AllowedHolidayGroupNamesJson, AllowedAttendanceGroupNamesJson)
        SELECT
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))),
            TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.start')),
            TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.end')),
            NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.branch'))), N''),
            NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.department'))), N''),
            JSON_QUERY(j.value, '$.positions'),
            JSON_QUERY(j.value, '$.supervisors'),
            JSON_QUERY(j.value, '$.tags'),
            JSON_QUERY(j.value, '$.allowedShiftNames'),
            JSON_QUERY(j.value, '$.allowedHolidayGroupNames'),
            JSON_QUERY(j.value, '$.allowedAttendanceGroupNames')
        FROM OPENJSON(@Payload, '$.schedules') j
        WHERE NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.name'))), N'') IS NOT NULL
          AND TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.start')) IS NOT NULL
          AND TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.end')) IS NOT NULL;

        MERGE dbo.Schedule AS t
        USING (
            SELECT s.Name,
                   s.StartDate,
                   s.EndDate,
                   b.BranchId,
                   d.DepartmentId
            FROM #Schedule s
            LEFT JOIN dbo.Branch b ON b.Name = s.BranchName
            LEFT JOIN dbo.Department d ON d.Name = s.DepartmentName
        ) AS src
          ON t.Name = src.Name
         AND t.StartDate = src.StartDate
         AND t.EndDate = src.EndDate
        WHEN MATCHED THEN
          UPDATE SET t.BranchId = src.BranchId,
                     t.DepartmentId = src.DepartmentId
        WHEN NOT MATCHED THEN
          INSERT (Name, StartDate, EndDate, BranchId, DepartmentId)
          VALUES (src.Name, src.StartDate, src.EndDate, src.BranchId, src.DepartmentId);

        CREATE TABLE #ScheduleMap (
            ScheduleId INT NOT NULL PRIMARY KEY,
            PositionsJson NVARCHAR(MAX) NULL,
            SupervisorsJson NVARCHAR(MAX) NULL,
            TagsJson NVARCHAR(MAX) NULL,
            AllowedShiftNamesJson NVARCHAR(MAX) NULL,
            AllowedHolidayGroupNamesJson NVARCHAR(MAX) NULL,
            AllowedAttendanceGroupNamesJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #ScheduleMap(ScheduleId, PositionsJson, SupervisorsJson, TagsJson,
                                 AllowedShiftNamesJson, AllowedHolidayGroupNamesJson, AllowedAttendanceGroupNamesJson)
        SELECT
            sch.ScheduleId,
            src.PositionsJson,
            src.SupervisorsJson,
            src.TagsJson,
            src.AllowedShiftNamesJson,
            src.AllowedHolidayGroupNamesJson,
            src.AllowedAttendanceGroupNamesJson
        FROM #Schedule src
        JOIN dbo.Schedule sch
          ON sch.Name = src.Name
         AND sch.StartDate = src.StartDate
         AND sch.EndDate = src.EndDate;

        DELETE sp
        FROM dbo.SchedulePosition sp
        JOIN #ScheduleMap sm ON sm.ScheduleId = sp.ScheduleId;

        INSERT INTO dbo.SchedulePosition(ScheduleId, PositionId)
        SELECT DISTINCT
            sm.ScheduleId,
            p.PositionId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.PositionsJson) jp
        JOIN dbo.Position p ON p.Name = LTRIM(RTRIM(jp.value));

        DELETE ss
        FROM dbo.ScheduleSupervisor ss
        JOIN #ScheduleMap sm ON sm.ScheduleId = ss.ScheduleId;

        INSERT INTO dbo.ScheduleSupervisor(ScheduleId, SupervisorId)
        SELECT DISTINCT
            sm.ScheduleId,
            s.SupervisorId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.SupervisorsJson) js
        JOIN dbo.Supervisor s ON s.Name = LTRIM(RTRIM(js.value));

        DELETE st
        FROM dbo.ScheduleTag st
        JOIN #ScheduleMap sm ON sm.ScheduleId = st.ScheduleId;

        INSERT INTO dbo.ScheduleTag(ScheduleId, TagId)
        SELECT DISTINCT
            sm.ScheduleId,
            t.TagId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.TagsJson) jt
        JOIN dbo.Tag t ON t.Name = LTRIM(RTRIM(jt.value));

        DELETE sas
        FROM dbo.ScheduleAllowedShift sas
        JOIN #ScheduleMap sm ON sm.ScheduleId = sas.ScheduleId;

        INSERT INTO dbo.ScheduleAllowedShift(ScheduleId, ShiftId)
        SELECT DISTINCT
            sm.ScheduleId,
            s.ShiftId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.AllowedShiftNamesJson) js
        JOIN dbo.Shift s ON s.Name = LTRIM(RTRIM(js.value));

        DELETE sah
        FROM dbo.ScheduleAllowedHolidayGroup sah
        JOIN #ScheduleMap sm ON sm.ScheduleId = sah.ScheduleId;

        INSERT INTO dbo.ScheduleAllowedHolidayGroup(ScheduleId, HolidayGroupId)
        SELECT DISTINCT
            sm.ScheduleId,
            hg.HolidayGroupId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.AllowedHolidayGroupNamesJson) jh
        JOIN dbo.HolidayGroup hg ON hg.Name = LTRIM(RTRIM(jh.value));

        DELETE saa
        FROM dbo.ScheduleAllowedAttendanceGroup saa
        JOIN #ScheduleMap sm ON sm.ScheduleId = saa.ScheduleId;

        INSERT INTO dbo.ScheduleAllowedAttendanceGroup(ScheduleId, AttendanceGroupId)
        SELECT DISTINCT
            sm.ScheduleId,
            ag.AttendanceGroupId
        FROM #ScheduleMap sm
        CROSS APPLY OPENJSON(sm.AllowedAttendanceGroupNamesJson) ja
        JOIN dbo.AttendanceGroup ag ON ag.Name = LTRIM(RTRIM(ja.value));

        /* ---------------- 版本 ---------------- */
        IF @Version IS NOT NULL
        BEGIN
            MERGE dbo.AppMeta AS t
            USING (SELECT N'DataVersion' AS [Key], CONVERT(NVARCHAR(200), @Version) AS [Value]) AS s
               ON t.[Key] = s.[Key]
            WHEN MATCHED THEN
              UPDATE SET t.[Value] = s.[Value], t.UpdatedAt = SYSUTCDATETIME()
            WHEN NOT MATCHED THEN
              INSERT ([Key], [Value]) VALUES (s.[Key], s.[Value]);
        END

        COMMIT;

        SELECT
            CAST(1 AS BIT) AS [ok],
            @Version AS [version],
            SYSUTCDATETIME() AS [updatedAt],
            (SELECT COUNT(*) FROM #Person) AS [employees],
            (SELECT COUNT(*) FROM #Shift) AS [shifts],
            (SELECT COUNT(*) FROM #AttendanceGroup) AS [attendanceGroups],
            (SELECT COUNT(*) FROM #Schedule) AS [schedules];
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SyncPersonal
    @Payload NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(@Payload) <> 1
        THROW 50011, N'Invalid JSON payload for usp_SyncPersonal', 1;

    DECLARE @EmployeeId NVARCHAR(20) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@Payload, '$.employeeId'))), N'');
    DECLARE @RangeStart DATE = TRY_CONVERT(DATE, JSON_VALUE(@Payload, '$.rangeStart'));
    DECLARE @RangeEnd DATE = TRY_CONVERT(DATE, JSON_VALUE(@Payload, '$.rangeEnd'));

    IF @EmployeeId IS NULL
        THROW 50012, N'employeeId is required', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE EmployeeId = @EmployeeId)
            THROW 50013, N'Employee not found', 1;

        MERGE dbo.PersonalShiftConfig AS t
        USING (SELECT @EmployeeId AS EmployeeId, @RangeStart AS RangeStart, @RangeEnd AS RangeEnd) AS s
           ON t.EmployeeId = s.EmployeeId
        WHEN MATCHED THEN
          UPDATE SET t.RangeStart = s.RangeStart,
                     t.RangeEnd = s.RangeEnd,
                     t.UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
          INSERT (EmployeeId, RangeStart, RangeEnd)
          VALUES (s.EmployeeId, s.RangeStart, s.RangeEnd);

        CREATE TABLE #Assignment (
            [Date] DATE NOT NULL,
            AssignType VARCHAR(8) NOT NULL,
            Source VARCHAR(10) NULL,
            ShiftNamesJson NVARCHAR(MAX) NULL
        );

        INSERT INTO #Assignment([Date], AssignType, Source, ShiftNamesJson)
        SELECT
            TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.date')),
            LTRIM(RTRIM(JSON_VALUE(j.value, '$.type'))),
            NULLIF(LTRIM(RTRIM(JSON_VALUE(j.value, '$.source'))), N''),
            JSON_QUERY(j.value, '$.shiftNames')
        FROM OPENJSON(@Payload, '$.assignments') j
        WHERE TRY_CONVERT(DATE, JSON_VALUE(j.value, '$.date')) IS NOT NULL
          AND LTRIM(RTRIM(JSON_VALUE(j.value, '$.type'))) IN ('work','off');

        IF @RangeStart IS NOT NULL AND @RangeEnd IS NOT NULL
        BEGIN
            DELETE FROM dbo.PersonalAssignment
            WHERE EmployeeId = @EmployeeId
              AND [Date] BETWEEN @RangeStart AND @RangeEnd;
        END
        ELSE
        BEGIN
            DELETE FROM dbo.PersonalAssignment
            WHERE EmployeeId = @EmployeeId;
        END

        INSERT INTO dbo.PersonalAssignment(EmployeeId, [Date], AssignType, ShiftId, Source)
        SELECT DISTINCT
            @EmployeeId,
            a.[Date],
            'off',
            NULL,
            a.Source
        FROM #Assignment a
        WHERE a.AssignType = 'off';

        INSERT INTO dbo.PersonalAssignment(EmployeeId, [Date], AssignType, ShiftId, Source)
        SELECT DISTINCT
            @EmployeeId,
            a.[Date],
            'work',
            s.ShiftId,
            a.Source
        FROM #Assignment a
        CROSS APPLY OPENJSON(a.ShiftNamesJson) sn
        JOIN dbo.Shift s ON s.Name = LTRIM(RTRIM(sn.value))
        WHERE a.AssignType = 'work';

        DELETE FROM dbo.PersonalSetting
        WHERE EmployeeId = @EmployeeId;

        INSERT INTO dbo.PersonalSetting(EmployeeId, Category, RefId)
        SELECT DISTINCT @EmployeeId, 'holidayGroup', hg.HolidayGroupId
        FROM OPENJSON(@Payload, '$.settings.holidayGroups') j
        JOIN dbo.HolidayGroup hg ON hg.Name = LTRIM(RTRIM(j.value));

        INSERT INTO dbo.PersonalSetting(EmployeeId, Category, RefId)
        SELECT DISTINCT @EmployeeId, 'attendanceGroup', ag.AttendanceGroupId
        FROM OPENJSON(@Payload, '$.settings.attendanceGroups') j
        JOIN dbo.AttendanceGroup ag ON ag.Name = LTRIM(RTRIM(j.value));

        INSERT INTO dbo.PersonalSetting(EmployeeId, Category, RefId)
        SELECT DISTINCT @EmployeeId, 'shift', s.ShiftId
        FROM OPENJSON(@Payload, '$.settings.shifts') j
        JOIN dbo.Shift s ON s.Name = LTRIM(RTRIM(j.value));

        INSERT INTO dbo.PersonalSetting(EmployeeId, Category, RefId)
        SELECT DISTINCT @EmployeeId, 'position', p.PositionId
        FROM OPENJSON(@Payload, '$.settings.positions') j
        JOIN dbo.Position p ON p.Name = LTRIM(RTRIM(j.value));

        INSERT INTO dbo.PersonalSetting(EmployeeId, Category, RefId)
        SELECT DISTINCT @EmployeeId, 'tag', t.TagId
        FROM OPENJSON(@Payload, '$.settings.tags') j
        JOIN dbo.Tag t ON t.Name = LTRIM(RTRIM(j.value));

        COMMIT;

        SELECT
            CAST(1 AS BIT) AS [ok],
            @EmployeeId AS [employeeId],
            SYSUTCDATETIME() AS [updatedAt],
            (SELECT COUNT(*) FROM dbo.PersonalAssignment WHERE EmployeeId = @EmployeeId) AS [assignmentCount];
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT 'Stored procedures 建立完成: dbo.usp_SyncGlobal, dbo.usp_SyncPersonal';
GO
