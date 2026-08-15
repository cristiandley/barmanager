import AppKit

/// Ventana transparente y sin interacción que se coloca sobre la franja de la
/// barra de menús, un nivel por debajo de los status items, y pinta una
/// "píldora" de color detrás de cada grupo de iconos.
final class GroupBackgrounds {
    private let window: NSWindow
    private let view = BackgroundsView()

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Los status items viven en el nivel 25 (kCGStatusWindowLevel); esta
        // ventana va en el 24, por encima del fondo de la barra pero debajo
        // de los iconos.
        window.level = .mainMenu
        window.contentView = view
    }

    /// `hidden`/`visible` en coordenadas de pantalla (Cocoa); `barStrip` es la
    /// franja completa de la barra en la pantalla del separador.
    func show(hidden: CGRect?, visible: CGRect?, barStrip: CGRect) {
        window.setFrame(barStrip, display: false)
        view.hiddenPill = hidden.map { local($0, in: barStrip) }
        view.visiblePill = visible.map { local($0, in: barStrip) }
        view.needsDisplay = true
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func local(_ rect: CGRect, in strip: CGRect) -> CGRect {
        CGRect(x: rect.minX - strip.minX, y: rect.minY - strip.minY,
               width: rect.width, height: rect.height)
    }
}

private final class BackgroundsView: NSView {
    var hiddenPill: CGRect?
    var visiblePill: CGRect?

    override func draw(_ dirtyRect: NSRect) {
        if let rect = hiddenPill {
            fillPill(rect, color: NSColor.systemBlue.withAlphaComponent(0.22))
        }
        if let rect = visiblePill {
            fillPill(rect, color: NSColor.systemGray.withAlphaComponent(0.28))
        }
    }

    private func fillPill(_ rect: CGRect, color: NSColor) {
        let radius = min(6, rect.height / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        color.setFill()
        path.fill()
    }
}
