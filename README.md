# Saysee

把口述变成清晰、精炼的书面表达。

Saysee 是面向 Apple Silicon 的 macOS 菜单栏语音输入应用。按 Fn 开始说话，再按一次结束：本地模型转录音频，文本模型纠错、提炼和理顺逻辑，最后尝试填入当前输入框；无法确认输入目标时显示结果卡片，并复制到剪贴板。

**状态：0.1.0 公开预览源码，尚未发布正式安装包。** 当前仅完成本地验证，尚未提供 Developer ID 签名、公证的 DMG。

## 功能

- 本地中文、英文转录：Qwen3 ASR 1.7B 6-bit，使用 MLX / Metal 原生推理。
- Fn 开始／结束，`⌘⇧Space` 备用，Esc 取消；也可点击收音胶囊结束。
- 安静时三条短杠静止，说话时提亮并大幅错峰跳动，停说后收拢；处理中使用完整细环与高亮弧段。
- 长录音提前转录完整的 30 秒分块，结束后处理尾段；最多录音 5 分钟。
- 结合上下文纠正明显识别错误，合并重复、精炼语言；多事项使用纯文本编号，输出纯文本。
- 仅支持 DeepSeek，模型名称可配置，thinking 关闭。
- 设置、权限检查、重试、复制及分阶段耗时日志。

## 隐私边界

**本地转录不等于全流程离线。完整转录文字会发送给你选择的云端文本模型进行整理。**

- 麦克风音频只在本机内存中处理，应用不将原始音频写入磁盘或发送给 LLM。
- DeepSeek API Key 存入 macOS Keychain，不读取本地服务账号文件或云认证环境变量。
- 日志只记录阶段、耗时及必要状态，不记录转录正文、整理正文、API Key 或私钥。
- 输出会留在系统剪贴板；主动点击“复制密钥”也会把 Key 放入剪贴板。
- 云端请求由用户自己的账号发起，相关费用和数据处理规则取决于所选服务商。

详情见 [隐私与数据流](docs/privacy.md) 和 [安全政策](SECURITY.md)。

## 从源码运行

需要 Apple Silicon Mac、Xcode 26.6 / Swift 6.3 工具链、Apple Metal Toolchain、Python 3 和 uv。当前验证环境为 Apple M3、macOS 26.5.2；目标系统最低版本为 macOS 14，但尚未完整验证所有系统版本和硬件。

```sh
xcodebuild -downloadComponent MetalToolchain
./scripts/bootstrap.sh
./scripts/build-app.sh
./scripts/run-app.sh
```

首次准备会下载约 2 GB 的固定版本 Qwen 权重。Python / uv 仅用于构建准备，运行生成的 `dist/Saysee.app` 不需要 Python 或本地服务器。默认构建采用 ad-hoc 签名，用于开发验证。

首次使用：

1. 在“语音与整理”配置自己的 DeepSeek API Key 和模型，点击“测试连接”。测试只发送固定示例句。
2. 在“设备与权限”检查麦克风、辅助功能与输入监控权限，按系统要求重启 App。
3. 把系统 Fn／地球键动作设为“不执行任何操作”，避免同时触发系统听写或切换输入源。
4. 切换到可编辑输入框，按 Fn 说话，再按 Fn 结束。

退出请使用菜单栏“退出 Saysee”、设置页的退出按钮，或在设置窗口按 `⌘Q`。关闭设置窗口只隐藏窗口；退出 App 才会停止整个应用。

完整构建说明、环境变量和测试命令见 [开发指南](docs/development.md)。

## 项目结构

```text
Sources/
  SayseeApp/       macOS 应用、录音、Qwen 推理、浮层、设置和文字交付
  SayseeCore/      会话隔离、声音活动检测、PCM、热键规则、认证及 LLM 请求
Tests/            Swift 单元测试
Resources/        App 元数据和随包第三方许可
scripts/          依赖准备、构建、验证及公开内容审计
.github/          CI 和问题模板
docs/            架构、隐私、开发与发布说明
```

本地研究目录 `experiments/`、设计原型 `design/`、内部开发记录 `docs/internal/`、模型缓存和构建产物均不纳入公开源码。旧 sherpa/ONNX 桥接和波形代码已从正式源码中归档。

## 已知限制

- 第三方键盘的 Fn 可能只在固件内部处理，无法被系统读取；可用备用快捷键。
- 自动填入依赖 macOS Accessibility。部分自绘编辑器和网页控件无法验证，默认复制并显示结果，不按应用添加特殊兼容规则。
- “已填入”目前表示已派发一次粘贴快捷键，并非目标应用确认插入；结果同时保留在剪贴板。
- 短于 30 秒的录音仍需在结束后转录。首次模型加载、GPU 编译及云服务响应都会影响延迟。
- 30 秒分块可能切断词语；取消会作废结果，但已运行的 GPU 块可能计算到块结束才释放推理通道。
- 声音活动门控不是说话人识别，持续的大声环境噪声也可能触发动画。
- LLM 可能错误纠词、概括或推断关系；重要文本需自行核对。

## 验证与发布

```sh
swift test -j 2
python3 -m unittest discover -s scripts/validation -p 'test_*.py'
```

发布前必须审计 **Git 暂存区的源码快照** 与 **实际 App 产物**，而不是只依赖 `.gitignore`。参见 [发布清单](docs/releasing.md) 与 [本次发布审查](docs/release-review.md)。本项目不包含自动公开仓库、推送或上传 Release 的脚本。

## 许可与上游

项目代码采用 [MIT](LICENSE) 许可证，模型及依赖适用各自许可证，见 [第三方声明](THIRD_PARTY_NOTICES.md)。

- [Qwen3 ASR](https://github.com/QwenLM/Qwen3-ASR)
- [Qwen3-ASR-1.7B-6bit 权重](https://huggingface.co/mlx-community/Qwen3-ASR-1.7B-6bit)
- [MLX Audio Swift](https://github.com/Blaizzy/mlx-audio-swift)
- [MLX Swift](https://github.com/ml-explore/mlx-swift)
