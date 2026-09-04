# Release 发布预检 — 2026-09-04

## 结论

本地 Release 构建、测试和启动检查已完成，**尚不满足公开分发条件**。
没有上传公证、发布网站下载、提交 App Store，也没有创建证书或改变系统安全设置。

源码基线：`f2df9c0b13fc1a0fd4ef15c689be1d5a5c63d8af`。
使用 Git 导出该提交中的 PulseBar，在独立临时目录构建，未包含工作区内尚未提交的
传感器实验代码、工程变更或用户的 Phase 22 文档修改。本阶段不修改 App 代码。

环境：macOS 26.5（25F71）、Xcode 26.6（17F113）、macOS SDK 26.5，本机 arm64。
保留项目现有版本 `0.1.0`、构建号 `1`，不代表该版本已正式发布。

## 已验证

| 检查 | 结果 |
| --- | --- |
| SwiftPM Release 优化模式测试 | 64 项全部通过；完整并发检查，Swift 警告视为错误 |
| Xcode Release archive | 成功；正常 PulseBar scheme，无实验传感器配置 |
| 架构 | 同一二进制包含 arm64 和 x86_64 |
| 最低系统版本 | 两个架构均声明 macOS 14.0 |
| 本地签名完整性 | `codesign --verify --deep --strict` 通过 |
| 沙盒 | `com.apple.security.app-sandbox = true` |
| Hardened Runtime | 签名 flags 含 `runtime` |
| 调试权限 | 不包含 `com.apple.security.get-task-allow` |
| 调试符号 | 两个架构的 dSYM UUID 与可执行文件对应 |
| Apple Silicon 实际运行 | 独立 App 副本可启动；CPU、内存、磁盘、电池、GPU、网络显示实时值 |
| 刷新设置 | 0.5、1、2、5 秒选项都存在；保留用户已有的 1 秒选择，未修改偏好 |

64 项是干净源码的测试数。上一阶段工作区的 67 项包含 3 项未提交的传感器实验测试，
这里不包含它们。Intel 架构仅完成编译与结构检查，没有在 Intel 实机上运行；
macOS 14 最低版本兼容性也尚未进行实机验证。

## 本地产物

- 可直接打开的验收 App：`运行版/ReleasePreflight-f2df9c0-20260904/PulseBar.app`
- Xcode 归档：`运行版/ReleasePreflight-f2df9c0-20260904/PulseBar-LOCAL-ONLY.xcarchive`
- 归档包含 Release App 和两个架构的 dSYM。
- 旧的 `运行版/PulseBar.app` 以及先前 Debug 构建没有被覆盖。

这是 **ad-hoc 本地签名**，不是 Developer ID 分发签名。请勿作为官网下载文件或
正式安装包发送给用户。重新正式签名后需重新验证并生成分发文件校验值。

本次本地可执行文件 SHA-256：
`0acd4b3f10b4baec700073212c50955b1a56d1ea00fda20d5de89a00a56016ef`

## 发布阻碍与后续顺序

1. 默认钥匙串中没有检测到有效的 Developer ID Application、Developer ID Installer
   或 Apple Development 代码签名身份。这个结果仅说明本机尚无可用身份，不能据此
   判断用户是否已经拥有 Apple Developer Program 会员。
2. 当前签名显示 `Signature=adhoc`、`TeamIdentifier=not set`；Gatekeeper 的只读评估
   返回 `rejected`。本机构建能运行不等于其他用户下载后能通过系统检查。没有绕过评估、
   移除隔离属性或关闭 Gatekeeper。
3. 从归档内和独立 App 副本打开时，Launch at Login 均显示 `Unavailable`，开关禁用。
   未尝试注册启动项、未修改用户的登录项，也未验证重新登录。具体原因尚未确定，不能
   断言更换证书就必然解决；配置正式签名并正常安装后仍须验证，若继续失败再针对性修复。
4. 用户确认开发者账号/团队后，在 Xcode 配置 Developer ID Application 签名，再构建
   正式归档。密码、私钥等不应发送到聊天中；不需要为普通 App/DMG 凭空创建 Installer
   证书，只有采用需要该证书的安装器签名方式时才考虑。
5. 经过签名、公证并附加公证票据后，重新执行 Gatekeeper 检查，以及真实下载、安装、
   启动、开机自启检查。随后才接入官网 HTTPS 下载地址；公开访问仍需要用户确认。
6. App Store 分发单独验证审核要求，现有实验性 GPU 驱动字段仍有兼容性与审核风险。
   条款、多语言和跨硬件实机验收仍在后续阶段，不在本次新增。

依据：[Apple 公证说明](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、
[macOS 分发签名](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)、
[Universal 二进制](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)。

## 复现本地检查

先将上述提交导出到新的临时目录；不要在有未完成变更的工作区执行清理或重置。
以下命令在导出的 PulseBar 项目目录执行；归档、构建目录须选择新的输出位置。

```sh
swift test -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors

xcodebuild -project PulseBar.xcodeproj -scheme PulseBar \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath ./DerivedData/LocalRelease \
  -archivePath ./运行版/LOCAL-ONLY.xcarchive \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  'OTHER_CODE_SIGN_FLAGS=--options runtime' \
  SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES archive
```

上述签名参数仅用于本地预检，不是正式发布命令；缺少 Developer ID、公证以及发布授权
时不要将生成物用于公网下载。本阶段回档点仅保存此报告和 README，程序源码基线未改变。
