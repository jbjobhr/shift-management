# Shift Management Backend API 規格（v1）

本文件提供後端實作所需 API 規格，目標是逐步讓前端從 localStorage 過渡到 API + DB。

## 1. 設計目標

1. 與現行前端資料結構相容（`shiftMgmt:global`、`shiftMgmt:personal:{empId}`）。
2. 提供「整包同步」端點，先降低改造成本。
3. 保留未來擴充成細粒度 CRUD 的空間。

## 2. 基本約定

- Base URL: `/api/v1`
- Content-Type: `application/json; charset=utf-8`
- 時區: 日期使用 `YYYY-MM-DD`，時間使用 `HH:mm`，時間戳使用 ISO 8601 UTC（例：`2026-05-22T09:30:00Z`）
- 字串比對: 名稱欄位建議先 `trim()`，空字串視為 `null`

### 2.1 熱區 / 冷區定義

- 熱區: 高頻讀寫、使用者操作時常變動，需優先低延遲與即時一致性。
- 冷區: 低頻變動、以設定或字典資料為主，可接受較高快取比例。

資料分類表:

| 資料類型 | 區域 | 說明 |
|---|---|---|
| personal.assignments | 熱區 | 個人每日班別指派，最常被修改 |
| personal.settings | 熱區 | 個人化套用結果（假別組/考勤組/班別/崗位/標籤） |
| schedules | 溫熱區（偏熱） | 月度班表設定，更新頻率中等 |
| attendanceGroups | 溫熱區（偏熱） | 組員與週班表會調整，但非每日 |
| shifts | 冷區 | 班別模板，相對穩定 |
| holidayGroups / individualHolidays | 冷區 | 假日資料低頻更新 |
| dictionary（branches/departments/positions/tags/supervisors/punchLocations） | 冷區 | 字典資料，低頻更新 |

## 3. 統一回應格式

### 成功

```json
{
	"ok": true,
	"data": {},
	"meta": {
		"requestId": "a8f8cb9b-74e9-4f0f-99e8-3cd13a54b4f2",
		"serverTime": "2026-05-22T09:30:00Z"
	}
}
```

### 失敗

```json
{
	"ok": false,
	"error": {
		"code": "VALIDATION_ERROR",
		"message": "Payload validation failed",
		"details": [
			{
				"field": "schedules[0].start",
				"reason": "Invalid date format"
			}
		]
	},
	"meta": {
		"requestId": "ca7dd668-9a2f-4f66-a94b-0e2f5d8cf8ae",
		"serverTime": "2026-05-22T09:30:00Z"
	}
}
```

## 4. API 清單

### 4.1 Health Check

- Method: `GET`
- Path: `/health`
- 用途: 服務/資料庫健康檢查
- 資料區域: 系統狀態（不分熱冷）

Response `200`:

```json
{
	"ok": true,
	"data": {
		"status": "healthy",
		"db": "up"
	}
}
```

### 4.2 取得全域資料

- Method: `GET`
- Path: `/global`
- 用途: 回傳前端可直接覆蓋 `shiftMgmt:global` 的資料
- 資料區域: 混合（冷區為主，含部分溫熱區）
- 區域明細:
	- 冷區: dictionary、shifts、holidayGroups、individualHolidays
	- 溫熱區: schedules、attendanceGroups
- 快取建議: 伺服器端請將冷區與溫熱區分段組裝（cold cached + warm live/short cache），避免把整包 `/global` 以長 TTL 快取。

Response `200`:

```json
{
	"ok": true,
	"data": {
		"version": 13,
		"global": {
			"__version": 13,
			"schedules": [],
			"shifts": [],
			"holidayGroups": {},
			"individualHolidays": [],
			"persons": [],
			"supervisors": [],
			"attendanceGroups": [],
			"branches": [],
			"departments": [],
			"allPositions": [],
			"positions": [],
			"tags": [],
			"selectedBranch": "",
			"selectedDepartment": ""
		}
	}
}
```

### 4.3 全域同步（整包）

- Method: `POST`
- Path: `/sync/global`
- 用途: 將前端全域資料一次 upsert 到資料庫
- 交易要求: 單一 transaction
- 資料區域: 混合同步（冷區 + 溫熱區）
- 建議: 以批次任務/手動儲存觸發，不建議高頻連續呼叫

Request:

