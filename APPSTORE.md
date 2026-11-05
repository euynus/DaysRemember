# App Store 提交准备 · 时光 (Days Remember)

> 草稿。营销文案可按需修改；隐私问卷与审核备注为依据 App 实际行为整理，可直接使用。

## 基本信息

- **名称**：主屏幕上显示「时光」（`CFBundleDisplayName`）；App Store 名称、副标题与其他文案见下文「商店文案」
- **分类**：生活 / 效率
- **Bundle ID**：`dev.gooday.days`（Widget：`.widget`）
- **版本 / 构建号**：版本取 `project.yml` 的 `MARKETING_VERSION`（现为 1.0.1），App 与小组件共用；构建号由 `scripts/archive.sh` 按提交数生成，每次从新的提交上传都会更大
- **支持设备**：iPhone，竖屏，iOS 26+
- **语言**：简体中文、繁體中文、English

## 网址

产品网站在 `docs/`，按 `wrangler.jsonc` 作为静态文件发布到 `days.gooday.dev`（没有构建步骤）：Worker 连上 GitHub 后推送 `main` 即自动部署，否则在仓库里运行 `npx wrangler deploy`。隐私政策与支持页面和产品页一样每种语言一页：简体在根路径，繁體和英文在 `zh-Hant/`、`en/` 下。

| 字段 | 简体中文 | 繁體中文 | English |
|---|---|---|---|
| 隐私政策网址（必填） | `https://days.gooday.dev/privacy/` | `…/zh-Hant/privacy/` | `…/en/privacy/` |
| 支持网址（必填） | `https://days.gooday.dev/support/` | `…/zh-Hant/support/` | `…/en/support/` |
| 营销网址（可选） | `https://days.gooday.dev/` | `…/zh-Hant/` | `…/en/` |

App 内「我的 › 关于」的「隐私政策」「帮助与反馈」打开同样的页面（`SettingsView.siteURL`）。换域名时两处一起改。

## 商店文案

> 依据产品网站（`docs/`）与 App 里的实际功能和界面用词写成；功能或网站文案改了，这里一起改。每个字段放在一个代码块里，直接复制到 App Store Connect 对应语言的同名字段。

- **长度上限**：名称、副标题各 30 字符，宣传文本 170，关键词 100，描述 4000。下面的草稿都在上限内（`python3` 数过）。
- **名称**全局唯一，单独的「时光」多半已被占用，所以名称带上了「纪念日倒数」；它也是搜索词。备选名称也被占用时，再换一个组合，主屏幕上显示的始终是「时光」。
- **关键词**用英文逗号分隔、逗号后不加空格；名称和副标题里的词已经会被搜索到，关键词里不再重复。关键词按重要程度排列，App Store Connect 提示超长时从末尾删。中文两种语言的末尾带上英文的 anniversary、countdown，方便在中国大陆和台湾的商店里用英文搜到。没有用「倒数日」「Days Matter」这类其他 App 的名称（审核指南 2.3.7）。
- **描述**里不写价格（商店页会显示）和其他平台。宣传文本可以随时修改、不用审核；其余字段随版本提交审核。

### 简体中文

**名称**（备选：时光 · 纪念日与倒计时）

```text
时光 · 纪念日倒数
```

**副标题**

```text
温柔记住每一个重要的日子
```

**宣传文本**

```text
无论是结婚纪念日、宝宝降生、一场期待已久的旅行，还是重要的考试倒数，都可以放进主屏幕与锁屏小组件。支持公历与农历重复、贴心提前提醒，无账号、无广告、不收集任何数据。
```

**关键词**

```text
倒计时,农历,生日,恋爱,在一起,情侣,结婚,宝宝,周年,节气,考试,考研,旅行,假期,提醒,小组件,锁屏,日历,正数,天数,节日,百日,分享卡片,anniversary,countdown
```

**描述**

