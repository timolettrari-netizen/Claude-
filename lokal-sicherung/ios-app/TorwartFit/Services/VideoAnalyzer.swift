import Foundation
import AVFoundation
import Vision
import UIKit

/// Ein ausgewertetes Einzelbild aus dem Video
struct AnalyzedFrame: Identifiable {
    let id = UUID()
    let index: Int            // 1 … n
    let time: Double          // Sekunde im Video
    let image: UIImage        // mit eingezeichnetem Skelett
    let jpeg: Data            // für Claude
    let measurements: String  // z. B. "Knie L 95°, R 98° …" oder leer
    let personFound: Bool
}

/// Zieht Einzelbilder aus einem Video, erkennt die Körperhaltung (auf dem Gerät) und misst Gelenkwinkel.
enum VideoAnalyzer {
    static let frameCount = 12
    static let maxSide: CGFloat = 768

    enum Failure: LocalizedError {
        case unreadable, tooShort
        var errorDescription: String? {
            switch self {
            case .unreadable: return "Das Video konnte nicht gelesen werden."
            case .tooShort: return "Das Video ist zu kurz. Filme mindestens eine ganze Wiederholung (2–3 Sekunden)."
            }
        }
    }

    static func analyze(url: URL, progress: @escaping (Double) -> Void) async throws -> (frames: [AnalyzedFrame], duration: Double) {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite else { throw Failure.unreadable }
        guard duration >= 1.0 else { throw Failure.tooShort }

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxSide, height: maxSide)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        // Bei langen Videos nur die ersten 40 Sekunden – dort sind meist die ersten Wiederholungen
        let span = min(duration, 40)
        var frames: [AnalyzedFrame] = []
        for i in 0..<frameCount {
            let t = span * (0.03 + 0.94 * Double(i) / Double(frameCount - 1))
            guard let cg = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)).image else { continue }
            let pose = detectPose(cg)
            let annotated = draw(cg, pose: pose)
            let jpeg = annotated.jpegData(compressionQuality: 0.6) ?? Data()
            frames.append(AnalyzedFrame(index: frames.count + 1, time: t, image: annotated, jpeg: jpeg,
                                        measurements: pose.map(measure) ?? "", personFound: pose != nil))
            await MainActor.run { progress(Double(i + 1) / Double(frameCount)) }
        }
        guard !frames.isEmpty else { throw Failure.unreadable }
        return (frames, duration)
    }

    // MARK: Körperhaltung

    typealias Joints = [VNHumanBodyPoseObservation.JointName: CGPoint]   // Bildkoordinaten (Pixel, Ursprung oben links)

    private static func detectPose(_ cg: CGImage) -> Joints? {
        let req = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        guard (try? handler.perform([req])) != nil,
              let obs = req.results?.max(by: { $0.confidence < $1.confidence }),
              let pts = try? obs.recognizedPoints(.all) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var out: Joints = [:]
        for (name, p) in pts where p.confidence > 0.3 {
            out[name] = CGPoint(x: p.location.x * w, y: (1 - p.location.y) * h)
        }
        return out.count >= 6 ? out : nil
    }

    /// Winkel am Punkt b zwischen a und c in Grad
    private static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Int {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y), v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let m = sqrt(v1.dx * v1.dx + v1.dy * v1.dy) * sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard m > 0 else { return 0 }
        return Int((acos(max(-1, min(1, dot / m))) * 180 / .pi).rounded())
    }

    private static func measure(_ j: Joints) -> String {
        typealias J = VNHumanBodyPoseObservation.JointName
        var parts: [String] = []
        func tri(_ label: String, _ a: J, _ b: J, _ c: J) {
            if let pa = j[a], let pb = j[b], let pc = j[c] { parts.append("\(label) \(angle(pa, pb, pc))°") }
        }
        tri("Knie L", .leftHip, .leftKnee, .leftAnkle)
        tri("Knie R", .rightHip, .rightKnee, .rightAnkle)
        tri("Hüfte L", .leftShoulder, .leftHip, .leftKnee)
        tri("Hüfte R", .rightShoulder, .rightHip, .rightKnee)
        tri("Ellbogen L", .leftShoulder, .leftElbow, .leftWrist)
        tri("Ellbogen R", .rightShoulder, .rightElbow, .rightWrist)
        tri("Schulter L", .leftHip, .leftShoulder, .leftElbow)
        tri("Schulter R", .rightHip, .rightShoulder, .rightElbow)
        // Rumpfneigung gegenüber der Senkrechten
        if let ls = j[.leftShoulder], let rs = j[.rightShoulder], let lh = j[.leftHip], let rh = j[.rightHip] {
            let s = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2), h = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            let lean = Int((atan2(abs(s.x - h.x), abs(h.y - s.y)) * 180 / .pi).rounded())
            parts.append("Rumpfneigung \(lean)°")
        }
        // Knie- im Verhältnis zur Fußbreite (nur bei Ansicht von vorne sinnvoll: < 0,8 deutet auf nach innen kippende Knie)
        if let lk = j[.leftKnee], let rk = j[.rightKnee], let la = j[.leftAnkle], let ra = j[.rightAnkle] {
            let kw = abs(lk.x - rk.x), aw = abs(la.x - ra.x)
            if aw > 20 { parts.append(String(format: "Kniebreite/Fußbreite %.2f", kw / aw)) }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Zeichnen

    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist), (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .nose),
    ]

    private static func draw(_ cg: CGImage, pose: Joints?) -> UIImage {
        let size = CGSize(width: cg.width, height: cg.height)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: size))
            guard let j = pose else { return }
            let c = ctx.cgContext
            let lw = max(2, size.width / 220)
            c.setLineCap(.round)
            for (a, b) in bones {
                guard let pa = j[a], let pb = j[b] else { continue }
                // linke Körperseite grün, rechte orange
                let left = [a, b].contains { "\($0.rawValue)".lowercased().contains("left") }
                c.setStrokeColor((left ? UIColor(red: 0.78, green: 0.96, blue: 0.2, alpha: 0.9) : UIColor.orange.withAlphaComponent(0.9)).cgColor)
                c.setLineWidth(lw)
                c.move(to: pa); c.addLine(to: pb); c.strokePath()
            }
            c.setFillColor(UIColor.white.cgColor)
            for p in j.values { c.fillEllipse(in: CGRect(x: p.x - lw, y: p.y - lw, width: lw * 2, height: lw * 2)) }
        }
    }
}
