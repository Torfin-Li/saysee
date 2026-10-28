import SwiftUI
import AppKit
import AVFoundation
import ApplicationServices
import SayseeCore
struct SettingsView:View {
 @ObservedObject var controller:SessionController
 @AppStorage("deepSeekModel") var deepSeekModel="deepseek-flash"
 @State var key=""
 @State private var keyLoading=true
 @State private var keyLoaded=false
 @State private var keySaving=false
 @State private var showingKey=false
 @State var message=""
 @State var testing=false
 @State var section=0
 var body:some View {
  HStack(spacing:0) {
   VStack(alignment:.leading,spacing:8) {
    Label("saysee",systemImage:"waveform").font(.system(size:22,weight:.semibold)).padding(.bottom,25)
    nav("通用",icon:"slider.horizontal.3",id:0);nav("设备与权限",icon:"mic",id:1);nav("语音与整理",icon:"text.alignleft",id:2)
    Spacer();Button("退出 Saysee",systemImage:"power"){NSApp.terminate(nil)}.buttonStyle(.plain).padding(.bottom,12).help("退出应用并停止录音（⌘Q）");Text("本地语音 · 清晰表达\n第一版 0.1").font(.system(size:11)).foregroundStyle(.secondary)
   }.padding(22).frame(width:190).background(Color.accentColor.opacity(0.05))
   Divider()
   ScrollView {
    VStack(alignment:.leading,spacing:20) {
     if section==0 {general} else if section==1 {permissions} else {services}
    }.padding(32).frame(maxWidth:.infinity,alignment:.leading)
   }
  }.frame(width:780,height:570).tint(Color(red:0.10,green:0.45,blue:0.38)).accentColor(Color(red:0.10,green:0.45,blue:0.38)).onDisappear{showingKey=false}
 }
 private func nav(_ title:String,icon:String,id:Int)->some View {
  Button {section=id;message=""} label:{Label(title,systemImage:icon).frame(maxWidth:.infinity,alignment:.leading).padding(10).background(section==id ? Color.accentColor.opacity(0.12):.clear,in:RoundedRectangle(cornerRadius:8))}.buttonStyle(.plain)
 }
 private var general:some View {
  VStack(alignment:.leading,spacing:20) {
   Text("让表达，跟上思路。").font(.system(size:25,weight:.semibold))
   Text("按一下 Fn 开始，再按一下结束。说完后，Saysee 会把你的话整理成完整文本。").foregroundStyle(.secondary)
   Divider();row("录音快捷键",detail:"单独按下并松开；组合键不触发",value:"Fn / ⌘⇧Space")
   row("语音识别",detail:"Qwen3 ASR 1.7B · 6-bit · 本地运行",value:"中文 / English")
   row("文字输出",detail:"目标未变化时填入；否则显示结果并复制",value:"自动识别")
   Text("Fn / 地球键请在系统键盘设置中改为“不执行任何操作”，避免同时触发系统输入源或听写。").font(.system(size:12)).foregroundStyle(.secondary)
   HStack {Button("键盘设置"){open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")};Button("开始试说"){NSApp.hide(nil);DispatchQueue.main.asyncAfter(deadline:.now()+0.3){controller.toggle()}}.buttonStyle(.borderedProminent)}
   Text("录音最多 5 分钟；Esc 取消。完整转录文字会发送到所选云服务进行整理，原始音频留在本机且不保存。").font(.system(size:12)).foregroundStyle(.secondary)
  }
 }
 private var permissions:some View {
  VStack(alignment:.leading,spacing:20) {
   Text("设备与权限").font(.system(size:25,weight:.semibold))
   Text("使用系统默认麦克风，开始录音时请求权限。").foregroundStyle(.secondary)
   row("麦克风",detail:"接收你的声音",value:AVCaptureDevice.authorizationStatus(for:.audio) == .authorized ? "已允许":"未授权")
   row("辅助功能",detail:"识别输入位置和填入文字",value:AXIsProcessTrusted() ? "已允许":"未授权")
   row("输入监控",detail:"全局响应 Fn 与 Esc",value:controller.hotkeyReady ? "监听已就绪":"需要授权")
   HStack {Button("麦克风设置"){open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")};Button("辅助功能设置"){let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true];_ = AXIsProcessTrustedWithOptions(options as CFDictionary);open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")}}
   HStack {Button("输入监控设置"){CGRequestListenEventAccess();open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")};Button("重新检查"){controller.enableHotkey();message="已重新检查。系统要求时请退出并重开 Saysee。"}}
   Toggle("仅检测快捷键（不开始录音）",isOn:$controller.diagnosingHotkey)
   Text(controller.hotkeyStatus).font(.system(size:12)).foregroundStyle(.secondary)
   Text("按下并松开 Fn，或使用备用快捷键 ⌘⇧Space。若没有收到 Fn 事件，请检查系统 Fn 动作与其他输入法快捷键。").font(.system(size:12)).foregroundStyle(.secondary)
   Button("查看诊断日志"){NSWorkspace.shared.selectFile(DiagnosticLog.fileURL.path,inFileViewerRootedAtPath:DiagnosticLog.directory.path)}
   Text(message).font(.system(size:12)).foregroundStyle(.secondary)
  }
 }
 private var services:some View {
  VStack(alignment:.leading,spacing:16) {
   Text("语音与整理").font(.system(size:25,weight:.semibold))
   Text("语音识别在本机完成；录音期间分段转录，结束后整理全文。").foregroundStyle(.secondary)
   row("文字整理服务",detail:"使用自己的 API Key",value:"DeepSeek")
    field("模型",text:$deepSeekModel)
    Text("深度思考已关闭 · 直接整理文本").font(.system(size:11)).foregroundStyle(.secondary)
    VStack(alignment:.leading,spacing:8) {
     Text("DeepSeek API Key").font(.system(size:12)).foregroundStyle(.secondary)
     HStack {
      Group {
       if showingKey {TextField("DeepSeek API Key",text:$key)}
       else {SecureField("DeepSeek API Key",text:$key)}
      }.textFieldStyle(.roundedBorder)
      Button {showingKey.toggle()} label:{Image(systemName:showingKey ? "eye.slash":"eye")}
       .help(showingKey ? "隐藏密钥":"显示密钥").accessibilityLabel(showingKey ? "隐藏密钥":"显示密钥")
     }
     HStack {
      Button("复制密钥") {
       NSPasteboard.general.clearContents();NSPasteboard.general.setString(key,forType:.string);message="密钥已复制。"
      }.disabled(key.isEmpty)
      Button("粘贴密钥") {
       if let value=NSPasteboard.general.string(forType:.string) {key=value.trimmingCharacters(in:.whitespacesAndNewlines);message="密钥已粘贴，请保存到钥匙串。"}
      }
     }.controlSize(.small)
    }
    .disabled(keyLoading || keySaving)
    Button(keySaving ? "正在保存…":"保存到钥匙串") {
     keySaving=true
     Task {
      do {try await Keychain.save(key);message=key.isEmpty ? "密钥已移除。":"密钥已保存。"} catch {message=error.localizedDescription}
      keySaving=false
     }
    }.disabled(keyLoading || keySaving)
    if keyLoading {Text("正在读取钥匙串，请处理系统授权提示。").font(.system(size:11)).foregroundStyle(.secondary)}
   HStack {Button(testing ? "正在测试…":"测试连接"){testing=true;Task {message=await controller.checkConnection();testing=false}}.disabled(testing || keyLoading || keySaving);Text("仅发送一段测试文字").font(.system(size:11)).foregroundStyle(.secondary)}
   if !message.isEmpty {Text(message).font(.system(size:12)).textSelection(.enabled)}
  }.task {
   guard !keyLoaded else {return}
   keyLoading=true
   let stored=await Keychain.read()
   guard !Task.isCancelled else {return}
   key=stored;keyLoaded=true;keyLoading=false
  }
 }
 private func row(_ title:String,detail:String,value:String)->some View {HStack {VStack(alignment:.leading,spacing:4){Text(title);Text(detail).font(.system(size:11)).foregroundStyle(.secondary)};Spacer();Text(value).font(.system(size:12)).foregroundStyle(Color.accentColor)}.padding(.vertical,6)}
 private func field(_ title:String,text:Binding<String>)->some View {VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:12)).foregroundStyle(.secondary);TextField(title,text:text).textFieldStyle(.roundedBorder)}}
 private func open(_ url:String){NSWorkspace.shared.open(URL(string:url)!)}
}