```text
「时光」帮你温柔记住每一个重要的日子：无论是结婚纪念日、宝宝降生、一场期待已久的旅行，还是重要的考试倒数。未来的满怀期待，走过的温柔回望。

【将至与已过】
首页分为两面。「将至」为即将到来的日子倒数，置顶与临近的事项一目了然；每年重复的纪念日刚过去的一周内，仍会留在首页，方便你随时记下当天的故事。只发生一次的日子在跨过当天后会自动移入「已过」，一天天为你累积走过的时光。

【整数纪念】
「已过」里的日子会自动预告下一个值得庆祝的里程碑：1000 天内每逢百天、此后每满 500 天，以及每一个整年周年，让平淡的日常也闪闪发光。

【农历与节气】
生日与纪念日支持按公历或农历每年重复。内置日历清晰标注农历日期、二十四节气与传统节日，完整涵盖 1900 至 2100 年。

【轻点切换单位】
在日子详情页轻点天数，即可在天、周、月、小时之间自由切换。下方时间轴清晰罗列上一次与下一次周年，或下一个整数纪念节点。

【贴心提醒】
支持提前 7 天、3 天、1 天或当天提醒，提醒时间由你决定，每个日子还能单独定制。你也可以分别开启晨间的「每日问候」，或让「时光回忆」在已过日子的周年当天带你回望那一天。

【封面与分类】
每个日子都是一张带有分类色彩的温润卡片。你可以换上珍藏的照片，或从 12 幅手绘感扁平插画中挑选；新建日子时也会按分类自动配好相衬的封面。除了内置的爱情、家人、旅行、工作、生活，还可以在「我的」里创建专属分类，自由搭配图标与 5 种柔和色系。

【桌面与锁屏小组件】
提供小、中、大三种尺寸的主屏幕卡片，以及一次纵览多项日程的「日子列表」与三款锁屏小组件。单日小组件可指定特定日子，也可自动跟随置顶事项。

【快捷入口与 Siri】
支持从控制中心或长按主屏幕图标一键新建日子；无需打开 App，直接问问 Siri「某个日子还有几天」就能即刻获知。

【分享卡片】
内置照片、手记、极简、双栏四款排版模板，一键导出 3:4 竖版纪念卡片，方便保存到相册或分享给重要的人。个人笔记默认隐藏，仅在你勾选时才会展示在卡片上。

【iCloud 同步与备份】
日子、分类与照片可通过你个人的 iCloud 在多台设备间私密同步，也可以选择仅保存在本机。误删的日子会在「最近删除」中保留 30 天；多设备修改同一日子产生冲突时，被替换的版本也会在「同步保留版本」中留存 30 天，随时可以恢复。同时支持导出完整备份文件，换机迁移更安心。

【隐私承诺】
不收集任何数据。你的日子、照片与设置只保存在你的设备上（开启同步时保存在你个人的 iCloud 私有空间中），绝不经过任何第三方服务器，开发者也无法访问。无需注册账号，无广告，无追踪，无第三方 SDK。

支持简体中文、繁體中文和 English，可在「我的 › 语言」中随时切换。倒数计算与提醒时间均自动跟随设备当前时区。
```

### 繁體中文

**名稱**（備選：時光 · 紀念日與倒數計時）

```text
時光 · 紀念日倒數
```

**副標題**

```text
溫柔記住每一個重要的日子
```

**宣傳文字**

```text
無論是結婚紀念日、寶寶誕生、一場期待已久的旅行，還是重要的考試倒數，都可以放進主畫面與鎖定畫面小工具。支援國曆與農曆重複、貼心提前提醒，無帳號、無廣告、不收集任何資料。
```

**關鍵字**

```text
倒數計時,農曆,生日,戀愛,在一起,情侶,結婚,寶寶,週年,節氣,考試,旅行,假期,提醒,小工具,鎖定畫面,日曆,正數,天數,節日,百日,分享卡片,anniversary,countdown
```

**描述**

