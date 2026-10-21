# App Store 提交准备 · 时光 (Days Remember)

> 草稿。营销文案可按需修改；隐私问卷与审核备注为依据 App 实际行为整理，可直接使用。

## 基本信息

- **名称**：主屏幕上显示「时光」（`CFBundleDisplayName`）；App Store 名称、副标题与其他文案见下文「商店文案」
- **分类**：生活 / 效率
- **Bundle ID**：`com.shiguang.daysremember`（Widget：`.widget`）
- **版本 / 构建号**：版本取 `project.yml` 的 `MARKETING_VERSION`（现为 1.0），App 与小组件共用；构建号由 `scripts/archive.sh` 按提交数生成，每次从新的提交上传都会更大
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
记录结婚纪念、宝宝出生、一场旅行、考试倒数。按公历或农历每年重复，放进主屏与锁屏小组件，提前提醒不错过。无需账号，无广告，不收集任何数据。
```

**关键词**

```text
倒计时,农历,生日,恋爱,在一起,情侣,结婚,宝宝,周年,节气,考试,考研,旅行,假期,提醒,小组件,锁屏,日历,正数,天数,节日,百日,分享卡片,anniversary,countdown
```

**描述**

```text
时光帮你温柔记住每一个重要的日子：结婚纪念、宝宝出生、一场旅行、考试倒数。未来的值得期待，过去的可以回望。

【将至与已过】
首页分成两面。「将至」为还没到的日子倒数，最近的五个排在最前；每年的日子刚过去的一周里，首页还会留着它，方便你写下这一天。不重复的日子过去以后移到「已过」，一天天正数。

【整数纪念】
「已过」里的日子会预告下一个整数纪念：1000 天以内每满 100 天，之后每满 500 天，或者满一整年。

【农历与节气】
日子可以按公历或农历每年重复。日历里标出农历日期、二十四节气和传统节日，农历支持 1900 至 2100 年。

【轻点切换单位】
在日子详情里轻点数字，就在天、周、月、小时之间切换。下面列出这个日子的节点：每年的日子有上一次和下一次周年，已过的日子有下一个整数纪念。

【贴心提醒】
提前 7 天、3 天、1 天或当天提醒，时间自选，每个日子也可以单独设置。「每日问候」每天在你选的时间送上一句问候；「时光回忆」会在已过日子的周年那天，提醒你想起这一天。两项可以分别打开。

【封面与分类】
每个日子都是一张分类颜色的卡片。配一张自己的照片，或从 12 张扁平插图里挑一张；新建的日子会按分类先配好封面。除了爱情、家人、旅行、工作、生活，还能在「我的」里新建自己的分类，图标和颜色自己挑。

【小组件】
主屏幕小、中、大三种尺寸，用和 App 里一样的彩色卡片；锁定屏幕另有三种样式。每个小组件都可以单独选一个日子。

【分享卡片】
照片、手记、极简、双栏四种模板，可以导出 3:4 竖图，保存到相册或分享出去。笔记默认不出现在图片上。

【iCloud 同步与备份】
日子、分类和照片通过你自己的 iCloud 在设备间同步。误删的日子在「最近删除」里保留 30 天；两台设备改了同一个日子，被替换的那一版也会在「同步保留版本」里保留 30 天，都可以恢复。还可以导出备份文件，在新设备上从文件恢复。

【隐私】
不收集任何数据。日子、照片和设置只保存在你的设备和你自己的 iCloud 中，不会上传给开发者。无需账号，无广告，无追踪，无第三方 SDK。

支持简体中文、繁體中文和 English，可以在「我的 › 语言」里切换。倒数和提醒跟随设备所在的时区。
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
記錄結婚紀念、寶寶出生、一場旅行、考試倒數。按國曆或農曆每年重複，放進主畫面與鎖定畫面小工具，提前提醒不錯過。無需帳號，無廣告，不收集任何資料。
```

**關鍵字**

```text
倒數計時,農曆,生日,戀愛,在一起,情侶,結婚,寶寶,週年,節氣,考試,旅行,假期,提醒,小工具,鎖定畫面,日曆,正數,天數,節日,百日,分享卡片,anniversary,countdown
```

**描述**

```text
時光幫你溫柔記住每一個重要的日子：結婚紀念、寶寶出生、一場旅行、考試倒數。未來的值得期待，過去的可以回望。

