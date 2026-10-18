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

产品网站在 `docs/`，由 Cloudflare Workers Builds 在每次推送 `main` 时按 `wrangler.jsonc` 发布到 `days.gooday.dev`（静态文件，没有构建步骤）。隐私政策与支持页面和产品页一样每种语言一页：简体在根路径，繁體和英文在 `zh-Hant/`、`en/` 下。

| 字段 | 简体中文 | 繁體中文 | English |
|---|---|---|---|
| 隐私政策网址（必填） | `https://days.gooday.dev/privacy/` | `…/zh-Hant/privacy/` | `…/en/privacy/` |
| 支持网址（必填） | `https://days.gooday.dev/support/` | `…/zh-Hant/support/` | `…/en/support/` |
| 营销网址（可选） | `https://days.gooday.dev/` | `…/zh-Hant/` | `…/en/` |

App 内「我的 › 关于」的「隐私政策」「帮助与反馈」打开同样的页面（`SettingsView.siteURL`）。换域名时两处一起改。

## 描述（草稿，可编辑）

时光是一款温暖的纪念日与倒数应用。记录结婚纪念、宝宝出生、一场旅行、考试倒数……让重要的日子从容到来。

- 将至与已过：「将至」为还没到的日子倒数，最近的五个排在最前；不重复的日子过去以后，在「已过」里一天天正数
- 整数纪念：「已过」里的日子会预告下一个整数纪念——1000 天以内每满 100 天，之后每满 500 天，或者满一整年
- 农历支持：按公历或农历每年重复，日历显示农历日期、二十四节气与传统节日
- 轻点切换单位：在日子详情里轻点数字，在天、周、月、小时之间切换
- 彩色卡片：每个日子都是一张分类颜色的卡片，配一张自己的照片，或从 12 张扁平插图里挑一张
- 自定义分类：在「我的」里，除了爱情、家人、旅行、工作、生活，还能新建自己的分类，图标与颜色随心搭配
- 贴心提醒：提前 7/3/1 天或当天提醒，提醒时间自选；每日问候与时光回忆可分别打开
- 小组件：主屏幕小 / 中 / 大三种尺寸，用和 App 里一样的彩色卡片，另有三种锁定屏幕样式；每个小组件可单独选一个日子
- iCloud 同步：日子、分类和照片在你的设备间自动同步，误删的日子 30 天内可以恢复
- 分享卡片：照片、手记、极简、双栏四种模板，可导出 3:4 竖图，一键保存或分享

免费使用。所有数据都保存在你的设备与你自己的 iCloud 中——不收集、不上传、无广告、无追踪。

**关键词（建议）**：纪念日,倒数日,倒计时,生日提醒,农历,节日,纪念,Anniversary,Countdown,Widget

**宣传文本（建议）**：把重要的日子放在主屏，温柔提醒，从容相聚。

## 繁體中文（草稿）

- **名稱**：時光
- **副標題**：溫柔記住每一個重要的日子

時光是一款溫暖的紀念日與倒數 App。記錄結婚紀念、寶寶出生、一場旅行、考試倒數……讓重要的日子從容到來。

- 將至與已過：「將至」為還沒到的日子倒數，最近的五個排在最前；不重複的日子過去以後，在「已過」裡一天天正數
- 整數紀念：「已過」裡的日子會預告下一個整數紀念——1000 天以內每滿 100 天，之後每滿 500 天，或者滿一整年
- 農曆支援：按國曆或農曆每年重複，日曆顯示農曆日期、二十四節氣與傳統節日
- 輕點切換單位：在日子詳情裡輕點數字，在天、週、月、小時之間切換
- 彩色卡片：每個日子都是一張分類顏色的卡片，配一張自己的照片，或從 12 張扁平插圖裡挑一張
- 自訂分類：在「我的」裡，除了愛情、家人、旅行、工作、生活，還能新增自己的分類，圖示與顏色隨心搭配
- 貼心提醒：提前 7/3/1 天或當天提醒，提醒時間自選；每日問候與時光回憶可分別開啟
- 小工具：主畫面小 / 中 / 大三種尺寸，用和 App 裡一樣的彩色卡片，另有三種鎖定畫面樣式；每個小工具可單獨選一個日子
- iCloud 同步：日子、分類和照片在你的裝置間自動同步，誤刪的日子 30 天內可以還原
- 分享卡片：照片、手記、極簡、雙欄四種範本，可匯出 3:4 直圖，一鍵儲存或分享

免費使用。所有資料都儲存在你的裝置與你自己的 iCloud 中——不蒐集、不上傳、無廣告、無追蹤。

