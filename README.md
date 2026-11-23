[English](#english) | 中文

# Open To Do — 开源微软待办替代品

> **微软待办（Microsoft To Do）将于 2027 年 6 月 30 日停止服务，个人账号没有官方替代品。**
> Open To Do 是一个免费、开源、本地优先的待办应用：Windows / Android / iOS / Linux 四端同一份代码，
> 界面与微软待办高度一致，老用户上手零成本；数据只保存在本机，无需账号、无需服务器。

## 功能

- **智能列表**：我的一天、重要、已计划、全部任务，数量实时显示
- **自定义列表**：新建、重命名、删除、每列表可选颜色
- **任务**：底部快速添加、圆圈勾选完成（带动画）、星标重要、删除
- **任务详情**：步骤（子任务）、截止日期（今天/明天/自选/清除）、提醒（日期+时间）、重复（每天/工作日/每周/每月/每年）、多行备注、加入“我的一天”、创建时间、删除任务
- **我的一天**：每天自动重置——前一天加入的任务会自动移出
- **已计划**：按截止日期分组（已逾期 / 今天 / 明天 / 本周 / 以后）
- **搜索**：按标题、备注全文搜索全部任务
- **排序**：按重要程度、截止日期、创建日期、字母顺序
- **导入/导出**：完整备份 JSON；可导入微软待办 Graph JSON 与 CSV，详见 [迁移指南](docs/MIGRATION.md)
- **设置**：浅色/深色/跟随系统、每周第一天、语言切换、清除已完成
- **16 种界面语言**：English、简体中文、繁體中文、Español、हिन्दी、العربية、Português、Français、Deutsch、Русский、日本語、한국어、Italiano、Türkçe、Bahasa Indonesia、Tiếng Việt，应用内一键切换（含阿拉伯语 RTL 从右到左布局）

## 界面

界面对标微软待办：微软蓝 `#0078D4` 主色、左侧导航栏、圆圈勾选、星标、太阳图标、宽屏右侧详情面板。

> 截图待补充（欢迎提交 PR）。

## 快速开始

```bash
git clone https://github.com/Anathleticbicyclist/open-todo.git
cd open-todo
flutter pub get
flutter run            # 运行到当前设备
```

### 打包各平台

```bash
flutter build windows --release   # Windows
flutter build apk --release       # Android APK
flutter build ios --release --no-codesign   # iOS（需 macOS + Xcode）
flutter build linux --release     # Linux
```

GitHub Actions 会在每次推送到 `main` 时自动构建四个平台的 Release（见 `.github/workflows/build.yml`），
构建产物在 Actions 页下载。

## 从微软待办迁移

微软待办停止服务前，请先把数据导出来，再导入 Open To Do。
完整步骤见 **[docs/MIGRATION.md](docs/MIGRATION.md)**：

1. 用 Microsoft Graph Explorer 导出你的列表与任务（JSON）
2. 在 Open To Do 设置页点「导入」，选择该 JSON 文件
3. 也支持 CSV 导入（`list,title,completed,important,due_date,note`）

## 数据与隐私

- 所有数据存在本机 SQLite（`open_todo.db`），不联网、不上传、不设账号
- 提醒目前只在应用内显示日期时间，**v1 不发送系统通知**（见路线图）
- 导出备份为 JSON 文件，可随时带走

## 路线图

- [ ] 系统通知（到点提醒）
- [ ] 可选的云同步（WebDAV / 自建服务器，默认关闭）
- [ ] 附件（图片、文件）
- [ ] 任务分组与更多智能列表
- [ ] 桌面小部件

## 许可证

MIT，见 [LICENSE](LICENSE)。

---

<a id="english"></a>

[中文](#open-to-do--开源微软待办替代品) | English

# Open To Do — an open-source Microsoft To Do replacement

> **Microsoft To Do retires on June 30, 2027, and personal accounts get no
> official replacement.** Open To Do is a free, open-source, local-first
> to-do app: one codebase for Windows / Android / iOS / Linux, a UI that
> closely matches Microsoft To Do so existing users feel at home, and data
> that stays on your device — no account, no server.

## Features

- **Smart lists**: My Day, Important, Planned, All Tasks, with live counts
- **Custom lists**: create, rename, delete, pick a colour per list
- **Tasks**: quick add at the bottom, animated circular checkbox, star for
  Important, delete
- **Task details**: steps (subtasks), due date (Today / Tomorrow / pick a
  date / clear), reminder (date + time), repeat (Daily / Weekdays / Weekly /
  Monthly / Yearly), multi-line note, "Add to My Day", created date, delete
- **My Day**: resets daily — tasks added on a previous day drop out
  automatically
- **Planned**: grouped by due date (Overdue / Today / Tomorrow / This week /
  Later)
- **Search**: full-text search across titles and notes
- **Sorting**: by importance, due date, creation date, alphabetically
- **Import / Export**: full JSON backup; imports Microsoft To Do Graph JSON
  and CSV — see the [migration guide](docs/MIGRATION.md)
- **Settings**: Light / Dark / System theme, first day of week, language
  switcher, clear completed
- **16 UI languages**: English, 简体中文, 繁體中文, Español, हिन्दी, العربية,
  Português, Français, Deutsch, Русский, 日本語, 한국어, Italiano, Türkçe,
  Bahasa Indonesia, Tiếng Việt — switch instantly in the app (Arabic renders
  right-to-left)

## Screenshots

The UI follows Microsoft To Do closely: Microsoft blue `#0078D4`, left
navigation sidebar, circular checkboxes, stars, sun icon, detail pane on
wide screens.

> Screenshots to be added (PRs welcome).

## Quick start

```bash
git clone https://github.com/Anathleticbicyclist/open-todo.git
cd open-todo
flutter pub get
flutter run            # run on the current device
```

### Build each platform

```bash
flutter build windows --release   # Windows
flutter build apk --release       # Android APK
flutter build ios --release --no-codesign   # iOS (needs macOS + Xcode)
flutter build linux --release     # Linux
```

GitHub Actions builds all four platforms on every push to `main`
(see `.github/workflows/build.yml`); download the artifacts from the
Actions page.

## Migrating from Microsoft To Do

Export your data before To Do shuts down, then import it into Open To Do.
Full steps in **[docs/MIGRATION.md](docs/MIGRATION.md)**:

1. Export your lists and tasks as JSON with Microsoft Graph Explorer
2. In Open To Do, go to Settings → Import and pick that JSON file
3. CSV import is also supported
   (`list,title,completed,important,due_date,note`)

## Data & privacy

- Everything lives in a local SQLite database (`open_todo.db`); no network,
  no uploads, no account
- Reminders currently show their date/time inside the app; **v1 does not send
  OS notifications** (see roadmap)
- Export a JSON backup any time and take your data with you

## Roadmap

- [ ] OS notifications (remind at the set time)
- [ ] Optional cloud sync (WebDAV / self-hosted, off by default)
- [ ] Attachments (images, files)
- [ ] Task groups and more smart lists
- [ ] Home-screen widgets

## License

MIT — see [LICENSE](LICENSE).
