# App Store 提交准备 · 时光 (Days Remember)

> 草稿。营销文案可按需修改；隐私问卷与审核备注为依据 App 实际行为整理，可直接使用。

## 基本信息

- **名称**：时光
- **副标题（建议）**：温柔记住每一个重要的日子
- **分类**：生活 / 效率
- **Bundle ID**：`com.shiguang.daysremember`（Widget：`.widget`）
- **版本 / 构建号**：1.0 / 1
- **支持设备**：iPhone，竖屏，iOS 17+
- **语言**：简体中文、繁體中文、English
- **名称是否可用**：App Store 名称全局唯一，「时光」很可能已被占用。被占用时可改用「时光 · 纪念日倒数」这类名称，主屏幕上显示的仍是 `CFBundleDisplayName` 里的「时光」。

## 网址

产品网站在 `docs/`，由 Cloudflare Workers Builds 在每次推送 `main` 时按 `wrangler.jsonc` 发布到 `days.gooday.dev`（静态文件，没有构建步骤）。隐私政策与支持页面包含三种语言，按锚点区分。

| 字段 | 简体中文 | 繁體中文 | English |
|---|---|---|---|
| 隐私政策网址（必填） | `https://days.gooday.dev/privacy/#zh-Hans` | `…/privacy/#zh-Hant` | `…/privacy/#en` |
| 支持网址（必填） | `https://days.gooday.dev/support/#zh-Hans` | `…/support/#zh-Hant` | `…/support/#en` |
| 营销网址（可选） | `https://days.gooday.dev/` | `…/zh-Hant/` | `…/en/` |

App 内「设置 › 关于」的「隐私政策」「帮助与反馈」打开同样的页面（`SettingsView.siteURL`）。换域名时两处一起改。

## 描述（草稿，可编辑）

时光是一款温暖的纪念日与倒数应用。记录结婚纪念、宝宝出生、一场旅行、考试倒数……让重要的日子从容到来。

- 倒数与纪念：未来的值得期待，过去的可以回望
- 农历支持：按公历或农历每年重复，日历显示农历日期、节气与传统节日
- 自定义分类：图标与颜色随心搭配
- 照片封面：为日子加一张照片，或选用手绘插图封面
- 贴心提醒：提前 7/3/1 天或当天提醒，提醒时间自选
- 小组件：主屏幕小 / 中 / 大三种尺寸，以及锁定屏幕样式
- iCloud 同步：日子在你的设备间自动同步
- 分享卡片：四种模板，可导出 3:4 竖图，一键保存或分享

所有数据都保存在你的设备与你自己的 iCloud 中——不收集、不上传、无广告、无追踪。

**关键词（建议）**：纪念日,倒数日,倒计时,生日提醒,农历,节日,纪念,Anniversary,Countdown,Widget

**宣传文本（建议）**：把重要的日子放在主屏，温柔提醒，从容相聚。

## 繁體中文（草稿）

- **名稱**：時光
- **副標題**：溫柔記住每一個重要的日子

時光是一款溫暖的紀念日與倒數 App。記錄結婚紀念、寶寶出生、一場旅行、考試倒數……讓重要的日子從容到來。

- 倒數與紀念：未來的值得期待，過去的可以回望
- 農曆支援：按國曆或農曆每年重複，日曆顯示農曆日期、節氣與傳統節日
- 自訂分類：圖示與顏色隨心搭配
- 照片封面：為日子加一張照片，或選用手繪插圖封面
- 貼心提醒：提前 7/3/1 天或當天提醒，提醒時間自選
- 小工具：主畫面小 / 中 / 大三種尺寸，以及鎖定畫面樣式
- iCloud 同步：日子在你的裝置間自動同步
- 分享卡片：四種範本，可匯出 3:4 直圖，一鍵儲存或分享

所有資料都儲存在你的裝置與你自己的 iCloud 中——不蒐集、不上傳、無廣告、無追蹤。

**關鍵字**：紀念日,倒數日,倒數計時,生日提醒,農曆,節日,紀念,小工具,Anniversary,Countdown

**宣傳文字**：把重要的日子放在主畫面，溫柔提醒，從容相聚。

## English (draft)

- **Name**: Days Remember
- **Subtitle**: Anniversaries and countdowns

Days Remember is a warm anniversary and countdown app. Keep track of a wedding anniversary, a baby’s birth, a trip or an exam, and let the days that matter arrive without a rush.

- Countdowns and anniversaries: look forward to what’s ahead, and look back on what has passed
- Lunar calendar: repeat a day every year by the Gregorian or lunar calendar; the calendar shows lunar dates, solar terms and traditional festivals
- Custom categories: choose your own icons and colors
- Photo covers: give a day a photo, or pick a hand-drawn illustration
- Reminders: 7, 3 or 1 day ahead, or on the day, at a time you choose
- Widgets: small, medium and large on the Home Screen, plus Lock Screen styles
- iCloud sync: your days sync across your devices
- Share cards: four templates and a 3:4 portrait export, ready to save or share

Everything stays on your devices and in your own iCloud. No data collection, no uploads, no ads, no tracking.

**Keywords**: anniversary,countdown,birthday,reminder,lunar,calendar,widget,days since,days until,events

