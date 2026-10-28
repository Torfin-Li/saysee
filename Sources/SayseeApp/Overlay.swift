import AppKit
import SwiftUI
@MainActor final class OverlayWindow {
 private let panel:NSPanel
 private let controller:SessionController
 init(controller:SessionController) {
  self.controller=controller
  panel=NSPanel(contentRect:NSRect(x:0,y:0,width:180,height:100),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.title="Saysee 语音浮层";panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.level = .floating;panel.hidesOnDeactivate=false;panel.becomesKeyOnlyIfNeeded=true
  panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];panel.isMovableByWindowBackground=false
  panel.contentView=NSHostingView(rootView:OverlayView(controller:controller))
 }
 func update() {
  if controller.phase == .idle {panel.orderOut(nil);return}
  let expanded=controller.phase == .result || controller.phase == .failed
  let size=NSSize(width:expanded ? 470:200,height:expanded ? 370:105)
  let screen=NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
  let frame=screen.visibleFrame
  panel.setFrame(NSRect(x:frame.midX-size.width/2,y:frame.minY+18,width:size.width,height:size.height),display:true)
  panel.orderFrontRegardless()
 }
}

private let mint=Color(red:0.57,green:0.89,blue:0.80)
struct OverlayView:View {
 @ObservedObject var controller:SessionController
 @State private var hovering=false
 var expanded:Bool {controller.phase == .result || controller.phase == .failed}
 var body:some View {
  VStack(spacing:9) {
   Spacer(minLength:0)
   if expanded {card} else {pill}
   if controller.phase == .recording {Text("Fn 或轻点结束 · Esc 取消").font(.system(size:11)).foregroundStyle(.secondary)}
  }.padding(12).frame(maxWidth:.infinity,maxHeight:.infinity)
 }
 private var pill:some View {
  Group {
   if controller.phase == .recording {
    Button(action:controller.stop) {pillContents}.buttonStyle(.plain)
   } else {
    pillContents.accessibilityElement(children:.combine)
   }
  }
   .onHover {hovering=$0}
   .help(controller.phase == .recording ? "点击或按 Fn 结束录音；Esc 取消":"Esc 取消")
   .accessibilityLabel(controller.phase == .recording ? "结束录音":pillLabel)
 }
 private var pillContents:some View {
   HStack(spacing:10) {
    if controller.phase == .success {
     Image(systemName:"checkmark").font(.system(size:16,weight:.medium)).foregroundStyle(mint).frame(width:37,height:24)
    } else {VoiceIndicator(active:controller.voiceActive,processing:controller.phase == .thinking)}
    Text(pillLabel).font(.system(size:11,weight:.medium)).tracking(0.3).foregroundStyle(Color(red:0.87,green:0.94,blue:0.89)).frame(width:42,alignment:.leading)
   }.frame(width:132,height:44)
    .background(hovering && controller.phase == .recording ? Color(red:0.18,green:0.29,blue:0.24):controller.voiceActive ? Color(red:0.10,green:0.29,blue:0.22):Color(red:0.12,green:0.20,blue:0.17),in:Capsule())
    .overlay(Capsule().strokeBorder(controller.voiceActive ? mint.opacity(0.50):.white.opacity(0.14),lineWidth:0.7))
    .animation(.easeInOut(duration:0.20),value:controller.voiceActive)
    .shadow(color:.black.opacity(0.17),radius:12,y:5)
    .contentShape(Capsule())
 }
 private var pillLabel:String {
  switch controller.phase {
  case .recording:return hovering ? "结束":controller.voiceActive ? "收音中":"聆听中"
  case .preparing:return "准备中"
  case .thinking:return "整理中"
  case .success:return "已填入"
  default:return ""
  }
 }
 private var card:some View {
  VStack(alignment:.leading,spacing:0) {
   HStack {Image(systemName:controller.phase == .failed ? "exclamationmark.circle":"checkmark");Text(controller.phase == .failed ? "这次还没有整理完成":"文字已复制到剪贴板");Spacer();Button(action:controller.close){Image(systemName:"xmark").frame(width:25,height:25)}.buttonStyle(.plain).help("关闭")}.font(.system(size:12)).foregroundStyle(controller.phase == .failed ? Color.orange:Color.accentColor).padding(16)
   if controller.phase == .failed {Text(controller.errorMessage).font(.system(size:13)).foregroundStyle(.secondary).padding(.horizontal,18).padding(.bottom,10)}
   ScrollView {Text(controller.phase == .failed ? controller.raw:controller.output).font(.system(size:14)).lineSpacing(5).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,18).padding(.bottom,14)}.frame(maxHeight:.infinity)
   Divider()
   HStack {Text(controller.phase == .failed ? "原始转录已保留":"未自动填入，请在目标位置粘贴").font(.system(size:11)).foregroundStyle(.secondary);Spacer()
    if controller.phase == .failed {if !controller.raw.isEmpty {Button("复制原文",action:controller.useRaw)};Button("重试",action:controller.retry)}
    else {Button("复制文字",action:controller.copyResult)}
   }.controlSize(.small).padding(14)
  }.frame(width:440,height:330).background(Color(nsColor:.windowBackgroundColor),in:RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).stroke(.primary.opacity(0.06))).shadow(color:.black.opacity(0.15),radius:16,y:6)
 }
}