**關鍵字**：紀念日,倒數日,倒數計時,生日提醒,農曆,節日,紀念,小工具,Anniversary,Countdown

**宣傳文字**：把重要的日子放在主畫面，溫柔提醒，從容相聚。

## English (draft)

- **Name**: Days Remember
- **Subtitle**: Anniversaries and countdowns

Days Remember is a warm anniversary and countdown app. Keep track of a wedding anniversary, a baby’s birth, a trip or an exam, and let the days that matter arrive without a rush.

- Ahead and Past: Ahead counts down to the days still to come, with the five nearest at the top; one-time days that have gone by move to Past, where they count up day by day
- Round numbers: days under Past show their next round number — every 100 days up to 1,000, every 500 after that, or a whole year
- Lunar calendar: repeat a day every year by the Gregorian or lunar calendar; the calendar shows lunar dates, the 24 solar terms and traditional festivals
- Tap to change units: in a day’s detail, tap the number to switch between days, weeks, months and hours
- Colored cards: every day is a card in its category’s color; give it a photo of your own, or pick one of 12 flat illustrations
- Custom categories: in Me, besides Love, Family, Travel, Work and Life, create categories of your own, each with its own icon and color
- Reminders: 7, 3 or 1 day ahead, or on the day, at a time you choose; the Daily Greeting and Memories can be turned on separately
- Widgets: small, medium and large on the Home Screen, in the same colored cards as the app, plus three Lock Screen styles; each widget can show a day of its own
- iCloud sync: days, categories and photos sync across your devices, and a deleted day can be restored for 30 days
- Share cards: Photo, Journal, Minimal and Split templates, with a 3:4 portrait export, ready to save or share

Free to use. Everything stays on your devices and in your own iCloud. No data collection, no uploads, no ads, no tracking.

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
- **通知**：本地通知，用于日子提醒、每日问候与时光回忆（保存一个带提醒的日子、或在「我的 › 提醒设置」里打开开关时才请求授权；拒绝后该页会显示「去设置」的提示）。

## 审核备注（App Review Notes，建议）

- 无账号、无登录、无自有服务器。首次启动为空白资料库：点「日子」页右上角「+」新建一个日子，即可体验倒数、提醒、分享卡片与小组件。
- 底部三个标签：日子（分「将至」与「已过」两面）、日历、我的。分类、提醒设置、小组件、数据与同步、语言与关于都是「我的」里的条目。
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
- [x] 隐私政策与支持页面：`docs/privacy/`、`docs/support/`，App 内「我的 › 关于」可打开
- [ ] Cloudflare：Workers & Pages → 创建 → 导入 GitHub 仓库 `euynus/DaysRemember`，Worker 名称填 `days-remember`（与 `wrangler.jsonc` 一致），部署命令保持 `npx wrangler deploy`；部署后在该 Worker 的「设置 › 域和路由」添加自定义域 `days.gooday.dev`，确认上面三个网址能打开。**提交审核前必须完成**，否则 App 内的隐私政策链接打不开
- [ ] App Store Connect：填写上面的网址、年龄分级问卷、版权
- [ ] App Store Connect：新建 App 记录时确认名称可用；为繁體中文与英文添加本地化，填入上面的草稿
- [ ] 中国大陆上架需要 App 备案号（ICP）：在「价格与销售范围」选中国大陆时填写。备案通过接入商（如阿里云、腾讯云）办理，需要 Bundle ID 与签名证书信息，通常要一到几周。暂未备案就先不选中国大陆
- [ ] 欧盟上架需要在 App Store Connect 声明「交易商身份」（DSA）。声明为交易商时，地址、电话与邮箱会公开显示在商店页
- [ ] 用正式版 Xcode 归档（不能是 beta），并在 Organizer 中验证后上传
- [x] App Store 截图：`docs/screenshots/<语言>/`，6.9 英寸 1320×2868、无 alpha 的 JPEG，简体 / 繁体 / 英文各 7 张（首页、详情、日历、小组件、分享、我的、已过）。按文件名顺序上传到 App Store Connect 各语言的「6.9 英寸 iPhone」截图位；`bash scripts/screenshots.sh` 可重新生成
- [ ] TestFlight 真机回归：两台设备间的 iCloud 同步、通知权限与点按跳转、主屏/锁屏小组件、触感、动态字体放大
- [ ] App Store Connect 隐私问卷按上文填写

> 注：App 已锁定浅色外观（`UIUserInterfaceStyle = Light`），无需深色截图。
