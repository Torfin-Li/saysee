import Foundation
public enum DiagnosticLog {
 private static let queue=DispatchQueue(label:"saysee.diagnostics",qos:.utility)
 public static var directory:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Saysee")}
 public static var fileURL:URL {directory.appendingPathComponent("saysee.jsonl")}
 public static func now()->Double {ProcessInfo.processInfo.systemUptime}
 public static func milliseconds(since start:Double)->Double {(now()-start)*1000}
 public static func encode(stage:String,session:String?=nil,durationMs:Double?=nil,elapsedMs:Double?=nil,metadata:[String:String]=[:]) throws -> Data {
  let allowed:Set<String>=["model","provider","status","cache_hit","input_chars","output_chars","audio_ms","decode_ms","rtf","key_code","fn_down","modifiers","backend","listen_permission","ax_permission","pid","prompt_version","reason","error_domain","error_code","event_kind","ax_role","thinking"]
  let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
  var record:[String:Any]=["time":formatter.string(from:Date()),"stage":stage,"pid":ProcessInfo.processInfo.processIdentifier]
  if let session=session {record["session"]=session}
  if let value=durationMs,value.isFinite {record["duration_ms"]=(value*100).rounded()/100}
  if let value=elapsedMs,value.isFinite {record["elapsed_ms"]=(value*100).rounded()/100}
  for (key,value) in metadata where allowed.contains(key) {record[key]=value}
  return try JSONSerialization.data(withJSONObject:record,options:[.sortedKeys])
 }
 public static func emit(_ stage:String,session:UUID?=nil,since start:Double?=nil,elapsedSince origin:Double?=nil,metadata:[String:String]=[:]) {
  let duration=start.map{milliseconds(since:$0)},elapsed=origin.map{milliseconds(since:$0)}
  queue.async {
  guard var line=try? encode(stage:stage,session:session?.uuidString,durationMs:duration,elapsedMs:elapsed,metadata:metadata) else {return}
  line.append(10);FileHandle.standardError.write(line)
  do {
   try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
   let url=fileURL
   if let attrs=try? FileManager.default.attributesOfItem(atPath:url.path),let size=attrs[.size] as? NSNumber,size.intValue>5_000_000 {
    let old=url.appendingPathExtension("1");try? FileManager.default.removeItem(at:old);try FileManager.default.moveItem(at:url,to:old)
   }
   if !FileManager.default.fileExists(atPath:url.path) {FileManager.default.createFile(atPath:url.path,contents:nil,attributes:[.posixPermissions:0o600])}
   let handle=try FileHandle(forWritingTo:url);defer{try? handle.close()};try handle.seekToEnd();try handle.write(contentsOf:line)
  }catch { /* Console remains available if persistent logging is not writable. */ }
  }
 }
 public static func flush() {queue.sync {}}
}
