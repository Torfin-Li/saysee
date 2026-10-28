import AppKit
import ApplicationServices
import Carbon
import SayseeCore
struct TextTarget {
 let element:AXUIElement
 let pid:pid_t
}
@MainActor enum TextDelivery {
 private static func attribute(_ element:AXUIElement,_ name:String)->CFTypeRef? {
  var value:CFTypeRef?
  guard AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success else {return nil}
  return value
 }
 private static func elementAttribute(_ element:AXUIElement,_ name:String)->AXUIElement? {
  guard let value=attribute(element,name),CFGetTypeID(value)==AXUIElementGetTypeID() else {return nil}
  return unsafeBitCast(value,to:AXUIElement.self)
 }
 static func focus() -> TextTarget? {
  guard AXIsProcessTrusted(),!IsSecureEventInputEnabled(),let app=NSWorkspace.shared.frontmostApplication,app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
   DiagnosticLog.emit("delivery_target",metadata:["reason":"permission_secure_input_or_own_app"]);return nil
  }
  let root=AXUIElementCreateApplication(app.processIdentifier)
  let element=elementAttribute(root,kAXFocusedUIElementAttribute)
  let role=element.flatMap{attribute($0,kAXRoleAttribute) as? String}
  let subrole=element.flatMap{attribute($0,kAXSubroleAttribute) as? String}
  if let element=element {
   var writable:DarwinBoolean=false
   if AXUIElementIsAttributeSettable(element,kAXValueAttribute as CFString,&writable) == .success,
      TextTargetPolicy.accepts(role:role ?? "",subrole:subrole,writable:writable.boolValue) {
    DiagnosticLog.emit("delivery_target",metadata:["status":"text_control","ax_role":role ?? "unknown"])
    return TextTarget(element:element,pid:app.processIdentifier)
   }
  }
  DiagnosticLog.emit("delivery_target",metadata:["reason":"unsupported_or_noneditable_focus","ax_role":role ?? "unexposed"])
  return nil
 }
 static func copy(_ text:String) {NSPasteboard.general.clearContents();NSPasteboard.general.setString(text,forType:.string)}
 static func deliver(_ text:String,expected:TextTarget?) -> Bool {
  copy(text)
  guard let expected=expected else {DiagnosticLog.emit("delivery_skipped",metadata:["reason":"no_initial_target"]);return false}
  guard let now=focus(),now.pid==expected.pid,CFEqual(now.element,expected.element) else {
   DiagnosticLog.emit("delivery_skipped",metadata:["reason":"focus_changed_or_unavailable"]);return false
  }
  guard let down=CGEvent(keyboardEventSource:nil,virtualKey:9,keyDown:true),let up=CGEvent(keyboardEventSource:nil,virtualKey:9,keyDown:false) else {
   DiagnosticLog.emit("delivery_skipped",metadata:["reason":"event_creation_failed"]);return false
  }
  down.flags = .maskCommand;up.flags = .maskCommand
  down.post(tap:.cghidEventTap);up.post(tap:.cghidEventTap)
  DiagnosticLog.emit("paste_dispatched",metadata:["status":"text_control"]);return true
 }
}