【將至與已過】
首頁分成兩面。「將至」為還沒到的日子倒數，最近的五個排在最前；每年的日子剛過去的一週裡，首頁還會留著它，方便你寫下這一天。不重複的日子過去以後移到「已過」，一天天正數。

【整數紀念】
「已過」裡的日子會預告下一個整數紀念：1000 天以內每滿 100 天，之後每滿 500 天，或者滿一整年。

【農曆與節氣】
日子可以按國曆或農曆每年重複。日曆裡標出農曆日期、二十四節氣和傳統節日，農曆支援 1900 至 2100 年。

【輕點切換單位】
在日子詳情裡輕點數字，就在天、週、月、小時之間切換。下面列出這個日子的節點：每年的日子有上一次和下一次週年，已過的日子有下一個整數紀念。

【貼心提醒】
提前 7 天、3 天、1 天或當天提醒，時間自選，每個日子也可以單獨設定。「每日問候」每天在你選的時間送上一句問候；「時光回憶」會在已過日子的週年那天，提醒你想起這一天。兩項可以分別開啟。

【封面與分類】
每個日子都是一張分類顏色的卡片。配一張自己的照片，或從 12 張扁平插圖裡挑一張；新建的日子會依分類先配好封面。除了愛情、家人、旅行、工作、生活，還能在「我的」裡新增自己的分類，圖示和顏色自己挑。

【小工具】
主畫面小、中、大三種尺寸，用和 App 裡一樣的彩色卡片；鎖定畫面另有三種樣式。每個小工具都可以單獨選一個日子。

【分享卡片】
照片、手記、極簡、雙欄四種範本，可以匯出 3:4 直圖，儲存到相簿或分享出去。筆記預設不會出現在圖片上。

【iCloud 同步與備份】
日子、分類和照片透過你自己的 iCloud 在裝置間同步。誤刪的日子在「最近刪除」裡保留 30 天；兩台裝置改了同一個日子，被取代的那一版也會在「同步保留版本」裡保留 30 天，都可以還原。還可以匯出備份檔案，在新裝置上從檔案還原。

【隱私】
不收集任何資料。日子、照片和設定只儲存在你的裝置和你自己的 iCloud 中，不會上傳給開發者。無需帳號，無廣告，無追蹤，無第三方 SDK。

支援簡體中文、繁體中文和 English，可以在「我的 › 語言」裡切換。倒數和提醒跟隨裝置所在的時區。
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
Keep a wedding anniversary, a birth, a trip or an exam in view. Repeat by the Gregorian or lunar calendar, add Home and Lock Screen widgets, get reminded ahead.
```

**Keywords**

```text
birthday,lunar,chinese,calendar,widget,reminder,since,until,wedding,baby,love,dating,exam,trip
```

**Description**

```text
Days Remember gently keeps track of the days that matter: a wedding anniversary, a baby's birth, a trip, an exam. Look forward to what's ahead, and look back on what has passed.

AHEAD AND PAST
The Days tab has two sides. Ahead counts down to the days still to come, with the five nearest at the top, and keeps a yearly day there for a week after it passes so you can write it down. One-time days that have gone by move to Past, where they count up day by day.

ROUND NUMBERS
Days under Past show their next round number: every 100 days up to 1,000, every 500 after that, or a whole year.

LUNAR CALENDAR AND SOLAR TERMS
Repeat a day every year by the Gregorian or the lunar calendar. The calendar shows lunar dates, the 24 solar terms and traditional festivals, with lunar dates from 1900 through 2100.

TAP TO CHANGE UNITS
In a day's detail, tap the number to switch between days, weeks, months and hours. Below it are the day's marks: the last and next anniversaries of a yearly day, or the next round number of a past day.

REMINDERS
Get reminded 7, 3 or 1 day ahead, or on the day, at a time you choose, and give any day reminders of its own. The Daily Greeting sends a short note each day at the time you pick, and Memories brings back a past day on its anniversary. Each can be turned on separately.

