/* =====================================================================
 * ShiftManagement - Seed data (對齊 index.html FALLBACK)
 * ===================================================================== */
USE ShiftManagement;
GO

SET NOCOUNT ON;

/* ---- 字典 ---- */
INSERT INTO dbo.Branch(Name) VALUES (N'總公司'),(N'北區分店'),(N'中區分店'),(N'南區分店');
INSERT INTO dbo.Department(Name) VALUES (N'管理部'),(N'營運部'),(N'倉儲部'),(N'物流部'),(N'客服部'),(N'人資部');
INSERT INTO dbo.Position(Name) VALUES
    (N'揀貨員'),(N'包裝員'),(N'理貨員'),(N'搬運工'),
    (N'品檢員'),(N'分類員'),(N'叉車手'),(N'司機');
INSERT INTO dbo.PunchLocation(Name) VALUES (N'總公司'),(N'倉儲中心'),(N'北區分部'),(N'中區分部'),(N'南區分部'),(N'外勤');
INSERT INTO dbo.Tag(Name) VALUES (N'可加班'),(N'新人'),(N'夜班優先');
INSERT INTO dbo.Supervisor(Name) VALUES (N'劉經理');

/* ---- 班別 ---- */
INSERT INTO dbo.Shift(Name, ShortName, StartTime, EndTime, Hours, Rest) VALUES
    (N'早班', N'早', '08:00', '17:00', 8, 1),
    (N'午班', N'午', '13:00', '17:00', 4, 0),
    (N'晚班', N'晚', '18:00', '22:00', 4, 0);

/* ---- 員工 ---- */
DECLARE @HQ INT = (SELECT BranchId FROM dbo.Branch WHERE Name=N'總公司');
INSERT INTO dbo.Employee(EmployeeId, Name, BranchId) VALUES
    (N'EMP001', N'王小明', @HQ),
    (N'EMP002', N'李小華', @HQ),
    (N'EMP003', N'張大偉', @HQ),
    (N'EMP004', N'陳美玲', @HQ),
    (N'EMP005', N'林志豪', @HQ);

/* ---- 假別組 ---- */
INSERT INTO dbo.HolidayGroup(Name) VALUES (N'台灣國定假日'),(N'一例一休');

DECLARE @gNat INT = (SELECT HolidayGroupId FROM dbo.HolidayGroup WHERE Name=N'台灣國定假日');
DECLARE @gWk  INT = (SELECT HolidayGroupId FROM dbo.HolidayGroup WHERE Name=N'一例一休');

INSERT INTO dbo.HolidayGroupDate(HolidayGroupId,[Date]) VALUES
    (@gNat,'2026-01-01'),(@gNat,'2026-02-28'),(@gNat,'2026-04-04'),
    (@gNat,'2026-05-01'),(@gNat,'2026-06-19'),(@gNat,'2026-10-10'),(@gNat,'2026-12-25');

-- 一例一休：產生 2026 全年週六/週日
;WITH d AS (
    SELECT CAST('2026-01-01' AS DATE) AS dt
    UNION ALL SELECT DATEADD(DAY,1,dt) FROM d WHERE dt < '2026-12-31'
)
INSERT INTO dbo.HolidayGroupDate(HolidayGroupId,[Date])
SELECT @gWk, dt FROM d WHERE DATEPART(WEEKDAY, dt) IN (1,7) -- 依預設語系，1=Sun,7=Sat (us_english)
OPTION (MAXRECURSION 400);

INSERT INTO dbo.IndividualHoliday([Date], Note) VALUES
    ('2026-01-20', N'彈性假期'),
    ('2026-02-20', N'彈性假期');

/* ---- 班表 ---- */
DECLARE @DeptWH INT = (SELECT DepartmentId FROM dbo.Department WHERE Name=N'倉儲部');
DECLARE @DeptOps INT = (SELECT DepartmentId FROM dbo.Department WHERE Name=N'營運部');

INSERT INTO dbo.Schedule(Name, StartDate, EndDate, BranchId, DepartmentId) VALUES
    (N'2026年1月排班', '2026-01-01', '2026-01-31', @HQ, @DeptWH),
    (N'2026年2月排班', '2026-02-01', '2026-02-28', @HQ, @DeptWH),
    (N'2026年3月排班', '2026-03-01', '2026-03-31', @HQ, @DeptOps);

/* ---- 考勤組 ---- */
INSERT INTO dbo.AttendanceGroup(Name, ScheduleType, WorkOnHoliday) VALUES
    (N'A組 - 倉儲', 'auto', 0),
    (N'B組 - 物流', 'auto', 1),
    (N'C組 - 客服', 'auto', 0);

DECLARE @A INT = (SELECT AttendanceGroupId FROM dbo.AttendanceGroup WHERE Name=N'A組 - 倉儲');
DECLARE @B INT = (SELECT AttendanceGroupId FROM dbo.AttendanceGroup WHERE Name=N'B組 - 物流');
DECLARE @C INT = (SELECT AttendanceGroupId FROM dbo.AttendanceGroup WHERE Name=N'C組 - 客服');

INSERT INTO dbo.AttendanceGroupMember(AttendanceGroupId, EmployeeId) VALUES
    (@A,N'EMP001'),(@A,N'EMP002'),
    (@B,N'EMP003'),
    (@C,N'EMP004'),(@C,N'EMP005');

DECLARE @sMorning INT = (SELECT ShiftId FROM dbo.Shift WHERE Name=N'早班');
DECLARE @sNoon    INT = (SELECT ShiftId FROM dbo.Shift WHERE Name=N'午班');
DECLARE @sNight   INT = (SELECT ShiftId FROM dbo.Shift WHERE Name=N'晚班');