```text
「時光」幫你溫柔記住每一個重要的日子：無論是結婚紀念日、寶寶誕生、一場期待已久的旅行，還是重要的考試倒數。未來的滿懷期待，走過的溫柔回望。

【將至與已過】
首頁分為兩面。「將至」為即將到來的日子倒數，置頂與臨近的事項一目了然；每年重複的紀念日剛過去的一週內，仍會留在首頁，方便你隨時記下當天的故事。只發生一次的日子在跨過當天後會自動移入「已過」，一天天為你累積走過的時光。

【整數紀念】
「已過」裡的日子會自動預告下一個值得慶祝的里程碑：1000 天內每逢百天、此後每滿 500 天，以及每一個整年週年，讓平淡的日常也閃閃發光。

【農曆與節氣】
生日與紀念日支援按國曆或農曆每年重複。內建日曆清晰標註農曆日期、二十四節氣與傳統節日，完整涵蓋 1900 至 2100 年。

【輕點切換單位】
在日子詳情頁輕點天數，即可在天、週、月、小時之間自由切換。下方時間軸清晰羅列上一次與下一次週年，或下一個整數紀念節點。

【貼心提醒】
支援提前 7 天、3 天、1 天或當天提醒，提醒時間由你決定，每個日子還能單獨自訂。你也可以分別開啟晨間的「每日問候」，或讓「時光回憶」在已過日子的週年當天帶你回望那一天。

【封面與分類】
每個日子都是一張帶有分類色彩的溫潤卡片。你可以換上珍藏的照片，或從 12 幅手繪感扁平插圖中挑選；新增日子時也會依分類自動配好相襯的封面。除了內建的愛情、家人、旅行、工作、生活，還可以在「我的」裡建立專屬分類，自由搭配圖示與 5 種柔和色系。

【主畫面與鎖定畫面小工具】
提供小、中、大三種尺寸的主畫面卡片，以及一次縱覽多項日程的「日子列表」與三款鎖定畫面小工具。單一日子小工具可指定特定日子，也可自動跟隨置頂事項。

【快捷入口與 Siri】
支援從控制中心或長按主畫面圖示一鍵新增日子；無需打開 App，直接問問 Siri「某個日子還有幾天」就能即刻獲知。

【分享卡片】
內建照片、手記、極簡、雙欄四款排版範本，一鍵匯出 3:4 直式紀念卡片，方便儲存到相簿或分享給重要的人。個人筆記預設隱藏，僅在你勾選時才會顯示在卡片上。

【iCloud 同步與備份】
日子、分類與照片可透過你個人的 iCloud 在多台裝置間私密同步，也可以選擇僅儲存在本機。誤刪的日子會在「最近刪除」中保留 30 天；多裝置修改同一日子產生衝突時，被取代的版本也會在「同步保留版本」中留存 30 天，隨時可以還原。同時支援匯出完整備份檔案，換機轉移更安心。

【隱私承諾】
不收集任何資料。你的日子、照片與設定只儲存在你的裝置上（開啟同步時儲存在你個人的 iCloud 私有空間中），絕不經過任何第三方伺服器，開發者也無法存取。無需註冊帳號，無廣告，無追蹤，無第三方 SDK。

支援簡體中文、繁體中文和 English，可在「我的 › 語言」中隨時切換。倒數計算與提醒時間均自動跟隨裝置目前時區。
```

### English

**Name** (fallback: Days Remember: Countdown)

```text
Days Remember
```

**Subtitle**

```text
Anniversaries and countdowns
```

**Promotional text**

```text
Keep wedding anniversaries, baby milestones, trips, and exams in view. Repeat by Gregorian or lunar calendar, add Home and Lock Screen widgets, and get gentle reminders.
```

**Keywords**

```text
birthday,lunar,chinese,calendar,widget,reminder,since,until,wedding,baby,love,dating,exam,trip
```

**Description**

```text
Days Remember gently keeps track of the days that matter: whether it's a wedding anniversary, a baby's first day, an upcoming trip, or an exam countdown. Look forward to what's ahead, and look back on what has passed.

AHEAD AND PAST
The Days tab has two sides. Ahead counts down to upcoming dates with pinned and nearest days first—and keeps yearly anniversaries around for a week after they pass so you have time to write down a memory. One-time days move to Past after they arrive, counting up day by day.

ROUND NUMBERS
Days in Past automatically highlight their next milestone: every 100 days up to 1,000, every 500 days after that, and every full year—making ordinary days worth celebrating.

LUNAR CALENDAR AND SOLAR TERMS
Repeat birthdays and anniversaries by either the Gregorian or lunar calendar. The built-in calendar marks lunar dates, the 24 solar terms, and traditional festivals from 1900 through 2100.

TAP TO CHANGE UNITS
In any day's detail view, tap the number to switch effortlessly between days, weeks, months, and hours. Below, a clear timeline shows the last and next anniversaries or the next round-number milestone.

THOUGHTFUL REMINDERS
Get notified 7, 3, or 1 day ahead, or on the day itself, at a time you choose, or customize reminders for individual days. You can also turn on a morning Daily Greeting or yearly Memories on the anniversary of past days.

COVERS AND CATEGORIES
Every day is a card in its category's soft color palette. Frame it with a favorite photo of your own, or choose from 12 hand-crafted flat illustrations automatically matched to each category. Start with Love, Family, Travel, Work, and Life, or create custom categories in Me with your own icon and color theme.

HOME AND LOCK SCREEN WIDGETS
Bring your days to the Home Screen in small, medium, or large cards, view multiple upcoming dates at a glance with the day list widget, or add one of three Lock Screen styles. Pin a specific day or let it follow your top pinned item.

SHORTCUTS AND SIRI
Add a new day quickly from Control Center or the Home Screen quick action, or ask Siri how many days are left without even opening the app.

SHARE CARDS
Turn any day into a clean 3:4 portrait card with Photo, Journal, Minimal, or Split templates to save to Photos or share. Personal notes stay private by default unless you choose to include them.

ICLOUD SYNC AND BACKUPS
Sync your days, categories, and photos privately across your devices through your own iCloud account, or keep everything on this device only. Deleted days stay in Recently Deleted for 30 days, and if two devices edit the same day, the replaced version is preserved in Saved Sync Versions for 30 days so either can be restored. You can also export a complete backup file for easy device migration.

PRIVACY PROMISE
No data collected. Your days, photos, and settings live on your devices—and in your private iCloud storage if you turn on sync—and never reach the developer. No accounts, no ads, no tracking, and no third-party SDKs.

Available in English, Simplified Chinese, and Traditional Chinese; switch anytime in Me › Language. Countdowns and reminders automatically follow your device’s time zone.
```

