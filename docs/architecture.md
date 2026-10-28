# 架构与请求路径

应用是一个 SwiftPM 可执行目标，采用 SwiftUI + AppKit；没有 Web 前端服务或常驻 Python 后端。`SayseeCore` 保存可独立测试的规则与协议处理，`SayseeApp` 负责 macOS 设备和交互。

## 一次语音输入

1. `GlobalHotkey` 接收 Fn 或备用快捷键，`SessionController` 创建会话标识，校验文本模型配置，准备本地 STT。
2. `SpeechEngine` 通过 AVAudioEngine 采集默认麦克风的 PCM，混为单声道。原始数据进入 `NativeDecoder`；独立的 `AudioActivityDetector` 只控制动画，不能裁剪或终止录音。
3. `PCMRecordingBuffer` 约束采样格式、总录音时长和会话身份。收满 30 秒的数据交给串行 `QwenRecognizer`；模型常驻，GPU 工作不会并发争用同一模型实例。
4. 再次按 Fn 或点击胶囊后先停止采集，记录当前输入目标，等待预转录任务和尾段识别，按收音顺序合并完整转录。
5. `RewriteClient` 把完整转录发送到DeepSeek 文本服务，以阻塞请求获得完整成稿。当前提示词是纠错、精炼、重组与纯文本分点，不接入 Live API。
6. `TextDelivery` 复制结果并重新检查目标。只对可验证的同一可编辑文本控件派发一次粘贴，否则展示结果卡片；不会抢回旧应用焦点或盲目重复粘贴。

取消、退出、设备变化和新会话使用会话标识拒绝过期数据或结果。GPU 同步生成不支持 token 级抢占，作废结果与终止计算是两件不同的事。

## 状态与界面

`idle → preparing → recording → thinking → success / result / failed`。

准备与录音安静阶段的图标静止。持续声音达到门限后，三条杠提亮并以明显高低差错峰跳动；停止说话后约 200 ms 收拢为低矮短杠。声音门控不决定是否录音。处理阶段使用完整底环加高亮弧段，单独播放旋转动画，并尊重系统减少动态效果设置。

## 文件入口

- `Sources/SayseeApp/Saysee.swift`：App 生命周期、单实例、菜单栏、设置与显式文件检查入口。
- `Sources/SayseeApp/SessionController.swift`：状态机和完整处理链路。
- `Sources/SayseeApp/SpeechEngine.swift`、`QwenDecoder.swift`：录音与本地模型。
- `Sources/SayseeApp/TextDelivery.swift`：目标检查和交付。
- `Sources/SayseeCore/RewriteClient.swift`：共享提示词、云服务请求及响应检查。
- `Sources/SayseeCore/LegacySettingsMigration.swift`：清除旧服务路径及项目配置，仅保留 DeepSeek 模型设置与 Keychain。
- `Sources/SayseeCore/DiagnosticLog.swift`：不含正文的结构化诊断日志。

## 边界

不承诺通用“任意光标可输入”检测，也不承诺派发粘贴就已插入。语音只在本机转录，但云端整理接收完整转录。模型权重是发布资源，不进入 Git；凭证是用户配置，既不进入 Git，也不进入 App 资源。
