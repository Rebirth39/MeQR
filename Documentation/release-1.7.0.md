# 喜劳转扩 1.7.0 发布准备

初次准备：2026-10-21；最近复核：2026-10-23（北京时间）。以下记录源码功能与发布准备状态，不代表商店已发布。

## 双端更新汇总

| 项目 | iOS / iPadOS | Android | 范围与边界 |
| --- | --- | --- | --- |
| 添加 Tag 响应优化 | 已实现 | 已实现 | 减少重复处理及预览重绘；没有可用于宣称具体提速倍数的基准数据 |
| 世界计划 CP/CB | 已实现 | 已实现 | 先支持 20 位角色；拖动来源在左，松手选择类型；B 旁 ↔ 换左右；组合命中区扩大为目标 Tag 中间 70%，两侧 15% 仍用于排序 |
| CP/CB 外观 | 已实现 | 已实现 | CP 固定双色实心；CB 固定白底双色描边；普通白底按钮不覆盖配对类型 |
| 普通 Tag 白底 | 已实现 | 已实现 | 保留分段描边；IP/团 Tag 用首个非纯白色，全部纯白回退可读色；其他 Tag 用对比度处理后的深色 |
| 白底样式持久化 | 本地、备份、同步 DTO | 本地、备份、同步 DTO | appearance / catalogKind 字段一致；已完成 iOS 成员端真实云文档下载验收，Android 与 iOS 的真实跨端链路仍待验收 |
| 毛玻璃磨砂强度 | 已实现并修复背景错位 | 已实现独立滑杆 | 与不透明度分开，0–100%，5% 一档；0% 不叠加模糊图；默认 50%，Android 保留原有卡内背景取景方式 |
| 磨砂参数保存 | 本地与本机备份 | 本地 JSON、备份、编辑副本 | 毛玻璃开关及强度仍不属于现有跨设备同步文档，不能宣称会跨端同步 |
| Tag 上限 | 15 | 15，入口及恢复均核对 | 本地与线上同步服务从 10 改为 15；第 16 个拒绝 |
| 内置 Tag 库 | 533 个 / 41 分组 | 533 个 / 41 分组 | 同线上 revision 2026.10.16.1，完整文件 SHA 一致，沿用已核实的线上颜色，未重配色 |
| Tag 长按拖动 | 修复拖动预览乱飞，用户此前确认可用 | 使用 Android 原生拖动 | 不强行统一平台手势实现 |
| 首页与卡片翻转 | 紧凑 24pt 标题、原生透视翻面及 60pt 顶部留白 | 保留现有 Android 动画 | 更高卡片、大字体和 iPad 顶部边界仍需验收 |
| 自有活跃计数 | 默认自动上报 | 默认自动上报 | 无额外弹窗、提示、开关、停止入口；失败静默；不引入第三方统计 SDK |
| Admin 活跃看板 | 服务端已上线 | 共用服务端 | 今日／本月同步卡片、今日／本月未同步安装近似数，分开展示 |
| 编辑未保存保护 | 卡片与二维码编辑加入退出确认 | 已有返回／取消确认及不可点外部取消的编辑页 | 保留各平台交互实现 |
| 设置项图标 | 使用现有原生图标 | 修复主题与我的工单缺失图标 | MEQR-20261022-A8C375；浅／深色下全部 11 个设置项图标回归通过 |

计数口径：同步按云端卡片 profileId 去重，不是账号或人数；未同步安装靠本地成功回执缓存，可能重复。采用北京时间自然日／月，不补报旧日。现有政策及 manifest 如实保留；本轮没有增加应用内提示。

已有功能如工单、支持码、云同步和认识记录不作为本次新增功能宣传。旧交换码协议仍按普通标签传递，不保证 CP/CB 属性和白底外观；Android 没有 iOS 的 Widget，均不宣称本次补齐。

## 当前版本与产物

- 当前源码版本：iOS 1.7.0 (29)，App 和 Widget 一致；Android 1.7.0 (19)。两端 build 独立递增，无需相同。
- iOS 当前提交为 9dff655；2026-10-23 只更新其发布文档，未改 App 源码。Android 本轮补齐设置图标映射和两个矢量资源，并提升本地版本号。
- 10 月 21 日证据中的 preflight APK 仍为 1.6.0 (18)，属于历史验证包；本轮 1.7.0 包与证据见 Documents/TestsScreenshot/release-parity-ticket-A8C375-20261023。
- 本轮没有提交 Git、推 GitHub、上传 ASC / TestFlight、替换官网下载包或覆盖安装用户真机。

## 验证及发布门槛

构建、测试、签名、哈希和部署证据保存在 Documents/Codex/meqr-1.7.0-preflight-20261021，其中 RESULT.md 为验收摘要。构建成功不等于商店验收完成。

发布前仍需：
- 在 iPhone、iPad 与 Android 真机验收长按组合、左右位、普通白底、背景与磨砂滑杆、回前台与离线启动。
- 在两端真实设备间同步 CP/CB、白底样式和 15 个 Tag；同时检查旧客户端读取以及失效凭证场景。
- 专门验收 iPad、大字体、长简介／多行 Tag 卡片的翻转边界，避免用当前卡片的 60pt 留白结果代替全设备结论。
- 核对 iOS App Privacy 和 Android 商店数据申报，与已实现统计及政策一致；manifest 不会自动更新商店表单。
- 确认版本号和递增 build，生成 iOS 签名 Archive／正式 Android 包，核对正式签名升级链，再提交发布。
- 如需同步 GitHub，包含 tracker 和本轮补齐；此前 Android 提交 d6fb29e 尚不含随后统计改动。

## 用户可见更新说明草稿

以下不包含内部计数功能、服务器接口或未验收的跨设备承诺。文案已按 humanizer 内部复核。

### 简体中文（两端通用）

这次主要改进 Tag 操作和卡片外观。

- 优化添加 Tag 时的响应。
- 新增世界计划 CP/CB Tag：把两个角色 Tag 拖到一起，选择 CP 或 CB；支持切换左右位。
- 普通 Tag 可切换白底样式，保留原来的配色描边。
- 毛玻璃增加独立磨砂强度设置，可与不透明度分别调整。
- 内置 Tag 库更新，卡片最多添加 15 个 Tag。

iOS 附加：修复已添加 Tag 拖动时预览位置异常，调整首页标题及卡片翻转布局。

### English (both platforms)

This update focuses on tag interactions and card appearance.

- Improved responsiveness when adding tags.
- Create Project Sekai CP/CB tags by dragging one character tag onto another. Choose the type and swap the left and right sides.
- Switch ordinary tags to a white background with their original colors along the border.
- Adjust frosting strength separately from card opacity.
- Updated the bundled tag catalog. Each card supports up to 15 tags.

iOS only: Fixed misplaced tag drag previews and adjusted the home title and card flip layout.

### 日本語（両プラットフォーム共通）

タグの操作とカードの外観を調整しました。

- タグ追加時の反応を改善。
- プロセカのキャラクタータグを重ねて CP/CB タグを作成できるようになりました。種類の変更や左右の入れ替えにも対応しています。
- 通常のタグに白背景を追加。元の色は枠線に残ります。
- すりガラスの強さを、カードの不透明度とは別に調整できるようになりました。
- 内蔵タグ一覧を更新。1枚のカードに最大15個のタグを追加できます。

iOS のみ：タグをドラッグしたときのプレビュー位置を修正し、ホーム画面のタイトルとカード反転時のレイアウトを調整しました。