## 隐私（App 隐私问卷答案）

- **是否收集数据**：否。App 不收集任何数据。
- **追踪**：无（`NSPrivacyTracking = false`，无追踪域名）。
- **数据存储**：日子 / 分类保存在设备（App Group 的 `UserDefaults` 与照片文件）和用户自己的 iCloud 私有数据库（CloudKit，照片为 `CKAsset`）；提醒设置通过用户自己的 iCloud 键值存储（`NSUbiquitousKeyValueStore`）同步。
- **隐私清单**：App 与 Widget 的 `PrivacyInfo.xcprivacy` 均声明 `NSPrivacyAccessedAPICategoryUserDefaults`（原因 `CA92.1`、App Group `1C8F.1`）与 `NSPrivacyAccessedAPICategoryFileTimestamp`（原因 `C617.1`，检查容器内的照片文件）。
- **出口合规**：`ITSAppUsesNonExemptEncryption = false`。

## 权限用途（Info.plist 文案）

- **相册添加**（`NSPhotoLibraryAddUsageDescription`）：用于把分享卡片保存到相册。
- **通知**：本地通知，用于日子提醒、每日问候与时光回忆（保存一个带提醒的日子、或在「我的 › 提醒设置」里打开开关时才请求授权；拒绝后该页会显示「去设置」的提示）。

## 审核备注（App Review Notes，建议）

- 无账号、无登录、无自有服务器。首次启动为空白资料库：点「日子」页右上角「+」新建一个日子，即可体验倒数、提醒、分享卡片与小组件。
- 底部三个标签：日子（分「将至」与「已过」两面）、日历、我的。分类、提醒设置、小组件、数据与同步、语言与关于都是「我的」里的条目。
- 用户看到的通知都是本地通知（`UNUserNotificationCenter`），用于纪念日 / 倒数提醒、每日问候与时光回忆；不发送营销推送。
- 后台模式：`fetch` 用于每天一次的 `BGAppRefreshTask`，补排 iOS 64 条上限之外的提醒；`remote-notification` 只用于 CloudKit 的静默推送，让同步及时拉取其他设备的更改。
- 其他入口：Siri 与快捷指令（「某个日子还有几天」、打开日子、新建日子）、控制中心的「新建日子」按钮、长按 App 图标的「新建日子」快捷操作，以及主屏幕的单个日子小组件和日子列表小组件。
- 分享与「保存到相册」通过系统分享面板与 `PHPhotoLibrary`，无第三方 SDK。
- iCloud 同步通过 CloudKit 私有数据库（`CKSyncEngine`）与 `NSUbiquitousKeyValueStore`（仅提醒设置），只同步用户自己的数据。

## 提交前清单

**仓库里已就绪**