COVERS AND CATEGORIES
Every day is a card in its category's color. Give it a photo of your own, or pick one of 12 flat illustrations; a new day starts with a cover that suits its category. Besides Love, Family, Travel, Work and Life, create categories of your own in Me, each with its own icon and color.

WIDGETS
Small, medium and large on the Home Screen, in the same colored cards as the app, plus three Lock Screen styles. Each widget can show a day of its own.

SHARE CARDS
Photo, Journal, Minimal and Split templates, with a 3:4 portrait export to save to Photos or share. Notes stay off the image unless you include them.

ICLOUD SYNC AND BACKUPS
Days, categories and photos sync across your devices through your own iCloud. A deleted day stays in Recently Deleted for 30 days, and when two devices change the same day, the replaced version stays in Saved Sync Versions for 30 days, so either can be restored. You can also export a backup and restore it from the file on a new device.

PRIVACY
No data collected. Your days, photos and settings stay on your devices and in your own iCloud, and nothing is sent to the developer. No account, no ads, no tracking, no third-party SDKs.

In English, Simplified Chinese and Traditional Chinese; switch in Me › Language. Countdowns and reminders follow your device’s time zone.
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
- 通知为本地通知（`UNUserNotificationCenter`），用于纪念日 / 倒数提醒。
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

- [ ] 为 App ID（`com.shiguang.daysremember`）与 Widget App ID（`.widget`）启用 App Groups（`group.com.shiguang.daysremember`），为 App ID 启用 iCloud（CloudKit 容器 `iCloud.com.shiguang.daysremember`）与推送
- [ ] CloudKit：用真机 Development 环境完成一次同步，确认 `DaysRememberLibrary` 区域里有 `LibraryDay` / `LibraryCategory` 记录，再在 CloudKit Console 把 Schema **部署到 Production**（否则 App Store 用户的同步全部失败；模拟器不会连接 CloudKit）
- [ ] 不要删掉 `remote-notification` 后台模式与 `registerForRemoteNotifications`：CloudKit 用静默推送通知同步变化

**App Store Connect**

- [ ] 新建 App 记录：先确认名称可用（见上文「商店文案」），SKU、主语言简体中文、Bundle ID
- [ ] App 信息：名称、副标题、分类（生活 / 效率）、年龄分级问卷（4+）、版权；为繁體中文与英文添加本地化，填入「商店文案」
- [ ] 价格与销售范围：免费。中国大陆需要 App 备案号（ICP），备案通过接入商（如阿里云、腾讯云）办理，需要 Bundle ID 与签名证书信息，通常要一到几周；暂未备案就先不选中国大陆
- [ ] 欧盟上架需要声明「交易商身份」（DSA）。声明为交易商时，地址、电话与邮箱会公开显示在商店页
- [ ] App 隐私问卷按上文填写，隐私政策网址见上表
- [ ] 内容权利：图标和 12 张扁平封面由仓库里的脚本绘制（`scripts/app-icon.py`、`scripts/flat-covers.py`）；作为照片后备保留的位图封面（`Cover*`）由 AI 生成，按实际情况回答
- [ ] 版本信息：宣传文本、关键词、描述（见「商店文案」）、支持与营销网址、截图；首个版本没有「此版本的新内容」一栏
- [ ] 审核信息：联系人与审核备注（见上文），无需演示账号

**构建与回归**

- [ ] 用正式版 Xcode 运行 `bash scripts/archive.sh`（脚本会拒绝 beta 版 Xcode），确认检查通过后 `--upload`，或在 Organizer 中验证后上传
- [ ] iOS 26.0 回归：部署目标是 iOS 26.0，CI 跑 iOS 26.5。在 Xcode › Settings › Components 装上 iOS 26.0 模拟器后跑一遍测试，最好再用一台 iOS 26 真机
- [ ] TestFlight 真机回归：两台设备间的 iCloud 同步、没有登录 iCloud 时的表现、通知权限（允许与拒绝）与点按跳转、相册权限被拒绝时的保存、主屏/锁屏小组件、触感、动态字体放大

> 注：App 已锁定浅色外观（`UIUserInterfaceStyle = Light`），无需深色截图。
