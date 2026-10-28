import AVFoundation
public enum PCMResampler {
 public static func to16k(_ samples:[Float],sampleRate:Int) throws -> [Float] {
  guard sampleRate>=8000,sampleRate<=192000 else {throw SayseeError.message("不支持的麦克风采样率。")}
  guard !samples.isEmpty else {return []}
  if sampleRate==16000 {return samples}
  guard let source=AVAudioFormat(commonFormat:.pcmFormatFloat32,sampleRate:Double(sampleRate),channels:1,interleaved:false),
        let target=AVAudioFormat(commonFormat:.pcmFormatFloat32,sampleRate:16000,channels:1,interleaved:false),
        let input=AVAudioPCMBuffer(pcmFormat:source,frameCapacity:AVAudioFrameCount(samples.count)),
        let output=AVAudioPCMBuffer(pcmFormat:target,frameCapacity:AVAudioFrameCount(ceil(Double(samples.count)*16000/Double(sampleRate)))+1024),
        let converter=AVAudioConverter(from:source,to:target) else {throw SayseeError.message("无法转换麦克风采样率。")}
  input.frameLength=AVAudioFrameCount(samples.count)
  samples.withUnsafeBufferPointer{input.floatChannelData![0].update(from:$0.baseAddress!,count:samples.count)}
  var supplied=false,error:NSError?
  let status=converter.convert(to:output,error:&error) {_,state in
   if supplied {state.pointee = .endOfStream;return nil}
   supplied=true;state.pointee = .haveData;return input
  }
  if let error=error {throw error}
  guard status != .error,output.frameLength>0 else {throw SayseeError.message("音频采样率转换失败。")}
  return Array(UnsafeBufferPointer(start:output.floatChannelData![0],count:Int(output.frameLength)))
 }
}
