[English](#english) | 中文

# 从微软待办迁移到 Open To Do

微软待办将于 **2027 年 6 月 30 日** 停止服务。请在那之前把你的数据导出来。
本指南介绍三种导出方式，以及如何导入 Open To Do。

## 方法一：用 Microsoft Graph Explorer 导出（推荐，无需写代码）

Microsoft Graph Explorer 是微软官方的在线 API 测试工具，不用安装任何东西。

### 1. 打开 Graph Explorer 并登录

1. 打开 https://developer.microsoft.com/graph/graph-explorer
2. 点右上角 **Sign in**，用你的微软账号登录（就是待办用的那个账号）
3. 首次登录会要求授权：勾选 `Tasks.ReadWrite`（读写待办）后点接受

### 2. 导出所有列表

在地址栏输入并运行：

```
GET https://graph.microsoft.com/v1.0/me/todo/lists
```

返回的 JSON 里 `value` 数组就是你的全部列表，每个列表有 `id` 和 `displayName`。
把整段 JSON 另存为 `todo-lists.json`。

### 3. 逐个列表导出任务

对每个列表，取它的 `id`，运行：

```
GET https://graph.microsoft.com/v1.0/me/todo/lists/{id}/tasks
```

把每个列表的任务 JSON 保存下来。Open To Do 接受两种文件形态：

- **合并文件**：一个 JSON，形如
  ```json
  {
    "value": [
      { "displayName": "Tasks", "tasks": [ { "title": "...", "status": "notStarted", "importance": "high", "dueDateTime": { "dateTime": "2027-01-15T00:00:00" }, "body": { "content": "...", "contentType": "text" } } ] },
      { "displayName": "Groceries", "tasks": [ ... ] }
    ]
  }
  ```
- **单个列表文件**：每个文件一个列表对象 `{ "displayName": "...", "tasks": [...] }`

> 提示：Graph Explorer 返回的任务 JSON 默认一页最多 200 条；如果某个列表任务很多，
> 返回里会有 `@odata.nextLink`，跟着它继续取，直到取完。

### 4. 导入 Open To Do

1. 打开 Open To Do → 设置 → **导入**
2. 选择上面保存的 JSON 文件
3. 导入完成后会显示导入了多少任务、多少新列表；同名列表会自动合并

**字段映射**（Open To Do 如何理解 Graph 的字段）：

| Graph 字段 | Open To Do |
|---|---|
| `title` | 任务标题 |
| `status` = `completed` | 已完成 |
| `importance` = `high` | 重要（星标） |
| `dueDateTime.dateTime` | 截止日期 |
| `reminderDateTime.dateTime` | 提醒时间 |
| `body.content`（text 或 html） | 备注（html 会转纯文本） |
| `createdDateTime` / `completedDateTime` | 创建 / 完成时间 |

> 注意：微软待办的步骤（checklist items）是独立资源，Graph Explorer 单次导出不含它们。
> 如需步骤，请对每个任务再调 `GET .../tasks/{task-id}/checklistItems`，
> 或用方法三的 CSV 方式自行整理。Open To Do 的自有备份 JSON 支持步骤完整往返。

## 方法二：等微软官方导出工具（待发布）

微软宣布停用时承诺会提供官方导出工具。如该工具发布：

1. 按官方指引导出（预计为 JSON 或 CSV）
2. 若为 JSON：直接用 Open To Do 的导入功能导入（Graph 形态兼容）
3. 若为 CSV：按下面方法三的列格式整理后导入
4. 若官方工具导出的是其他格式，请在 GitHub 提 issue，我们会跟进支持

## 方法三：CSV 导入（备用）

把任务整理成 CSV，标题行必须是：

```
list,title,completed,important,due_date,note
```

- `list`：列表名（不存在会自动创建）
- `title`：任务标题（必填）
- `completed` / `important`：`true` / `false`（也接受 `1` / `0` / `yes` / `no`）
- `due_date`：`yyyy-MM-dd`，如 `2027-01-15`
- `note`：备注

示例：

```csv
list,title,completed,important,due_date,note
Tasks,Buy milk,false,true,2027-01-15,Oat milk
Groceries,Call mom,true,false,,
```

在 Open To Do 设置页点「导入」，选择该 CSV 文件即可。

## 常见问题

**导出的 JSON 里中文是乱码？**
Graph Explorer 返回的是 UTF-8，保存文件时选 UTF-8 编码即可；Open To Do 按 UTF-8 读取。

**导入后任务的列表名不对？**
检查 JSON 里列表的 `displayName` 是否正确；Open To Do 按 `displayName` 建列表。

**提醒时间导入后有时区偏差？**
Graph 的 `dateTime` 不带时区时按原值读取；建议导出时留意 `timeZone` 字段，
导入后在任务详情里核对一次提醒时间。

**微软账号登录不了 Graph Explorer？**
确认用的是待办绑定的微软账号；企业/学校账号可能需要管理员授权 `Tasks.ReadWrite`。

---

<a id="english"></a>

[中文](#从微软待办迁移到-open-to-do) | English

# Migrating from Microsoft To Do to Open To Do

Microsoft To Do retires on **June 30, 2027**. Export your data before then.
This guide covers three ways to export, and how to import into Open To Do.

## Option 1: Export with Microsoft Graph Explorer (recommended, no code)

Graph Explorer is Microsoft's official online API tool — nothing to install.

### 1. Open Graph Explorer and sign in

1. Go to https://developer.microsoft.com/graph/graph-explorer
2. Click **Sign in** (top right) with the Microsoft account you use for To Do
3. On first sign-in, consent to the `Tasks.ReadWrite` permission

### 2. Export all lists

Run this query:

```
GET https://graph.microsoft.com/v1.0/me/todo/lists
```

The `value` array in the response is all your lists, each with an `id` and
a `displayName`. Save the whole JSON as `todo-lists.json`.

### 3. Export the tasks of each list

For each list, take its `id` and run:

```
GET https://graph.microsoft.com/v1.0/me/todo/lists/{id}/tasks
```

Save each list's task JSON. Open To Do accepts two file shapes:

- **Combined file**: one JSON document like
  ```json
  {
    "value": [
      { "displayName": "Tasks", "tasks": [ { "title": "...", "status": "notStarted", "importance": "high", "dueDateTime": { "dateTime": "2027-01-15T00:00:00" }, "body": { "content": "...", "contentType": "text" } } ] },
      { "displayName": "Groceries", "tasks": [ ... ] }
    ]
  }
  ```
- **One file per list**: a single list object `{ "displayName": "...", "tasks": [...] }`

> Note: Graph Explorer returns at most 200 tasks per page. If a list has
> more, follow the `@odata.nextLink` in the response until you have them all.

### 4. Import into Open To Do

1. Open Open To Do → Settings → **Import**
2. Pick the JSON file you saved
3. A summary shows how many tasks and new lists were imported; lists with
   an existing name are merged into the existing list

**Field mapping** (how Open To Do reads Graph fields):

| Graph field | Open To Do |
|---|---|
| `title` | task title |
| `status` = `completed` | completed |
| `importance` = `high` | important (starred) |
| `dueDateTime.dateTime` | due date |
| `reminderDateTime.dateTime` | reminder |
| `body.content` (text or html) | note (html is converted to plain text) |
| `createdDateTime` / `completedDateTime` | created / completed time |

> Note: To Do checklist items (steps) are separate resources and are not
> included in a single Graph Explorer export. To bring them over, call
> `GET .../tasks/{task-id}/checklistItems` per task, or use the CSV route
> below. Open To Do's own backup JSON round-trips steps losslessly.

## Option 2: Wait for Microsoft's official export tool (not yet released)

When Microsoft announced the shutdown, it promised an official export tool.
If/when it ships:

1. Export with the official tool (expected: JSON or CSV)
2. JSON: import it directly with Open To Do (Graph shape is supported)
3. CSV: arrange it into the column format in Option 3 and import it
4. If the tool exports another format, open a GitHub issue and we will add
   support for it

## Option 3: CSV import (fallback)

Arrange your tasks as CSV with this header row:

```
list,title,completed,important,due_date,note
```

- `list`: list name (created automatically if it does not exist)
- `title`: task title (required)
- `completed` / `important`: `true` / `false` (`1` / `0` / `yes` / `no`
  also work)
- `due_date`: `yyyy-MM-dd`, e.g. `2027-01-15`
- `note`: note text

Example:

```csv
list,title,completed,important,due_date,note
Tasks,Buy milk,false,true,2027-01-15,Oat milk
Groceries,Call mom,true,false,,
```

In Open To Do, go to Settings → Import and pick the CSV file.

## FAQ

**The exported JSON shows garbled Chinese characters?**
Graph Explorer returns UTF-8; save the file with UTF-8 encoding and Open To
Do will read it correctly.

**List names are wrong after import?**
Check the `displayName` of each list in the JSON; Open To Do creates lists
from `displayName`.

**Reminder times are off by a timezone?**
Graph `dateTime` values without a timezone are read as-is; check the
`timeZone` field in the export and verify reminder times in the task details
after import.

**Can't sign in to Graph Explorer with my Microsoft account?**
Make sure you use the account bound to To Do; work/school accounts may need
an admin to grant `Tasks.ReadWrite`.
