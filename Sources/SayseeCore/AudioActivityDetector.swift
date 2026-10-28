import Foundation

/// Lightweight sound-activity gate for the indicator only; never trims STT audio.
/// 20 ms RMS windows, separate on/off thresholds, 60 ms attack and 200 ms release.
public struct AudioActivityDetector {
 public private(set) var isActive=false
 private var rate=0.0,sum=0.0,previousInput=0.0,previousOutput=0.0
 private var count=0,onWindows=0,offWindows=0
 public init() {}
 public mutating func reset() {self=Self()}
 public mutating func consume(_ samples:[Float],sampleRate:Double) {
  guard sampleRate.isFinite,sampleRate>=8000,sampleRate<=192000 else {return}
  if rate != sampleRate {reset();rate=sampleRate}
  let window=max(1,Int((sampleRate*0.02).rounded()))
  let alpha=exp(-2*Double.pi*100/sampleRate)
  for sample in samples {
   let x=sample.isFinite ? Double(sample):0
   // Suppress DC and low-frequency rumble without changing captured audio.
   let y=alpha*(previousOutput+x-previousInput)
   previousInput=x;previousOutput=y;sum+=y*y;count+=1
   if count==window {
    let db=20*log10(max(sqrt(sum/Double(count)),1e-8))
    if isActive {
     offWindows=db < -48 ? offWindows+1:0
     if offWindows>=10 {isActive=false;onWindows=0;offWindows=0}
    } else {
     onWindows=db > -42 ? onWindows+1:0
     if onWindows>=3 {isActive=true;onWindows=0;offWindows=0}
    }
    sum=0;count=0
   }
  }
 }
}
