import SwiftUI

/// Draws any of the six usage-icon concepts, faithfully porting the
/// prototype `makeStage(pct)` geometry (see design_handoff … makeStage()).
///
/// `fraction` is the *consumed* amount 0…1 (full = nearly exhausted).
/// All coordinates below are in the design's SVG viewBox space and are
/// scaled to fit the requested render size.
struct UsageIconCanvas: View {
    let concept: IconConcept
    let fraction: Double
    /// Status/monochrome color for the progress element.
    var color: Color = Palette.mono
    /// Track (unfilled) color.
    var trackColor: Color = Color.black.opacity(0.14)
    /// Hamster silhouette + feature colors (appearance dependent).
    var hamsterSilhouette: Color = Palette.hamsterLight
    var hamsterFace: Color = Palette.hamsterFaceLight

    var body: some View {
        Canvas { ctx, size in
            let p = max(0, min(1, fraction))
            switch concept {
            case .ring:    drawRing(ctx, size, p, radius: 8.5, width: 3)
            case .donut:   drawRing(ctx, size, p, radius: 7, width: 6)
            case .battery: drawBattery(ctx, size, p)
            case .liquid:  drawLiquid(ctx, size, p)
            case .eclipse: drawEclipse(ctx, size, p)
            case .hamster: drawHamster(ctx, size, p)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - viewBox scaling helpers

    /// Maps a point in `viewBox` coordinates to render coordinates, fitting
    /// (aspect-preserving, centered) inside `size`.
    private func fit(_ size: CGSize, _ vbW: CGFloat, _ vbH: CGFloat)
        -> (scale: CGFloat, dx: CGFloat, dy: CGFloat) {
        let scale = min(size.width / vbW, size.height / vbH)
        let dx = (size.width - vbW * scale) / 2
        let dy = (size.height - vbH * scale) / 2
        return (scale, dx, dy)
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ f: (CGFloat, CGFloat, CGFloat)) -> CGPoint {
        CGPoint(x: f.1 + x * f.0, y: f.2 + y * f.0)
    }

    // MARK: - Ring / Donut

    private func drawRing(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double,
                          radius: CGFloat, width: CGFloat) {
        let f = fit(size, 24, 24)
        let c = pt(12, 12, f)
        let r = radius * f.0
        let lw = width * f.0

        var track = Path()
        track.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.stroke(track, with: .color(trackColor), lineWidth: lw)

        guard p > 0 else { return }
        var arc = Path()
        arc.addArc(center: c, radius: r,
                   startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * p),
                   clockwise: false)
        ctx.stroke(arc, with: .color(color),
                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // MARK: - Battery

    private func drawBattery(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double) {
        let f = fit(size, 24, 24)
        let s = f.0
        // body rect x1.5 y7.5 w17 h9 rx2.2 (stroke)
        let body = Path(roundedRect: CGRect(x: f.1 + 1.5 * s, y: f.2 + 7.5 * s,
                                            width: 17 * s, height: 9 * s),
                        cornerRadius: 2.2 * s)
        ctx.stroke(body, with: .color(trackColor.opacity(1)), lineWidth: 1.4 * s)
        // nib x19.4 y10 w1.7 h4
        let nib = Path(roundedRect: CGRect(x: f.1 + 19.4 * s, y: f.2 + 10 * s,
                                           width: 1.7 * s, height: 4 * s),
                       cornerRadius: 0.8 * s)
        ctx.fill(nib, with: .color(trackColor))
        // fill rect x3 y9 width=14*p h6 rx1
        let w = 14 * p * s
        if w > 0.5 {
            let fill = Path(roundedRect: CGRect(x: f.1 + 3 * s, y: f.2 + 9 * s,
                                                width: w, height: 6 * s),
                            cornerRadius: 1 * s)
            ctx.fill(fill, with: .color(color))
        }
    }

    // MARK: - Liquid

    private func drawLiquid(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double) {
        let f = fit(size, 24, 24)
        let s = f.0
        let container = CGRect(x: f.1 + 6.5 * s, y: f.2 + 2.5 * s, width: 11 * s, height: 19 * s)
        let containerPath = Path(roundedRect: container, cornerRadius: 3.5 * s)
        // fill (clipped to container): y = 2.5 + 19*(1-p), h = 19*p
        if p > 0 {
            var layer = ctx
            layer.clip(to: containerPath)
            let y = f.2 + (2.5 + 19 * (1 - p)) * s
            let h = 19 * p * s
            layer.fill(Path(CGRect(x: container.minX, y: y, width: container.width, height: h)),
                       with: .color(color))
        }
        ctx.stroke(containerPath, with: .color(trackColor), lineWidth: 1.6 * s)
    }

    // MARK: - Eclipse

    private func drawEclipse(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double) {
        let f = fit(size, 24, 24)
        let s = f.0
        let c = pt(12, 12, f)
        let r = 9 * s
        // track ring
        var track = Path()
        track.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

        // Disk with a shadow circle knocked out from the right.
        // shadow cx = 12 + 18*(1-p)
        let shadowCx = f.1 + (12 + 18 * (1 - p)) * s
        let shadowR = 9.2 * s
        ctx.drawLayer { layer in
            var disk = Path()
            disk.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            layer.fill(disk, with: .color(color))
            var shadow = Path()
            shadow.addEllipse(in: CGRect(x: shadowCx - shadowR, y: c.y - shadowR,
                                         width: shadowR * 2, height: shadowR * 2))
            layer.blendMode = .destinationOut
            layer.fill(shadow, with: .color(.black))
        }
        ctx.stroke(track, with: .color(trackColor), lineWidth: 1.4 * s)
    }

    // MARK: - Hamster (mono, form-driven cheeks)

    private func drawHamster(_ ctx: GraphicsContext, _ size: CGSize, _ p: Double) {
        let f = fit(size, 100, 96)
        let s = f.0
        let cheekR = (29 - 25 * p) * s

        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
            let c = pt(x, y, f)
            return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            let c = pt(x, y, f)
            return Path(ellipseIn: CGRect(x: c.x - rx * s, y: c.y - ry * s,
                                          width: rx * 2 * s, height: ry * 2 * s))
        }

        // silhouette: ears → cheeks → head (head on top)
        ctx.fill(circle(31, 24, 10 * s), with: .color(hamsterSilhouette))
        ctx.fill(circle(69, 24, 10 * s), with: .color(hamsterSilhouette))
        ctx.fill(circle(28, 60, cheekR), with: .color(hamsterSilhouette))
        ctx.fill(circle(72, 60, cheekR), with: .color(hamsterSilhouette))
        ctx.fill(circle(50, 46, 27 * s), with: .color(hamsterSilhouette))

        // features
        ctx.fill(ellipse(41, 44, 4.2, 7), with: .color(hamsterFace))
        ctx.fill(ellipse(59, 44, 4.2, 7), with: .color(hamsterFace))
        var nose = Path()
        nose.move(to: pt(46, 54, f)); nose.addLine(to: pt(54, 54, f))
        nose.addLine(to: pt(50, 61, f)); nose.closeSubpath()
        ctx.fill(nose, with: .color(hamsterFace))
        ctx.fill(circle(46.5, 67, 3.8 * s), with: .color(hamsterFace))
        ctx.fill(circle(53.5, 67, 3.8 * s), with: .color(hamsterFace))
    }
}
