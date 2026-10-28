# 首次公开发布清单

本文记录源码公开和后续正式发行的检查要求。用户已于 2026-10-29 授权审查通过后推送个人公开仓库 `Torfin-Li/saysee`。本次只公开源码，不创建正式安装包 Release 或版本 tag；以下步骤供之后发布者复用。

## 公开源码边界

公开：项目代码、自动化测试、App 元数据、许可、构建／审计脚本、CI 和维护文档。

不公开：`experiments/`、`design/`、`docs/internal/`、`.tools/`、`.build/`、`dist/`、模型权重、语音与转录、日志、真实配置、凭证和签名材料。旧 sherpa / 波形实现留在本地实验归档。

`.gitignore` 不能移除已跟踪文件，也不能代替扫描。首次提交必须从明确的路径清单暂存，不使用未审阅的目录全量上传。

```sh
git add .gitignore .gitattributes .env.example LICENSE Package.swift Package.resolved \
  README.md SECURITY.md CONTRIBUTING.md CHANGELOG.md THIRD_PARTY_NOTICES.md \
  Sources Tests Resources scripts docs .github
python3 scripts/audit_public.py --app dist/Saysee.app
git diff --cached --check
git diff --cached --stat
```

审计导出的是 Git 暂存区中的 blob，而不是碰巧存在的工作文件。检查导出快照、扫描结果和 SHA-256 清单，均留在忽略的 `dist/public-audit/`。审计也检查 App 签名、负载路径、已知凭证形态、个人绝对路径和文本资源中的秘密；约 2 GB 的模型 tensor 不作文本秘密扫描，须单独核对固定上游来源。

提交前确认作者名与邮箱：不要无意公开工作邮箱或私人邮箱，必要时使用 GitHub 提供的 noreply 地址。首次提交后、push 前还须运行：

```sh
gitleaks git --redact --no-banner --log-opts='--all'
```

若后来修改任何待发布文件，重新暂存并重新审计。不得复用旧快照的扫描结论。审计工具隔离外部 gitleaks 配置并禁用内联放行注释，避免本机配置静默跳过检查。不要通过关闭规则、忽略整棵源码树或隐藏报告来让检查通过。

## 代码和行为验收

- [ ] Swift 测试、Python 发布边界测试、shell 语法检查通过。
- [ ] Release App 从空目录生成，曾经放入旧 App 的无害哨兵文件不能保留。
- [ ] 离线文件 STT 可用，签名校验通过，无开发机路径或凭证混入。
- [ ] 手动验证物理 Fn／备用键、静止与说话动画、取消、退出和权限变化。
- [ ] 手动验证原生文本框、网页、未知控件回退和处理时切换焦点。
- [ ] 代表性中英文口述的纠错、提炼、数字和否定保真得到验收。
- [ ] README 的当前能力、已知限制和隐私描述与实际行为一致。

自动测试和合成文件检查不能替代后四项真人验收。本轮没有承诺跨应用全覆盖或模型零误差。

## GitHub 首次公开

- [x] 本次已核对 CLI 账号为 `Torfin-Li`，仓库名为 `saysee`；连接器与 CLI 可能登录不同账号。
- [x] 用户已授权本次审查通过后公开源码；后续发行仍需符合当次授权范围。
- [ ] 启用私密漏洞报告，确认维护者可接收安全报告。
- [x] MIT 许可已获用户确认，模型及依赖通知已检查。
- [ ] 确认 Git 提交作者不会泄露不希望公开的邮箱，历史扫描无待处理发现。
- [ ] 创建仓库、push 后检查 GitHub CI；当前未实际运行远端 CI。
- [x] 已从公开快照验证无真实生产凭证时的本地单元测试。

## DMG 发行仍需完成

当前 `build-app.sh` 只生成 ad-hoc 签名开发 App，**并非完成 Developer ID 签名、公证、Gatekeeper 验证的安装包**。

正式 DMG 需单独完成 Developer ID / hardened runtime 兼容验证、Apple notarization 和 staple，再在干净用户环境验证下载、拖入 Applications、首次权限、模型可用与退出。签名证书和公证凭证只配置在受保护的发布环境，不进入源码或 App；首次正式分发前也应再次审计最终 DMG 内部的 App，而不是仅检查工作目录。

完成后才创建对应版本 tag、校验和、Release notes 并上传。当前没有可宣称已可直接安装的正式 DMG，也没有自动更新机制。