**Promotional text**: Keep the days that matter on your Home Screen, with gentle reminders.

## 隐私（App 隐私问卷答案）

- **是否收集数据**：否。App 不收集任何数据。
- **追踪**：无（`NSPrivacyTracking = false`，无追踪域名）。
- **数据存储**：日子 / 分类保存在设备（App Group 的 `UserDefaults` 与照片文件）和用户自己的 iCloud 私有数据库（CloudKit，照片为 `CKAsset`）；提醒设置通过用户自己的 iCloud 键值存储（`NSUbiquitousKeyValueStore`）同步。
- **隐私清单**：App 与 Widget 的 `PrivacyInfo.xcprivacy` 均声明 `NSPrivacyAccessedAPICategoryUserDefaults`（原因 `CA92.1`、App Group `1C8F.1`）与 `NSPrivacyAccessedAPICategoryFileTimestamp`（原因 `C617.1`，检查容器内的照片文件）。
- **出口合规**：`ITSAppUsesNonExemptEncryption = false`。

## 权限用途（Info.plist 文案）

- **相册添加**（`NSPhotoLibraryAddUsageDescription`）：用于把分享卡片保存到相册。
- **通知**：本地通知，用于日子提醒与每日问候（保存一个带提醒的日子、或在「提醒」页打开开关时才请求授权；拒绝后「提醒」页会显示前往设置的提示）。

## 审核备注（App Review Notes，建议）

- 无账号、无登录、无自有服务器。首次启动为空白资料库：点首页右上角「+」新建一个日子，即可体验倒数、提醒、分享卡片与小组件。
- 通知为本地通知（`UNUserNotificationCenter`），用于纪念日 / 倒数提醒。
- 分享与「保存到相册」通过系统分享面板与 `PHPhotoLibrary`，无第三方 SDK。
- iCloud 同步通过 CloudKit 私有数据库（`CKSyncEngine`）与 `NSUbiquitousKeyValueStore`（仅提醒设置），只同步用户自己的数据。

## 提交前清单

- [x] App 图标 1024²、无 alpha 通道（黑底日月图形）
- [x] 启动屏背景与 App 背景一致（米白 `#FCFCFA`，仅浅色）
- [x] 隐私清单（App + Widget）
- [x] 出口合规声明
- [ ] 在 Xcode 签名里填入真实 `DEVELOPMENT_TEAM`（归档上传所需；当前为空。`project.yml` 里的值会在 `xcodegen generate` 时覆盖 Xcode 中手动选的团队）
- [ ] 开发者账号中为 App ID 与 Widget App ID 启用 App Groups（`group.com.shiguang.daysremember`），为 App ID 启用 iCloud（CloudKit 容器 `iCloud.com.shiguang.daysremember`）与推送
- [ ] CloudKit：用真机 Development 环境完成一次同步，确认 `DaysRememberLibrary` 区域里有 `LibraryDay` / `LibraryCategory` 记录，再在 CloudKit Console 把 Schema **部署到 Production**（否则 App Store 用户的同步全部失败；模拟器不会连接 CloudKit）
- [ ] 归档后在 Organizer 检查导出的 App 权限：`aps-environment` 应为 `production`（源文件里是 `development`，由分发签名改写）
- [x] 隐私政策与支持页面：`docs/privacy/`、`docs/support/`，App 内「设置 › 关于」可打开
- [ ] Cloudflare：Workers & Pages → 创建 → 导入 GitHub 仓库 `euynus/DaysRemember`，Worker 名称填 `days-remember`（与 `wrangler.jsonc` 一致），部署命令保持 `npx wrangler deploy`；部署后在该 Worker 的「设置 › 域和路由」添加自定义域 `days.gooday.dev`，确认上面三个网址能打开。**提交审核前必须完成**，否则 App 内的隐私政策链接打不开
- [ ] App Store Connect：填写上面的网址、年龄分级问卷、版权
- [ ] App Store Connect：新建 App 记录时确认名称可用；为繁體中文与英文添加本地化，填入上面的草稿
- [ ] 中国大陆上架需要 App 备案号（ICP）：在「价格与销售范围」选中国大陆时填写。备案通过接入商（如阿里云、腾讯云）办理，需要 Bundle ID 与签名证书信息，通常要一到几周。暂未备案就先不选中国大陆
- [ ] 欧盟上架需要在 App Store Connect 声明「交易商身份」（DSA）。声明为交易商时，地址、电话与邮箱会公开显示在商店页
- [ ] 用正式版 Xcode 归档（不能是 beta），并在 Organizer 中验证后上传
- [x] App Store 截图：`docs/screenshots/<语言>/`，6.9 英寸 1320×2868、无 alpha 的 JPEG，简体 / 繁体 / 英文各 6 张（首页、详情、日历、小组件、分享、分类）。按文件名顺序上传到 App Store Connect 各语言的「6.9 英寸 iPhone」截图位；`bash scripts/screenshots.sh` 可重新生成
- [ ] TestFlight 真机回归：两台设备间的 iCloud 同步、通知权限与点按跳转、主屏/锁屏小组件、触感、动态字体放大
- [ ] App Store Connect 隐私问卷按上文填写

> 注：App 已锁定浅色外观（`UIUserInterfaceStyle = Light`），无需深色截图。
