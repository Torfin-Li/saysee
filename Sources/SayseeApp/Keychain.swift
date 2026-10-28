import Foundation
import Security
import SayseeCore
struct Keychain {
 static func read() async -> String {
  await Task.detached(priority:.userInitiated) {readSynchronously()}.value
 }
 static func save(_ key:String) async throws {
  try await Task.detached(priority:.userInitiated) {try saveSynchronously(key)}.value
 }
 private static func readSynchronously() -> String {
  let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.saysee.app",kSecAttrAccount as String:"deepseek",kSecReturnData as String:true]
  var result:CFTypeRef?;guard SecItemCopyMatching(query as CFDictionary,&result)==errSecSuccess,let data=result as? Data else {return ""};return String(data:data,encoding:.utf8) ?? ""
 }
 private static func saveSynchronously(_ key:String) throws {
  let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.saysee.app",kSecAttrAccount as String:"deepseek"]
  if key.isEmpty {
   let status=SecItemDelete(query as CFDictionary)
   guard status==errSecSuccess || status==errSecItemNotFound else {throw SayseeError.message("密钥移除失败（\(status)）。")}
   return
  }
  let data=Data(key.utf8);let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
  if status==errSecItemNotFound {var add=query;add[kSecValueData as String]=data;let status=SecItemAdd(add as CFDictionary,nil);guard status==errSecSuccess else {throw SayseeError.message("密钥保存失败（\(status)）。")}}
  else if status != errSecSuccess {throw SayseeError.message("密钥更新失败（\(status)）。")}
 }
}