```json
{
	"version": 13,
	"dictionary": {
		"branches": ["總公司"],
		"departments": ["倉儲部"],
		"positions": ["揀貨員", "理貨員"],
		"tags": ["可加班"],
		"supervisors": ["劉經理"],
		"punchLocations": ["總公司", "倉儲中心"]
	},
	"persons": [
		{
			"id": "EMP001",
			"name": "王小明",
			"branch": "總公司",
			"department": "倉儲部",
			"isActive": true
		}
	],
	"shifts": [
		{
			"name": "早班",
			"shortName": "早",
			"start": "08:00",
			"end": "17:00",
			"crossDay": false,
			"hours": 8,
			"rest": 1,
			"otStart": "17:00",
			"otEnd": "20:00"
		}
	],
	"holidayGroups": [
		{
			"name": "台灣國定假日",
			"dates": ["2026-01-01", "2026-02-28"]
		}
	],
	"individualHolidays": ["2026-01-20"],
	"attendanceGroups": [
		{
			"name": "A組 - 倉儲",
			"scheduleType": "auto",
			"workOnHoliday": false,
			"members": ["EMP001"],
			"punchLocations": ["倉儲中心"],
			"weekdayShifts": {
				"mon": ["早班"],
				"tue": ["早班"],
				"wed": ["早班"],
				"thu": ["早班"],
				"fri": ["早班"],
				"sat": [],
				"sun": []
			}
		}
	],
	"schedules": [
		{
			"name": "2026年1月排班",
			"start": "2026-01-01",
			"end": "2026-01-31",
			"branch": "總公司",
			"department": "倉儲部",
			"positions": ["揀貨員"],
			"supervisors": ["劉經理"],
			"tags": ["可加班"],
			"allowedShiftNames": ["早班"],
			"allowedHolidayGroupNames": ["台灣國定假日"],
			"allowedAttendanceGroupNames": ["A組 - 倉儲"]
		}
	]
}
```

Response `200`:

```json
{
	"ok": true,
	"data": {
		"version": 13,
		"updatedAt": "2026-05-22T09:30:00Z",
		"stats": {
			"employees": 5,
			"shifts": 3,
			"attendanceGroups": 3,
			"schedules": 3
		}
	}
}
```

### 4.4 取得個人資料

- Method: `GET`
- Path: `/personal/{employeeId}`
- 用途: 回傳前端可直接覆蓋 `shiftMgmt:personal:{empId}` 的資料
- 資料區域: 熱區
- 建議: 可做短 TTL 快取（例如 5~30 秒）或依 employeeId 精準失效

Response `200`:

```json
{
	"ok": true,
	"data": {
		"employeeId": "EMP001",
		"personal": {
			"rangeStart": "2026-01-01",
			"rangeEnd": "2026-01-31",
			"assignments": {
				"2026-01-05": {
					"type": "work",
					"shiftNames": ["早班"],
					"source": "manual"
				}
			},
			"holidayGroups": ["台灣國定假日"],
			"attendanceGroups": ["A組 - 倉儲"],
			"shifts": ["早班"],
			"positions": ["理貨員"],
			"tags": ["可加班"]
		}
	}
}
```

### 4.5 個人同步（整包）

- Method: `POST`
- Path: `/sync/personal`
- 用途: 將單一員工個人資料一次 upsert 到資料庫
- 交易要求: 單一 transaction
- 資料區域: 熱區
- 建議: 優先即時寫入 DB，成功後主動失效 `/personal/{employeeId}` 快取

Request:

```json
{
	"employeeId": "EMP001",
	"rangeStart": "2026-01-01",
	"rangeEnd": "2026-01-31",
	"assignments": [
		{
			"date": "2026-01-05",
			"type": "work",
			"shiftNames": ["早班"],
			"source": "manual"
		},
		{
			"date": "2026-01-06",
			"type": "off",
			"shiftNames": [],
			"source": "manual"
		}
	],
	"settings": {
		"holidayGroups": ["台灣國定假日"],
		"attendanceGroups": ["A組 - 倉儲"],
		"shifts": ["早班"],
		"positions": ["理貨員"],
		"tags": ["可加班"]
	}
}
```

Response `200`:

```json
{
	"ok": true,
	"data": {
		"employeeId": "EMP001",
		"updatedAt": "2026-05-22T09:35:00Z",
		"assignmentCount": 2
	}
}
```

## 5. 驗證規則（必要）

### 5.1 共用

1. `name` 類欄位不得為空字串。
2. 日期必須符合 `YYYY-MM-DD`。
3. 時間必須符合 `HH:mm`。
4. 陣列可為空，但不可為 `null`（若前端送 `null`，建議轉空陣列）。

### 5.2 `/sync/global`

1. `version` 必須為正整數。
2. `scheduleType` 只允許 `auto` 或 `manual`。
3. `weekdayShifts` key 只允許 `sun|mon|tue|wed|thu|fri|sat`。
4. `schedules[].start <= schedules[].end`。

### 5.3 `/sync/personal`

1. `employeeId` 必填且需存在。
2. `rangeStart <= rangeEnd`。
3. `assignments[].type` 只允許 `work|off`。
4. `type = off` 時允許 `shiftNames` 空陣列；`type = work` 時 `shiftNames` 至少 1 筆。

