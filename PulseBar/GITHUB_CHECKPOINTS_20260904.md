# GitHub 同步与回档对照 — 2026-09-04

已完成的原生 PulseBar 代码备份分支：[codex/performance-backup-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/performance-backup-20260904)。

本机 HTTPS Git 缺少登录凭据，SSH 未建立可信主机记录，未修改认证配置。改用用户已连接且有写入权限的 GitHub 接口逐阶段上传。接口会重新生成提交作者/时间元数据，因此提交 SHA 不同；每个阶段的 Git **tree SHA 完全一致**，即全部版本化文件的路径、权限与内容一致。本地提交/标签未重写，远端 main 未修改。

## 每一步内容校验

| 步骤 | 本地提交 | GitHub 对应提交 | tree SHA（双方相同） |
| --- | --- | --- | --- |
| Fix network throughput double counting and decimal byte units | `f2df9c0` | [dc6d3a0](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/dc6d3a02ddfe328bb166130459d1557804512c82) | `d5484f41336ee41c8a60c822236175431cd2047d` |
| Record local Universal Release preflight and distribution blockers | `c52550a` | [c4e1b43](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/c4e1b43e8277ff21cde352c2c04ec22922606423) | `2f0830c8bdf59d1b9a89c5a6cef71f43355e53b1` |
| Add compact native overview with drill-down and rollback notes | `0686fe8` | [47a8c36](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/47a8c367118a6ab9ca396da4e8e30a43ff08e609) | `238d2045baa1fe5895fb0bd32b5df0122501e591` |
| Replace fixed four-card overview with flexible metric groups | `61a468c` | [259c8ba](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/259c8baaf4b81ad0d7c7b896cc3312cd0e51cf14) | `6b0d2c7e85979995b993dba0f4b7ea89e1f8bd20` |
| Give disk a pink accent and battery a green fill with gray outline | `41d52ac` | [da03040](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/da0304033e6e6679c81eb8c9b0746b6d38ae1417) | `ebb3fec3d4294ba2710883e0931c4bfa2fe9cade` |
| Batch chart marks and record first performance checkpoint | `6b4eb16` | [19643a5](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/19643a5028f8af51cd2d323a33883b8a5e3b83fa) | `82f8b768bdba038fdb97ec0b65120dfcdab5e0a7` |
| Record measured Canvas experiment without claiming a performance gain | `fafa48f` | [e5b1a41](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/e5b1a417ca06bd08a4486898f3c0042f9f80822e) | `bc3b34a37747f77ea16cdbae135717e8ddec647d` |
| Restore verified batched renderer after inconclusive Canvas experiment | `3f572ad` | [7a30caa](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/7a30caaa188a42e1bbc8986d2f3d8b221e43b0bc) | `ca505e3d8da4d1227d0ed6da5922a37c18282206` |
| Scope monitoring observation to metric views and deduplicate menu bar | `bb6676b` | [10baac5](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/10baac5798ca0e19ff2f20e64329af2ab92ea581) | `06bc60c47e785c088197b7f4b0f264196ca30653` |
| Document final performance results, limitations and GitHub rollback checkpoints | `9d8eb1b` | [c565c5c](https://github.com/henhenhenry1008-bot/fluffy-giggle/commit/c565c5c90d788984fee33597d9fe77dc19f0cb96) | `9a8d74eddb61b7275e500a8814f535621cfac897` |

## 快速回档分支

本地标签仍保留；远端使用 **9 个回档分支**，不是同名 Git tags。

| 本地标签 | GitHub 回档分支 |
| --- | --- |
| `codex/color-ui-20260904` | [codex/checkpoint/color-ui-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/color-ui-20260904) |
| `codex/compact-ui-20260904` | [codex/checkpoint/compact-ui-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/compact-ui-20260904) |
| `codex/flexible-ui-20260904` | [codex/checkpoint/flexible-ui-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/flexible-ui-20260904) |
| `codex/perf-optimized-20260904` | [codex/checkpoint/perf-optimized-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/perf-optimized-20260904) |
| `codex/perf-round-1-before-20260904` | [codex/checkpoint/perf-round-1-before-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/perf-round-1-before-20260904) |
| `codex/perf-round-2-before-20260904` | [codex/checkpoint/perf-round-2-before-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/perf-round-2-before-20260904) |
| `codex/perf-round-2-experiment-20260904` | [codex/checkpoint/perf-round-2-experiment-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/perf-round-2-experiment-20260904) |
| `codex/perf-round-3-before-20260904` | [codex/checkpoint/perf-round-3-before-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/perf-round-3-before-20260904) |
| `codex/pre-compact-ui-20260904` | [codex/checkpoint/pre-compact-ui-20260904](https://github.com/henhenhenry1008-bot/fluffy-giggle/tree/codex/checkpoint/pre-compact-ui-20260904) |

## 使用与范围

- 先退出正在运行的 PulseBar，再启动所选本地回档 App，避免多实例干扰 CPU 统计。
- 回档源码时，在独立目录下载/检出对应 GitHub 分支；不要对当前目录执行 hard reset。当前工作区还有未完成的传感器和网站内容。
- 同步范围包含之前未上传的网络统计/单位修复、各版原生 UI、三轮性能工作、无收益实验及其撤回、测试和报告。
- 未完成的传感器/网站文件、运行版 .app、DerivedData、采样日志和完整工作区备份仍在本地；没有公开发布安装包或合并 main。
- 第 1–24 阶段的既有分支保留在仓库，本次新增历史以第 24 阶段的提交为父节点。
- 两边保留的是相同文件树的平行提交历史。以后恢复本机 Git 登录后，不应强推覆盖任一边；先核对本对照表和远端内容。
