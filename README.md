# 派遣排班系統（shift-management）

純前端排班管理系統，以 HTML + Tailwind CSS + Vanilla JS 實作，所有資料儲存於瀏覽器 `localStorage`，無需後端服務。

---

## 近期更新（最近 12 次 Push）

以下整理目前 `main` 分支最近 12 筆已推送提交（`origin/main`）的重點改動：

| Commit | 類型 | 主要變更 | 影響檔案 |
|---|---|---|---|
| `ab19489` | fix | 修正假別組與假別選取空值邏輯，避免錯誤回填 | `shift-choose.html`, `shift-setting.html` |
| `2c7bfc2` | feat | 新增班表可用項目選取頁（班別/假別組/考勤組） | `shift-choose.html`, `shift-setting.html` |
| `8551338` | ui | 調整總覽圖例欄的邊距、邊框、陰影 | `index.html` |
| `2ac2696` | feat | 新增 allowed picker（班別/假別組/考勤組） | `shift-setting-new.html`, `shift-setting.html` |
| `6fce3e6` | ux | 更新部門/工作地標題，加入必填標記與驗證強化 | `shift-setting-new.html`, `shift-setting.html` |
| `4d0c3fc` | ui | 調整主管標題與標籤邏輯，提升介面一致性 | `index.html`, `shift-setting-new.html`, `shift-setting.html` |
| `4cf5f6f` | feat | 新增假別組/考勤組頁面的草稿保存與編輯流程 | `holiday-group.html`, `shift-group.html`, `shift-setting-new.html` |
| `90b51d7` | feat | 新增假別組設定頁（新增、編輯、日期管理） | `holiday-group.html`, `shift-setting.html` |
| `d7d6507` | feat | 新增考勤組設定頁（新增、編輯、人員管理） | `shift-group.html`, `shift-setting.html` |
| `b38b384` | ui | 調整班表標題顯示，新增「全部班表」選項 | `index.html` |
| `ce84e6c` | feat | 新增排班名稱自動生成功能（依年月） | `index.html` |
| `65500ba` | fix/refactor | 返回頁面時重讀 localStorage，並重構班表設定即時保存 | `index.html`, `shift-list.html`, `shift-setting.html` |

---

## 目錄

