public struct FnGesture {
 private var down=false,combined=false
 public init() {}
 public mutating func keyDown() {if down {combined=true}}
 public mutating func update(fn:Bool,other:Bool)->Bool {
  if fn && !down {down=true;combined=other}
  else if fn && other {combined=true}
  else if !fn && down {let trigger = !combined && !other;down=false;combined=false;return trigger}
  return false
 }
}
public enum KeyEventKind {case down,up,flags}
public extension FnGesture {
 mutating func handle(keyCode:Int,kind:KeyEventKind,fnFlag:Bool,other:Bool)->Bool {
  if keyCode==63 {
   switch kind {
   case .down:return update(fn:true,other:other)
   case .up:return update(fn:false,other:other)
   case .flags:return update(fn:fnFlag,other:other)
   }
  }
  if kind == .down {keyDown()}
  if kind == .flags && other {_ = update(fn:fnFlag,other:true)}
  return false
 }
}
public extension FnGesture {
 mutating func handleHID(page:UInt32,usage:UInt32,value:Int,other:Bool)->Bool? {
  guard page==0xff,usage==3 else {return nil}
  return update(fn:value != 0,other:other)
 }
}
