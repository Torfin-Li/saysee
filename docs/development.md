# 开发与验证

## 环境

- Apple Silicon Mac；不支持在 Intel 上运行当前 MLX GPU STT。
- Xcode 26.6、Swift 6.3 和 Apple Metal Toolchain。虽然根包使用 Swift 5 语言模式，锁定的 MLX 依赖要求 Swift 6.3 工具链。
- Python 3、uv，仅用于模型准备和本地发布检查。
- gitleaks，用于公开内容扫描：`brew install gitleaks`。

当前手动验证环境是 Apple M3、macOS 26.5.2。部署目标 macOS 14 不表示已验证所有系统组合。CI 使用 `macos-26` Apple Silicon runner 和 Xcode 26.6；能力依据 [GitHub runner 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job) 及 [官方镜像清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)。CI 需在仓库创建并推送后才能实际运行，目前不把本地测试描述为 CI 通过。

## 准备和构建

```sh
xcodebuild -downloadComponent MetalToolchain
./scripts/bootstrap.sh
./scripts/build-app.sh
./scripts/run-app.sh
```

`bootstrap.sh` 建立 `.tools/model-download`，从固定上游 revision 下载模型到 `.tools/models/qwen3-asr-1.7b-6bit`，准备分词器并解析 Swift 依赖。`build-app.sh` 不会从整个工作目录复制资源，也不依赖本地实验目录；它从空暂存目录生成 App，再替换 `dist/Saysee.app`。替换前请退出正在运行的旧版 App。

构建映射源码／调试路径并剥离调试信息；Swift 编译参数变化可能触发一次完整依赖重编译。发行编译缓存位于 `/tmp/saysee-release-<uid>-<path-hash>`，脚本只接受当前用户拥有、权限为 0700 且不是符号链接的目录；这是为避免 SwiftPM 把个人目录写入资源回退路径。Metal 编译结果按依赖 revision 和编译器缓存。所有模型及许可均在签名前准备，运行时不应写入已安装的 App。

## 可选环境变量

`.env.example` 只是说明，不会自动加载。

- `SAYSEE_MODEL_DIR`：本机现有 Qwen3-ASR-1.7B-6bit 模型目录，供准备、打包或显式 CLI 验证使用。不要用于无来源的模型文件；正式发布须核对固定权重来源。

DeepSeek Key 在 App 内保存到 Keychain，不提供包含密钥的配置模板或命令行参数。

## 本地测试

```sh
swift test -j 2
python3 -m unittest discover -s scripts/validation -p 'test_*.py'
zsh -n scripts/bootstrap.sh scripts/build-app.sh scripts/build-metal.sh scripts/run-app.sh
codesign --verify --deep --strict dist/Saysee.app
```

源代码整理移除了已废弃波形实现及其 7 项测试；正式功能仍保留原有会话、PCM、活动门控、热键、交付、日志与请求测试。测试数量变化不代表跳过失败测试。

## 文件语音检查

使用自己的非敏感音频，不依赖任何被忽略的实验夹具：

```sh
./dist/Saysee.app/Contents/MacOS/Saysee --transcribe /path/to/test-audio.wav
./dist/Saysee.app/Contents/MacOS/Saysee --check-stt /path/to/test-audio.wav
./dist/Saysee.app/Contents/MacOS/Saysee --check-stt-paced /path/to/long-test-audio.wav
```

这些显式模式会输出指定文件的转录到 stdout，不开启麦克风、不填入其他应用、不调用 LLM。`--check-stt` 每文件运行两次并验证取消后新会话；`--check-stt-paced` 按真实收音节奏喂入，适合观察长录音预转录。测试条件会受首次加载、缓存及系统负载影响。

云端连接测试只通过 App 设置中的“测试连接”发起，使用固定合成句，调用 DeepSeek 并可能收费。已移除本地云认证、文本评估脚本与相关 CLI 入口，不再读取服务账号路径或凭证环境变量。

## 耗时日志

日志位于 `~/Library/Logs/Saysee/saysee.jsonl`，按 `session` 关联，耗时单位为毫秒：

- `capture_ready`：权限、模型准备与录音启动。
- `stt_chunk_complete`：录音期间完整 30 秒块的转录任务耗时。
- `stt_finalize` / `stt_complete`：停止后等待预转录及尾段的时间。
- `auth_wait_complete`：停止后读取本机 Keychain 的时间。
- `llm_complete`：完整整理请求耗时。
- `delivery_complete`：复制／粘贴派发耗时；派发不是插入回执。
- `turn_complete`：停止至结果可交付的总耗时。

请勿把日志和模型评估输出直接加入仓库。公开报告前检查正文、路径、项目标识与密钥是否已脱敏。
