public enum TextTargetPolicy {
 public static func accepts(role:String,subrole:String?,writable:Bool)->Bool {
  writable && ["AXTextField","AXTextArea"].contains(role) && subrole != "AXSecureTextField"
 }
}
