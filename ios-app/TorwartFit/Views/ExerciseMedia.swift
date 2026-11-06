import SwiftUI

/// Echte Fotos (Start ⇄ Ende) oder – wenn keine vorhanden – die animierte Figur.
struct ExerciseMedia: View {
    @EnvironmentObject var store: Store
    let id: String

    var body: some View {
        Group {
            if let p = store.photo(id) {
                PhotoLoop(name: p)
            } else {
                FigureView(id: id)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PhotoLoop: View {
    let name: String
    @State private var showEnd = false

    var body: some View {
        Color.black
            .aspectRatio(3 / 2, contentMode: .fit)
            .overlay {
                ZStack {
                    Image("\(name)-0").resizable().scaledToFill()
                    Image("\(name)-1").resizable().scaledToFill().opacity(showEnd ? 1 : 0)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text("Start ⇄ Ende")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
            .clipped()
            .onAppear {
                showEnd = false
                withAnimation(.easeInOut(duration: 1.1).delay(0.4).repeatForever(autoreverses: true)) { showEnd = true }
            }
    }
}

struct Thumb: View {
    @EnvironmentObject var store: Store
    let id: String
    var body: some View {
        Group {
            if let p = store.photo(id) {
                Image("\(p)-0").resizable().scaledToFill()
            } else {
                FigureView(id: id, still: true)
            }
        }
        .frame(width: 54, height: 54)
        .background(Color.card2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Animierte Figur aus den Posen der Web-App (Winkel in Grad, 0 = nach unten).
struct FigureView: View {
    @EnvironmentObject var store: Store
    let id: String
    var still = false

    var body: some View {
        Color.clear
            .aspectRatio(200 / 165, contentMode: .fit)
            .overlay {
                if still {
                    Canvas { ctx, size in draw(ctx: ctx, size: size, time: 0) }
                } else {
                    TimelineView(.animation) { tl in
                        Canvas { ctx, size in draw(ctx: ctx, size: size, time: tl.date.timeIntervalSinceReferenceDate) }
                    }
                }
            }
    }

    private func vec(_ deg: Double, _ len: Double) -> CGPoint {
        let r = deg * .pi / 180
        return CGPoint(x: sin(r) * len, y: cos(r) * len)
    }

    private func draw(ctx: GraphicsContext, size: CGSize, time: Double) {
        guard let anim = store.ex(id)?.anim,
              let pa = store.catalog.poses[anim.a], let pb = store.catalog.poses[anim.b],
              pa.count == 9, pb.count == 9 else { return }
        let ph = (1 - cos(2 * .pi * time / anim.period)) / 2
        let p = (0..<9).map { pa[$0] + (pb[$0] - pa[$0]) * ph }
        func add(_ o: CGPoint, _ a: Double, _ l: Double) -> CGPoint { let v = vec(a, l); return CGPoint(x: o.x + v.x, y: o.y + v.y) }
        let h = CGPoint.zero
        let sh = add(h, p[0], 38), head = add(sh, p[0], 14)
        let e1 = add(sh, p[1], 20), w1 = add(e1, p[2], 19), e2 = add(sh, p[3], 20), w2 = add(e2, p[4], 19)
        let k1 = add(h, p[5], 26), f1 = add(k1, p[6], 26), k2 = add(h, p[7], 26), f2 = add(k2, p[8], 26)
        let pts = [h, sh, e1, w1, e2, w2, k1, f1, k2, f2]
        let maxY = max(pts.map(\.y).max() ?? 0, head.y + 9)
        let lift = anim.hop * max(0, (ph - 0.55) / 0.45)
        let s = size.width / 200
        func T(_ q: CGPoint) -> CGPoint { CGPoint(x: (100 + q.x) * s, y: (150 - maxY + q.y - lift) * s) }
        func limb(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ c: Color) {
            var path = Path(); path.move(to: T(a)); path.addLine(to: T(b))
            ctx.stroke(path, with: .color(c), style: StrokeStyle(lineWidth: w * s, lineCap: .round))
        }
        // Boden
        var floor = Path(); floor.move(to: CGPoint(x: 0, y: 152 * s)); floor.addLine(to: CGPoint(x: size.width, y: 152 * s))
        ctx.stroke(floor, with: .color(.white.opacity(0.12)), lineWidth: 1)
        let skin = Color(red: 0.85, green: 0.64, blue: 0.49), far = Color(white: 0.3), shorts = Color(white: 0.16)
        // hinteres Bein / Arm
        limb(h, k2, 12, far); limb(k2, f2, 9, far); limb(sh, e2, 8, far); limb(e2, w2, 6.5, far)
        // Rumpf
        limb(h, sh, 18, .lime)
        limb(h, k1, 13, shorts); limb(k1, f1, 9.5, skin)
        let hc = T(head)
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x - 8.5 * s, y: hc.y - 9 * s, width: 17 * s, height: 18 * s)), with: .color(skin))
        limb(sh, e1, 9, .lime); limb(e1, w1, 7, skin)
    }
}