-- A 組：週一~週五 早班
INSERT INTO dbo.AttendanceGroupWeekday(AttendanceGroupId, DayOfWeek, ShiftId) VALUES
    (@A,'mon',@sMorning),(@A,'tue',@sMorning),(@A,'wed',@sMorning),
    (@A,'thu',@sMorning),(@A,'fri',@sMorning);

-- B 組：週一/二/四 早班；週六、日 午+晚
INSERT INTO dbo.AttendanceGroupWeekday(AttendanceGroupId, DayOfWeek, ShiftId) VALUES
    (@B,'mon',@sMorning),(@B,'tue',@sMorning),(@B,'thu',@sMorning),
    (@B,'sat',@sNoon),(@B,'sat',@sNight),
    (@B,'sun',@sNoon),(@B,'sun',@sNight);

-- C 組：週一/三/五 早班；週二/四 午+晚
INSERT INTO dbo.AttendanceGroupWeekday(AttendanceGroupId, DayOfWeek, ShiftId) VALUES
    (@C,'mon',@sMorning),(@C,'wed',@sMorning),(@C,'fri',@sMorning),
    (@C,'tue',@sNoon),(@C,'tue',@sNight),
    (@C,'thu',@sNoon),(@C,'thu',@sNight);

/* ---- 班表層級可用範圍 / 主管 / 標籤 ---- */
DECLARE @SchJan INT = (SELECT ScheduleId FROM dbo.Schedule WHERE Name = N'2026年1月排班');
DECLARE @SchFeb INT = (SELECT ScheduleId FROM dbo.Schedule WHERE Name = N'2026年2月排班');
DECLARE @SchMar INT = (SELECT ScheduleId FROM dbo.Schedule WHERE Name = N'2026年3月排班');
DECLARE @SupLiu INT = (SELECT SupervisorId FROM dbo.Supervisor WHERE Name = N'劉經理');
DECLARE @TagOT INT = (SELECT TagId FROM dbo.Tag WHERE Name = N'可加班');
DECLARE @TagNew INT = (SELECT TagId FROM dbo.Tag WHERE Name = N'新人');

INSERT INTO dbo.ScheduleAllowedShift(ScheduleId, ShiftId)
SELECT @SchJan, s.ShiftId FROM dbo.Shift s WHERE s.Name IN (N'早班', N'午班', N'晚班');

INSERT INTO dbo.ScheduleAllowedShift(ScheduleId, ShiftId)
SELECT @SchFeb, s.ShiftId FROM dbo.Shift s WHERE s.Name IN (N'早班', N'午班');

INSERT INTO dbo.ScheduleAllowedShift(ScheduleId, ShiftId)
SELECT @SchMar, s.ShiftId FROM dbo.Shift s WHERE s.Name IN (N'早班', N'晚班');

INSERT INTO dbo.ScheduleAllowedHolidayGroup(ScheduleId, HolidayGroupId)
SELECT @SchJan, hg.HolidayGroupId FROM dbo.HolidayGroup hg WHERE hg.Name IN (N'台灣國定假日', N'一例一休');

INSERT INTO dbo.ScheduleAllowedHolidayGroup(ScheduleId, HolidayGroupId)
SELECT @SchFeb, hg.HolidayGroupId FROM dbo.HolidayGroup hg WHERE hg.Name IN (N'台灣國定假日');

INSERT INTO dbo.ScheduleAllowedHolidayGroup(ScheduleId, HolidayGroupId)
SELECT @SchMar, hg.HolidayGroupId FROM dbo.HolidayGroup hg WHERE hg.Name IN (N'台灣國定假日', N'一例一休');

INSERT INTO dbo.ScheduleAllowedAttendanceGroup(ScheduleId, AttendanceGroupId)
SELECT @SchJan, ag.AttendanceGroupId FROM dbo.AttendanceGroup ag WHERE ag.Name IN (N'A組 - 倉儲', N'B組 - 物流');

INSERT INTO dbo.ScheduleAllowedAttendanceGroup(ScheduleId, AttendanceGroupId)
SELECT @SchFeb, ag.AttendanceGroupId FROM dbo.AttendanceGroup ag WHERE ag.Name IN (N'A組 - 倉儲');

INSERT INTO dbo.ScheduleAllowedAttendanceGroup(ScheduleId, AttendanceGroupId)
SELECT @SchMar, ag.AttendanceGroupId FROM dbo.AttendanceGroup ag WHERE ag.Name IN (N'B組 - 物流', N'C組 - 客服');

INSERT INTO dbo.SchedulePosition(ScheduleId, PositionId)
SELECT @SchJan, p.PositionId FROM dbo.Position p WHERE p.Name IN (N'揀貨員', N'理貨員', N'包裝員');

INSERT INTO dbo.SchedulePosition(ScheduleId, PositionId)
SELECT @SchFeb, p.PositionId FROM dbo.Position p WHERE p.Name IN (N'揀貨員', N'包裝員');

INSERT INTO dbo.SchedulePosition(ScheduleId, PositionId)
SELECT @SchMar, p.PositionId FROM dbo.Position p WHERE p.Name IN (N'司機', N'分類員');

INSERT INTO dbo.ScheduleSupervisor(ScheduleId, SupervisorId) VALUES
    (@SchJan, @SupLiu),
    (@SchFeb, @SupLiu),
    (@SchMar, @SupLiu);

INSERT INTO dbo.ScheduleTag(ScheduleId, TagId) VALUES
    (@SchJan, @TagOT),
    (@SchJan, @TagNew),
    (@SchFeb, @TagOT);

PRINT 'Seed data 完成';
GO