- [x] App 图标 1024²、无 alpha 通道（浅蓝底的晴空日月，`python3 scripts/app-icon.py` 生成）；另有 iOS 18 深色与着色版本，背景透明是这两种外观的要求
- [x] 启动屏背景与 App 背景一致（`#F6F6F3`，仅浅色），`AccentColor` 与 App 的墨色一致（`RenderingTests` 检查）
- [x] 隐私清单（App + Widget）
- [x] 出口合规声明（`ITSAppUsesNonExemptEncryption = false`，上传后不会再问）
- [x] 版本号与构建号由构建设置提供，App 与小组件一致（`WidgetTests` 检查）
- [x] Inter 字体的 SIL OFL 许可随字体打包（`Fonts/OFL.txt`）
- [x] 隐私政策与支持页面：三种语言各一页，App 内「我的 › 关于」打开当前语言的页面
- [x] 网站已上线：`/`、`/privacy/`、`/support/` 及 `zh-Hant/`、`en/` 下的页面都能打开，旧地址 301 跳转
- [x] App Store 截图：`docs/screenshots/<语言>/`，6.9 英寸 1320×2868、无 alpha 的 JPEG，简体 / 繁体 / 英文各 7 张（首页、详情、日历、小组件、分享、我的、已过）。按文件名顺序上传到 App Store Connect 各语言的「6.9 英寸 iPhone」截图位；`bash scripts/screenshots.sh` 可重新生成
- [x] 归档脚本：`bash scripts/archive.sh` 归档并导出 IPA，导出后检查 `aps-environment` 与 iCloud 环境为 production、App 与小组件版本一致、App Group、图标无 alpha；`--upload` 检查通过后再上传。CI 每次跑一遍不签名的真机归档（`--unsigned`）

**待补的信息**

- [x] Team ID：`V9KCA3SG7G`（个人账号 Yue Sun），已填进 `project.yml` 的 `DEVELOPMENT_TEAM`。`project.yml` 里的值会覆盖 Xcode 中手动选的团队；临时换团队用 `TEAM_ID=…`
- [x] 支持邮箱 `support@gooday.dev`：已写在三种语言的支持页「联系我们」和隐私政策的联系方式里；也可以填作 App Store Connect 的审核联系邮箱

**开发者账号与 CloudKit**

- [ ] 为 App ID（`dev.gooday.days`）与 Widget App ID（`.widget`）启用 App Groups（`group.dev.gooday.days`），为 App ID 启用 iCloud（CloudKit 容器 `iCloud.dev.gooday.days`）与推送
- [ ] CloudKit：用真机 Development 环境完成一次同步，确认 `DaysRememberLibrary` 区域里有 `LibraryDay` / `LibraryCategory` 记录，再在 CloudKit Console 把 Schema **部署到 Production**（否则 App Store 用户的同步全部失败；模拟器不会连接 CloudKit）
- [ ] 不要删掉 `remote-notification` 后台模式与 `registerForRemoteNotifications`：CloudKit 用静默推送通知同步变化

**App Store Connect**

- [ ] 新建 App 记录：先确认名称可用（见上文「商店文案」），SKU、主语言简体中文、Bundle ID `dev.gooday.days`。用旧 Bundle ID `com.shiguang.daysremember` 建的记录占着「时光」这个名字，先给它改名或移除；它的 TestFlight 构建和测试员不会转到新记录，要重新邀请
- [ ] App 信息：名称、副标题、分类（生活 / 效率）、年龄分级问卷（4+）、版权；为繁體中文与英文添加本地化，填入「商店文案」
- [ ] 价格与销售范围：免费。中国大陆需要 App 备案号（ICP），备案通过接入商（如阿里云、腾讯云）办理，需要 Bundle ID 与签名证书信息，通常要一到几周；暂未备案就先不选中国大陆
- [ ] 欧盟上架需要声明「交易商身份」（DSA）。声明为交易商时，地址、电话与邮箱会公开显示在商店页
- [ ] App 隐私问卷按上文填写，隐私政策网址见上表
- [ ] 内容权利：图标和 12 张扁平封面都由仓库里的脚本绘制（`scripts/app-icon.py`、`scripts/flat-covers.py`），App 不含第三方图片或 AI 生成的图片；字体 Inter 以 SIL OFL 随附
- [ ] 版本信息：宣传文本、关键词、描述（见「商店文案」）、支持与营销网址、截图；首个版本没有「此版本的新内容」一栏
- [ ] 审核信息：联系人与审核备注（见上文），无需演示账号

**构建与回归**

- [ ] 用正式版 Xcode 运行 `bash scripts/archive.sh`（脚本会拒绝 beta 版 Xcode），确认检查通过后 `--upload`，或在 Organizer 中验证后上传
- [ ] iOS 26.0 回归：部署目标是 iOS 26.0，CI 跑 iOS 26.5。在 Xcode › Settings › Components 装上 iOS 26.0 模拟器后跑一遍测试，最好再用一台 iOS 26 真机
- [ ] TestFlight 真机回归：两台设备间的 iCloud 同步、没有登录 iCloud 时的表现、通知权限（允许与拒绝）与点按跳转、相册权限被拒绝时的保存、主屏/锁屏小组件、触感、动态字体放大

> 注：App 已锁定浅色外观（`UIUserInterfaceStyle = Light`），无需深色截图。