## 6. 錯誤碼建議

| HTTP | code | 說明 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | 欄位格式/規則錯誤 |
| 404 | `EMPLOYEE_NOT_FOUND` | 個人同步找不到員工 |
| 409 | `CONFLICT` | 版本衝突或 optimistic lock 失敗 |
| 422 | `FK_RESOLVE_FAILED` | 名稱無法解析成 FK |
| 500 | `INTERNAL_ERROR` | 未預期錯誤 |

## 7. 實作流程（後端）

### 7.1 `/sync/global` 建議順序（同一 transaction）

1. Upsert 字典表（Branch/Department/Position/Tag/Supervisor/PunchLocation）。
2. Upsert Employee（解析 branch/department FK）。
3. Upsert Shift（自然鍵 `Name`）。
4. Upsert HolidayGroup，並重建 HolidayGroupDate。
5. 同步 IndividualHoliday。
6. Upsert AttendanceGroup，並重建 Member/PunchLoc/Weekday。
7. Upsert Schedule，並重建 Position/Supervisor/Tag。
8. 重建 ScheduleAllowedShift/HolidayGroup/AttendanceGroup。
9. Upsert AppMeta 的 `DataVersion`。

### 7.2 `/sync/personal` 建議順序（同一 transaction）

1. 驗證員工存在。
2. Upsert PersonalShiftConfig。
3. 刪除區間內舊 PersonalAssignment。
4. 寫入新 PersonalAssignment（`off` 用 `ShiftId = NULL`）。
5. 清空舊 PersonalSetting。
6. 依 settings 重建 holidayGroup/attendanceGroup/shift/position/tag。

## 8. 版本與相容策略

1. 後端維護 `DataVersion`，與前端 `__version` 對齊。
2. 新增欄位時採向後相容：
	 - Request 未帶欄位時套預設值。
	 - Response 新欄位不影響舊版前端。
3. 建議在同步 API 支援 `clientUpdatedAt`（可選）以做 optimistic lock。

## 8.1 熱區與冷區處理規則（後端實作）

1. 熱區資料（personal.*）
	- 寫入策略: 以 DB 為準，請求成功即落盤。
	- 併發策略: 建議 optimistic lock 或以 employeeId 做序列化更新。
	- 快取策略: 可短暫快取，但更新後必須立即失效。
2. 溫熱區資料（schedules、attendanceGroups）
	- 寫入策略: 可接受批次更新，但仍需 transaction 保證一致性。
	- 快取策略: 可中短 TTL（例如 1~5 分鐘），更新後做 key 級失效。
3. 冷區資料（dictionary、shifts、holidayGroups）
	- 寫入策略: 低頻更新，建議透過管理後台或明確保存操作觸發。
	- 快取策略: 可較長 TTL（例如 10~60 分鐘），並以版本號控制失效。

## 8.2 冷區快取加速方案（建議採用）

1. 快取層
	- 優先使用 Redis（多節點可共享）；單機開發可用 process memory。
	- 快取範圍: dictionary、shifts、holidayGroups、individualHolidays。
2. 快取 key 設計
	- `sm:v1:cold:dictionary:{version}`
	- `sm:v1:cold:shifts:{version}`
	- `sm:v1:cold:holidays:{version}`
	- 若回傳整包 global，可用 `sm:v1:global:cold-part:{version}`
3. TTL 建議
	- 冷區: 1800~3600 秒（30~60 分鐘）。
	- 溫熱區: 60~300 秒。
	- 熱區: 不建議長 TTL；若要快取，建議 <= 30 秒且強制失效。
4. 失效策略
	- `/sync/global` 成功後，刪除所有 cold key 或遞增 `DataVersion` 讓舊 key 自然失效。
	- 若採版本 key，建議以 `DataVersion` 當版本來源，避免逐 key 刪除遺漏。
5. API 回應標頭建議（GET）
	- 冷區資料: `Cache-Control: public, max-age=300, stale-while-revalidate=600`
	- 另加 `ETag`（內容 hash 或 version）支援 `If-None-Match`，可回 `304 Not Modified`。
6. 一致性原則
	- 熱區正確性優先、冷區效能優先。
	- 冷區允許短時間最終一致，但不可影響排班結果正確性（排班計算以最新 DB 資料為準）。

## 9. MVP 建議（先上線）

第一階段先實作以下 5 支即可支撐前端改造：

1. `GET /api/v1/health`
2. `GET /api/v1/global`
3. `POST /api/v1/sync/global`
4. `GET /api/v1/personal/{employeeId}`
5. `POST /api/v1/sync/personal`

第二階段再拆分細粒度 CRUD（例如 schedules/shifts/attendance-groups）。

