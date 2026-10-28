import Foundation
import Darwin
public final class ProcessLock {
 private let descriptor:Int32
 public init(url:URL) throws {
  descriptor=Darwin.open(url.path,O_RDWR|O_CREAT,0o600)
  guard descriptor>=0 else {throw SayseeError.message("无法创建 Saysee 单实例锁。")}
  guard flock(descriptor,LOCK_EX|LOCK_NB)==0 else {Darwin.close(descriptor);throw SayseeError.message("Saysee 已在运行。")}
  let text=Data("\(ProcessInfo.processInfo.processIdentifier)".utf8);ftruncate(descriptor,0);text.withUnsafeBytes{_ = Darwin.write(descriptor,$0.baseAddress,text.count)}
 }
 deinit {flock(descriptor,LOCK_UN);Darwin.close(descriptor)}
}
