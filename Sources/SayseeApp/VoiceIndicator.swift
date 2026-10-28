import SwiftUI

/// Sound activity selects the animation; its amplitude is intentionally fixed.
struct VoiceIndicator:View {
 let active:Bool
 let processing:Bool
 @Environment(\.accessibilityReduceMotion) private var reducedMotion
 var body:some View {
  TimelineView(.animation(minimumInterval:1.0/30,paused:reducedMotion || (!active && !processing))) {context in
   VoiceIndicatorFrame(active:active,processing:processing,time:reducedMotion ? 0:context.date.timeIntervalSinceReferenceDate)
  }.accessibilityHidden(true)
 }
}

/// Stateless frame shared by the native view and deterministic visual checks.
struct VoiceIndicatorFrame:View {
 let active:Bool
 let processing:Bool
 let time:Double
 @Environment(\.accessibilityReduceMotion) private var reducedMotion
 private let accent=Color(red:0.70,green:0.98,blue:0.82)
 var body:some View {
  ZStack {
   if processing {
    ZStack {
     Circle().stroke(accent.opacity(0.24),lineWidth:2.2)
     Circle().trim(from:0.02,to:0.35)
      .stroke(accent,style:StrokeStyle(lineWidth:2.2,lineCap:.round))
      .rotationEffect(.degrees(time.truncatingRemainder(dividingBy:1.2)/1.2*360))
      .shadow(color:accent.opacity(0.25),radius:2)
    }.frame(width:20,height:20)
   } else {
    HStack(spacing:4) {
     ForEach(0..<3) {index in
      let wave=(sin(time*2*Double.pi/0.8+Double(index)*1.65)+1)/2
      Capsule()
       .fill(active ? accent:Color(red:0.53,green:0.69,blue:0.61))
       .frame(width:5.5,height:active ? 9+wave*17:4)
       .offset(y:active ? sin(time*2*Double.pi/0.8+Double(index)*1.65)*2.5:0)
     }
    }
   }
  }.frame(width:37,height:30)
   .animation(reducedMotion ? nil:.spring(response:0.26,dampingFraction:0.78),value:active)
 }
}
