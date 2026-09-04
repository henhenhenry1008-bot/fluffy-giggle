# 分组总览版本 — 2026-09-04

本版接续 `0686fe8` 的四卡片版本，不再把总览限定为四张等大卡片。

## 改动

- CPU、内存使用并排的紧凑卡片。
- GPU 按系统实际返回的设备逐行展示名称、使用率和小图表。保留
  Experimental 提示；多个 GPU 不合并成一个没有统计依据的百分比。
  没有可用设备时显示 Unavailable，并保留详情入口。
- 网络使用全宽卡片，上下行数值采用同样大小的字体，各自有文字和
  箭头标签，并共享下方的小图表。
- 磁盘采用全宽容量条，显示占用百分比和可用空间。
- 总览可滚动以容纳额外设备；详情、返回总览、全部指标和设置入口保留。
- 不修改数据采集、统计口径、单位、刷新频率或任何已保存偏好。

## 验证

- 当前工作树的 SwiftPM 67 项测试通过。
- 排除未提交实验代码后的干净源码：Xcode Debug 构建及 64 项测试通过。
- 编译启用 complete 并发检查和 warnings-as-errors。
- 原生窗口检查：深色/浅色布局均无明显裁切，GPU 总览与详情读数对应，
  返回总览正常，所有总览卡片在辅助功能树中仍是按钮。
- 浅色检查后恢复了原先的 System 外观。用户已保存的 1 秒刷新选项不变。
- 独立保存的本地 App 通过代码签名完整性验证。

未进行多 GPU 实机、Intel 实机、macOS 14 或完整 VoiceOver 测试。
系统菜单栏实际弹出位置未重新验证；本轮视觉检查在共用同一总览视图的
原生窗口中完成。这仍是本地 Debug 预览，不是公开签名/公证发行包。

## 保存及回档

- 新版 App：`运行版/FlexibleOverview-20260904/PulseBar.app`
- 新版 Git 标签：`codex/flexible-ui-20260904`
- 四卡片旧版 App：`运行版/CompactOverview-20260904/PulseBar.app`
- 四卡片旧版 Git 标签：`codex/compact-ui-20260904`，提交 `0686fe8`
- 本次修改前的两个界面文件备份：`运行版/FlexibleUI-baseline-wogMOT/`

最快回档：先退出新版 PulseBar，再打开四卡片旧版 App。
不要同时运行两个版本；不需要清空偏好或重新编译。

如需检出四卡片源码且不碰当前工作树，在仓库根目录运行：

```sh
git worktree add --detach ../PulseBar-four-card-rollback codex/compact-ui-20260904
```

目标目录必须尚不存在。现有实验传感器、网站及其他文档改动均未包含
在本次独立提交中，也没有被回滚或覆盖。本版仅保存到本地，未推送或发布。

## 本版文件

- `Sources/PulseBar/Views/Dashboard/DashboardView.swift`
- `Sources/PulseBar/Views/Components/MetricCard.swift`
- `UI_FLEXIBLE_OVERVIEW.md`
