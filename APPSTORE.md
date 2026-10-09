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
- [ ] App Store Connect：隐私政策网址与支持网址（必填）、年龄分级问卷、版权
- [ ] App Store 截图（6.9 英寸必需，可在模拟器截取：首页、详情、日历、分类、提醒、分享、小组件、引导页；仅浅色）
- [ ] TestFlight 真机回归：两台设备间的 iCloud 同步、通知权限与点按跳转、主屏/锁屏小组件、触感、动态字体放大
- [ ] App Store Connect 隐私问卷按上文填写

> 注：App 已锁定浅色外观（`UIUserInterfaceStyle = Light`），无需深色截图。
