// hear.swift <audio file> [window seconds] [--labels]  → JSON lines: {"t":start,"d":dur,"top":[["label",conf],…]}
// The Mac's own sound classifier (SoundAnalysis, version 1): nothing is downloaded, nothing leaves the machine.
import Foundation
import SoundAnalysis
import CoreMedia

final class Out: NSObject, SNResultsObserving {
  var done = false
  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let r = result as? SNClassificationResult else { return }
    let top = r.classifications.filter { $0.confidence >= 0.05 }.prefix(8).map { "[\"\($0.identifier)\",\(String(format: "%.2f", $0.confidence))]" }.joined(separator: ",")
    print("{\"t\":\(String(format: "%.2f", r.timeRange.start.seconds)),\"d\":\(String(format: "%.2f", r.timeRange.duration.seconds)),\"top\":[\(top)]}")
  }
  func request(_ request: SNRequest, didFailWithError error: Error) { FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!); done = true }
  func requestDidComplete(_ request: SNRequest) { done = true }
}
let a = CommandLine.arguments
do {
  let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
  if a.contains("--labels") { print(req.knownClassifications.joined(separator: "\n")); exit(0) }
  let win = a.count > 2 ? (Double(a[2]) ?? 1.0) : 1.0
  req.windowDuration = CMTime(seconds: win, preferredTimescale: 48000)
  req.overlapFactor = 0.75
  let an = try SNAudioFileAnalyzer(url: URL(fileURLWithPath: a[1]))
  let out = Out()
  try an.add(req, withObserver: out)
  an.analyze()
} catch { FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!); exit(1) }