1. [頁面結構與導航](#頁面結構與導航)
2. [資料模型](#資料模型)
3. [核心邏輯](#核心邏輯)
   - [假日優先策略](#假日優先策略)
   - [考勤組自動排班](#考勤組自動排班)
   - [個人排班覆蓋](#個人排班覆蓋)
   - [加班時數計算](#加班時數計算)
   - [跨月班表顯示](#跨月班表顯示)
4. [色彩語義](#色彩語義)
5. [篩選器](#篩選器)
6. [資料持久化](#資料持久化)
7. [資料庫（MSSQL）](#資料庫mssql)

---

## 頁面結構與導航

```
shift-list.html          班表列表（入口）
    │
    ├─► shift-setting-new.html   新增班表（設定基本資訊、班別、假日、考勤組等）
    ├─► shift-setting.html       編輯既有班表（功能同上，額外有「複製班表」按鈕）
    │
index.html               班表總覽（主視圖，橫向日曆表格）
    │
    └─► personal-shift.html      個人排班（單一員工月曆，可點格子指派/覆蓋班別）
```

### shift-list.html — 班表列表

- 列出所有班表（名稱、分公司、起始/結束日期、天數、狀態）。
- 狀態判斷：
  - **即將開始**：今天 < 起始日
  - **進行中**：今天介於起始～結束日（含）
  - **已結束**：今天 > 結束日
- 支援名稱關鍵字搜尋。
- 操作：查看（導向 `index.html?index=N`）、設定（導向 `shift-setting.html?index=N`）、刪除。

### shift-setting-new.html / shift-setting.html — 排班設定

兩個檔案共享相同的功能區段：

| 區段 | 說明 |
|------|------|
| 基本資訊 | 班表名稱、起始/結束日期、分公司/分店/案場、部門/工作地 |
| 班別排班 | 新增/編輯班別（名稱、簡稱、起始/結束時間、休息時數、可加班時段） |
| 節假日設定 | 假別組管理（可新增多組、每組含多個日期）+ 彈性假期（個別日期） |
| 排班人員 | 考勤組管理（成員、排班型態、週班表設定、假日加班開關）+ 臨時人員搜尋加入 |
| 檢視人員（主管） | 設定可檢視此班表的主管名單 |
| 崗位、標籤 | 班表層級的崗位與標籤清單 |

`shift-setting.html` 額外有「**複製班表**」功能，將目前設定複製為新班表（只複製結構，不含個人指派）。

### index.html — 班表總覽

橫向日曆表格，每列為一名員工，每欄為一天。

- 標題列顯示日期 + 星期；**跨月班表**會在表格最上方加一列月份分組標題列，並在月份交界欄加垂直分隔線。
- 支援「上月 / 下月 / 今天」切換，切換後以 `viewOverride` 覆蓋顯示區間（不修改班表資料）。
- 點擊員工姓名或任一班表格，導向該員工的個人排班頁。
- 右上方統計卡：總人數、總工時、平均工時。

### personal-shift.html — 個人排班

以月曆呈現單一員工的班別狀態，支援點格子開啟 modal 指派/清除班別。

- URL 參數：`empId`、`scheduleIndex`、`start`、`end`
- 底部「個人化指派」區塊可批次設定假別組、考勤組（一次性套用）、崗位、標籤。
- 「**保留並套用**」：將新班別追加至既有指派（不重複）。
- 「**清除並套用**」：清除區間內原有指派後重新套用。
- 右上「儲存」將資料寫入 `localStorage`；「取消」回到上次儲存快照。

---

## 資料模型

### 全域資料 — `localStorage['shiftMgmt:global']`

```jsonc
{
  "__version": 13,           // 資料版本號，低於此版本時重置部分欄位

  // ── 班表列表 ──────────────────────────────────────────────
  "schedules": [
    {
      "name": "2026年1月排班",
      "start": "2026-01-01",
      "end": "2026-01-31",
      "branch": "總公司"     // 分公司/分店/案場
    }
  ],

  // ── 班別定義 ─────────────────────────────────────────────
  "shifts": [
    {
      "name": "早班",
      "shortName": "早",     // 總覽表格中顯示的簡稱
      "start": "08:00",
      "end": "17:00",
      "hours": 8,            // 實際計薪工時（扣除休息後）
      "rest": 1,             // 休息時數（小時）
      "otStart": "17:00",    // 可加班時段起始（選填）
      "otEnd": "20:00"       // 可加班時段結束（選填）
    }
  ],

  // ── 節假日 ───────────────────────────────────────────────
  "holidayGroups": {
    "台灣國定假日": ["2026-01-01", "2026-02-14", ...],
    "一例一休": ["2026-01-03", "2026-01-04", ...]   // 全年週六日
  },
  "individualHolidays": ["2026-01-20"],  // 彈性假期（個別日期）

  // ── 人員 ─────────────────────────────────────────────────
  "persons": [
    { "name": "王小明", "id": "EMP001" }
  ],
  "supervisors": ["劉經理"],

  // ── 考勤組 ───────────────────────────────────────────────
  "attendanceGroups": [
    {
      "name": "A組 - 倉儲",
      "members": ["EMP001", "EMP002"],
      "scheduleType": "auto",          // "auto" | "manual"
      "workOnHoliday": false,          // 假日是否仍排班
      "weekdayShifts": {               // 僅 auto 型態使用
        "mon": ["早班"], "tue": ["早班"],
        "wed": ["早班"], "thu": ["早班"],
        "fri": ["早班"], "sat": [], "sun": []
      },
      "punchLocations": ["倉儲中心"]   // 打卡地（選填）
    }
  ],

  // ── 其他分類資料 ──────────────────────────────────────────
  "branches": ["總公司", "北區分店", ...],
  "departments": ["管理部", "倉儲部", ...],
  "allPositions": ["揀貨員", "包裝員", ...],
  "positions": ["理貨員", "包裝員"],  // 本班表啟用崗位
  "tags": ["可加班", "新人", "夜班優先"],

  // ── UI 狀態（不跨頁保留） ──────────────────────────────────
  "selectedBranch": "",
  "selectedDepartment": ""
}
```

### 個人排班資料 — `localStorage['shiftMgmt:personal:{empId}']`

```jsonc
{
  "rangeStart": "2026-01-01",
  "rangeEnd": "2026-01-31",

  // 每日指派記錄
  "assignments": {
    "2026-01-05": {
      "type": "work",                   // "work" | "off"
      "shiftNames": ["早班"],           // 工作班別（複數可同日排）
      "source": "manual"                // "manual"：手動指派; 無此欄位表示自動填入
    },
    "2026-01-06": {
      "type": "off",
      "source": "manual"               // 手動指派休假
    }
  },

  "holidayGroups": ["台灣國定假日"],   // 個人適用的假別組
  "attendanceGroups": ["A組 - 倉儲"], // 套用考勤組（一次性套用用途）
  "shifts": ["早班", "午班"],          // 可排班別
  "positions": ["理貨員"],
  "tags": ["可加班"]
}
```

---

## 核心邏輯

### 假日優先策略

每日是否為「不可排班」日（`conflictHolidaySet`）的判斷優先序：

1. **使用者已勾選特定假別**（UI 篩選器）→ 僅以勾選之假別組/日期為準。
2. **未勾選**（預設）→ 所有假別組 + 彈性假期（`individualHolidays`）合集。

考勤組層級的「假日仍排班（`workOnHoliday`）」開關，可允許該組成員在假日仍顯示排班（以**假日加班**樣式呈現）。

### 考勤組自動排班

排班型態為 `auto` 時，依照 `weekdayShifts` 定義每週固定班次：

```
星期對照：sun / mon / tue / wed / thu / fri / sat
```

計算流程（`getShiftsForPersonOnDate`）：

1. 查有無個人排班覆蓋（`personal.assignments[dateStr]`） → 有則直接使用。
2. 查員工所屬考勤組；若型態為 `manual` 或無考勤組 → 空班。
3. 判斷該日是否為假日（`conflictHolidaySet`）：
   - 假日 + `workOnHoliday = false` → 空班。
   - 假日 + `workOnHoliday = true` → 按週排班，標記為**假日加班**。
4. 依 `weekdayShifts[DOW]` 回傳班別清單。

### 個人排班覆蓋

個人排班具有最高優先權，覆蓋考勤組自動排班結果：

| `type` | `source` | 考勤組假日？ | 顯示 |
|--------|----------|------------|------|
| `off` | `manual` | 任意 | 個人指派休假（藍底） |
| `off` | 無 | 為系統假日 | 系統休假（紅底） |
| `off` | 無 | 非系統假日 | 個人覆蓋休假（藍底） |
| `work` | 任意 | 任意 | 個人指派班別（藍底，優先顯示） |

「系統假日」定義：`individualHolidays` 或個人已勾選假別組中的日期。

### 加班時數計算

依**勞動基準法第 32 條**計算，於個人排班頁顯示：

| 指標 | 上限（一般） | 上限（延長，需工會/勞資會議同意） |
|------|------------|-------------------------------|
| 每月加班時數 | 46 h | 54 h |
| 連續 3 個月加班合計 | — | 138 h |
| 每日合計工時 | 12 h | — |

計算規則：

- **加班時數** = 日工時 − 8h（各日超出部分加總）。
- 每週 40h 上限：以 ISO 週（週一為首）累計；超過 40h 的班次在月曆中以**橙色「加」標籤**標示。
- 每日超過 12h 的格子以**紅框紅底**警示。
- 近 3 個月滾動計算：以目前檢視月份往前推 3 個月加總。

### 跨月班表顯示

當班表的 `start` 和 `end` 跨越月份時（`monthGroups.length > 1`）：

1. 在表格最頂部插入**月份分組標題列**，每月佔對應天數的 `colspan`。
2. 每月第一欄（表頭與所有資料格）加上 `border-left: 2px solid #94a3b8` 灰色垂直分隔線，清楚區隔月份邊界。
3. 單月班表（含「上月/下月/今天」切換後的月份視圖）不顯示此額外標題列。

---

## 色彩語義

| 情境 | 背景 | 文字 | 說明 |
|------|------|------|------|
| 班表排班 | `#dcfce7` (green-100) | `#166534` (green-800) | 考勤組自動排班（未被個人覆蓋） |
| 個人排班 | `#dbeafe` (blue-100) | `#1e40af` (blue-800) | 個人指派或個人覆蓋（含個人手動指派休假） |
| 假日加班 | `#ffedd5` (orange-100) | `#c2410c` (orange-700) | 假日仍排班，帶橙色邊框 |
| 休假 | `#fef2f2` (red-50) | `#dc2626` (red-600) | 系統假日不排班 |
| 今天 | 各色格底 | — | 藍色框線 `box-shadow: inset 0 0 0 2px #3b82f6` |
| 日超 12h | `#fff1f2` | — | 紅色邊框警示 |

---

## 篩選器

班表總覽（`index.html`）提供以下篩選器，可複合使用：

| 篩選器 | 類型 | 說明 |
|--------|------|------|
| 分公司/分店/案場 | 單選（可取消） | 依員工所屬分公司篩選 |
| 部門/工作地 | 單選（可取消） | 依員工所屬部門篩選 |
| 崗位 | 複選 | 依班表設定之崗位篩選 |
| 班別 | 複選 | 只顯示有被勾選班別的人員及日期 |
| 節假日 | 假別組（單選）+ 個別日期（複選） | 影響假日底色及 `conflictHolidaySet` |
| 考勤組 | 單選（可取消） | 僅顯示該考勤組成員 |
| 標籤 | 複選 | 依員工標籤篩選 |
| 搜尋 | 文字 | 姓名、員工編號模糊搜尋 |

已選條件顯示於「已選篩選條件」區塊，可點 × 逐一移除。

---

## 資料持久化

| `localStorage` 鍵 | 寫入時機 | 說明 |
|-------------------|----------|------|
| `shiftMgmt:global` | 班表設定儲存、總覽頁切換班表、個人排班返回前 | 全域設定（班表、班別、假日、人員、考勤組等） |
| `shiftMgmt:personal:{empId}` | 個人排班頁點「儲存」 | 單一員工的個人指派記錄 |

**版本控制**：`__version` 欄位目前為 `13`。載入時若儲存版本低於此值，自動重置 `attendanceGroups`、`holidayGroups`、`shifts` 為 Fallback 預設值，避免舊結構導致顯示錯誤。

**跨頁同步**：從個人排班返回總覽時，總覽頁監聽 `pageshow` 事件，若為 bfcache 恢復（`e.persisted`）則重新執行 `renderSchedule()`，確保個人排班變更即時反映。
---

## 資料庫（MSSQL）

提供與前端 `localStorage` 結構對應的 MSSQL 2022 schema，供未來後端整合或資料分析使用。

### 啟動

```bash
docker compose up -d           # 啟動 sqlserver (port 1433)
./db/init.sh                   # 等待就緒並建立 schema + seed 資料
```

預設 SA 密碼：`Shift@Pass2026`（可由環境變數 `MSSQL_SA_PASSWORD` 覆寫）。
連線字串範例：
`Server=localhost,1433;Database=ShiftManagement;User Id=sa;Password=Shift@Pass2026;TrustServerCertificate=True;`

### 對應關係

| 前端 (localStorage) | 資料表 |
|---|---|
| `persons[]` | `Employee` |
| `shifts[]` | `Shift` |
| `schedules[]` | `Schedule` (+ `SchedulePosition`) |
| `holidayGroups{}` / `individualHolidays[]` | `HolidayGroup` + `HolidayGroupDate` / `IndividualHoliday` |
| `attendanceGroups[]` | `AttendanceGroup` (+ `Member` / `Weekday` / `PunchLoc`) |
| `branches/departments/allPositions/tags/supervisors` | `Branch` / `Department` / `Position` / `Tag` / `Supervisor` |
| `shiftMgmt:personal:{empId}` | `PersonalShiftConfig` + `PersonalAssignment` + `PersonalSetting` |
| `__version` | `AppMeta` (Key=`DataVersion`) |

詳細 DDL 請見 [db/schema.sql](db/schema.sql)、種子資料 [db/seed.sql](db/seed.sql)。
