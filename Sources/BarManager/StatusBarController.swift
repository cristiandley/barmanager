import AppKit
import ServiceManagement

/// Controla los tres grupos de la barra de menús:
///
///   [siempre ocultos] ┊ [ocultos] | [visibles] ‹
///
/// Los grupos se delimitan con dos separadores (NSStatusItem). Colapsar un grupo
/// consiste en inflar el ancho de su separador (~10.000 px) para empujar todo lo
/// que esté a su izquierda fuera de la pantalla. El usuario decide qué icono va
/// en qué grupo arrastrándolo con ⌘ a un lado u otro de los separadores.
final class StatusBarController: NSObject {

    private enum State: String {
        /// Solo se ve el grupo "visibles".
        case collapsed
        /// Se ven "visibles" y "ocultos"; "siempre ocultos" sigue fuera.
        case expanded
        /// Se ve todo, incluido el grupo "siempre ocultos".
        case revealAll
    }

    private enum DefaultsKey {
        static let collapsed = "barmanager.collapsed"
        static let autoCollapse = "barmanager.autoCollapse"
        static let alwaysHiddenEnabled = "barmanager.alwaysHiddenEnabled"
        static let groupBackgrounds = "barmanager.groupBackgrounds"
    }

    private static let separatorLength: CGFloat = 10
    private static let expandedBarLength: CGFloat = 10_000
    private static let autoCollapseDelay: TimeInterval = 10

    // El orden de creación importa: el primero queda más a la derecha.
    private let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hiddenSeparator = NSStatusBar.system.statusItem(withLength: separatorLength)
    private let alwaysHiddenSeparator = NSStatusBar.system.statusItem(withLength: separatorLength)

    private let defaults = UserDefaults.standard
    private let groupBackgrounds = GroupBackgrounds()
    private var autoCollapseTimer: Timer?
    private var backgroundsTimer: Timer?

    private var state: State {
        didSet {
            defaults.set(state == .collapsed, forKey: DefaultsKey.collapsed)
            apply()
        }
    }

    private var autoCollapseEnabled: Bool {
        didSet { defaults.set(autoCollapseEnabled, forKey: DefaultsKey.autoCollapse) }
    }

    private var alwaysHiddenEnabled: Bool {
        didSet { defaults.set(alwaysHiddenEnabled, forKey: DefaultsKey.alwaysHiddenEnabled) }
    }

    private var groupBackgroundsEnabled: Bool {
        didSet { defaults.set(groupBackgroundsEnabled, forKey: DefaultsKey.groupBackgrounds) }
    }

    override init() {
        defaults.register(defaults: [
            DefaultsKey.collapsed: false,
            DefaultsKey.autoCollapse: false,
            DefaultsKey.alwaysHiddenEnabled: false,
            DefaultsKey.groupBackgrounds: true,
        ])
        state = defaults.bool(forKey: DefaultsKey.collapsed) ? .collapsed : .expanded
        autoCollapseEnabled = defaults.bool(forKey: DefaultsKey.autoCollapse)
        alwaysHiddenEnabled = defaults.bool(forKey: DefaultsKey.alwaysHiddenEnabled)
        groupBackgroundsEnabled = defaults.bool(forKey: DefaultsKey.groupBackgrounds)
        super.init()

        toggleItem.autosaveName = "barmanager.toggle"
        hiddenSeparator.autosaveName = "barmanager.separator.hidden"
        alwaysHiddenSeparator.autosaveName = "barmanager.separator.alwaysHidden"

        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(didClickToggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "BarManager — clic: ocultar/mostrar · ⌥ clic: mostrar todo · clic derecho: menú"
        }
        hiddenSeparator.button?.toolTip = "BarManager — límite del grupo «ocultos» (mover con ⌘+arrastrar)"
        alwaysHiddenSeparator.button?.toolTip = "BarManager — límite del grupo «siempre ocultos» (mover con ⌘+arrastrar)"

        // Permite alternar desde fuera (scripts, atajos de teclado de terceros):
        //   BarManager toggle | reveal  →  ver main.swift
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalToggle),
            name: Notification.Name("com.cristiandley.barmanager.toggle"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(externalReveal),
            name: Notification.Name("com.cristiandley.barmanager.reveal"), object: nil)

        apply()
    }

    // MARK: - Estado

    private func apply() {
        alwaysHiddenSeparator.isVisible = alwaysHiddenEnabled

        switch state {
        case .collapsed:
            setBar(hiddenSeparator, expanded: true, dashed: false)
            setBar(alwaysHiddenSeparator, expanded: true, dashed: true)
            setToggleSymbol("chevron.left", description: "Mostrar iconos ocultos", fill: nil)
        case .expanded:
            setBar(hiddenSeparator, expanded: false, dashed: false)
            setBar(alwaysHiddenSeparator, expanded: true, dashed: true)
            setToggleSymbol("chevron.right.circle.fill", description: "Ocultar iconos", fill: .systemRed)
        case .revealAll:
            setBar(hiddenSeparator, expanded: false, dashed: false)
            setBar(alwaysHiddenSeparator, expanded: false, dashed: true)
            setToggleSymbol("eye.circle.fill", description: "Mostrando todo", fill: .systemOrange)
        }

        scheduleAutoCollapseIfNeeded()
        // La barra tarda unos instantes en reacomodar los iconos tras cambiar
        // el largo del separador; una ráfaga de recálculos evita que el fondo
        // aparezca con retraso.
        for delay in [0.0, 0.1, 0.25, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshGroupBackgrounds()
            }
        }
        scheduleBackgroundsRefresh()
    }

    /// Un separador "expandido" ocupa 10.000 px y empuja su grupo fuera de la
    /// pantalla; sin imagen para que la franja quede en blanco.
    private func setBar(_ item: NSStatusItem, expanded: Bool, dashed: Bool) {
        if expanded {
            item.length = Self.expandedBarLength
            item.button?.image = nil
        } else {
            item.length = Self.separatorLength
            item.button?.image = Self.separatorImage(dashed: dashed)
        }
    }

    /// Con `fill`, el símbolo (variante .circle.fill) se pinta a color:
    /// glifo blanco sobre el círculo relleno. Sin `fill`, monocromo estándar.
    private func setToggleSymbol(_ name: String, description: String, fill: NSColor?) {
        var config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let fill {
            config = config.applying(.init(paletteColors: [.white, fill]))
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(config)
        image?.isTemplate = (fill == nil)
        toggleItem.button?.image = image
    }

    private func scheduleAutoCollapseIfNeeded() {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
        guard autoCollapseEnabled, state != .collapsed else { return }
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: Self.autoCollapseDelay, repeats: false) { [weak self] _ in
            self?.state = .collapsed
        }
    }

    // MARK: - Fondos de grupos

    /// Recalcula las píldoras de fondo a partir de la posición real de cada
    /// icono de la barra (ventanas del nivel de status items).
    private func refreshGroupBackgrounds() {
        guard groupBackgroundsEnabled, state != .collapsed,
              let separatorWindow = hiddenSeparator.button?.window,
              let screen = separatorWindow.screen else {
            groupBackgrounds.hide()
            return
        }

        let separator = separatorWindow.frame
        let barStrip = CGRect(x: screen.frame.minX, y: separator.minY,
                              width: screen.frame.width, height: separator.height)

        // Se descartan los separadores inflados (ancho enorme) y todo lo que
        // no esté en la franja vertical de esta barra.
        let items = Self.statusItemFrames(nearBarCenterY: separator.midY)
            .filter { $0.width < 500 }
            .map { $0.intersection(screen.frame) }
            .filter { !$0.isEmpty }

        let hiddenItems = items.filter { $0.maxX <= separator.minX + 1 }
        let visibleItems = items.filter { $0.minX >= separator.maxX - 1 }

        if ProcessInfo.processInfo.environment["BARMANAGER_DEBUG"] != nil {
            var dump = "separator=\(separator)\n"
            dump += Self.statusItemFrames(nearBarCenterY: separator.midY)
                .map { "item x=\($0.minX) w=\($0.width) y=\($0.minY) h=\($0.height)" }
                .joined(separator: "\n")
            try? dump.write(toFile: "/tmp/barmanager_debug.txt", atomically: true, encoding: .utf8)
        }

        func pill(_ rects: [CGRect]) -> CGRect? {
            guard let first = rects.first else { return nil }
            let union = rects.dropFirst().reduce(first) { $0.union($1) }
            return union.insetBy(dx: -2, dy: 3)
        }

        groupBackgrounds.show(hidden: pill(hiddenItems), visible: pill(visibleItems), barStrip: barStrip)
    }

    private func scheduleBackgroundsRefresh() {
        backgroundsTimer?.invalidate()
        backgroundsTimer = nil
        guard groupBackgroundsEnabled, state != .collapsed else { return }
        backgroundsTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshGroupBackgrounds()
        }
    }

    /// Marcos (coordenadas Cocoa) de todas las ventanas al nivel de los status
    /// items cuyo centro vertical coincide con la barra indicada. No requiere
    /// permisos: solo se consultan posiciones, no nombres ni contenido.
    private static func statusItemFrames(nearBarCenterY barY: CGFloat) -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.maxY
            ?? NSScreen.main?.frame.maxY ?? 0

        var frames: [CGRect] = []
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == statusLevel,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            // CGWindowList usa origen arriba-izquierda; Cocoa, abajo-izquierda.
            let cocoa = CGRect(x: bounds.minX, y: primaryHeight - bounds.maxY,
                               width: bounds.width, height: bounds.height)
            if abs(cocoa.midY - barY) < 8 {
                frames.append(cocoa)
            }
        }
        return frames
    }

    // MARK: - Interacción

    @objc private func didClickToggle() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
            return
        }

        if event.modifierFlags.contains(.option), alwaysHiddenEnabled {
            state = (state == .revealAll) ? .expanded : .revealAll
        } else {
            state = (state == .collapsed) ? .expanded : .collapsed
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let revealItem = NSMenuItem(title: "Mostrar todo (⌥ clic)", action: #selector(revealAllFromMenu), keyEquivalent: "")
        revealItem.target = self
        revealItem.isEnabled = alwaysHiddenEnabled
        menu.addItem(revealItem)

        menu.addItem(.separator())

        let alwaysHiddenItem = NSMenuItem(title: "Grupo «siempre ocultos»", action: #selector(toggleAlwaysHidden), keyEquivalent: "")
        alwaysHiddenItem.target = self
        alwaysHiddenItem.state = alwaysHiddenEnabled ? .on : .off
        menu.addItem(alwaysHiddenItem)

        let autoItem = NSMenuItem(title: "Ocultar automáticamente (10 s)", action: #selector(toggleAutoCollapse), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = autoCollapseEnabled ? .on : .off
        menu.addItem(autoItem)

        let backgroundsItem = NSMenuItem(title: "Fondos de grupos", action: #selector(toggleGroupBackgrounds), keyEquivalent: "")
        backgroundsItem.target = self
        backgroundsItem.state = groupBackgroundsEnabled ? .on : .off
        menu.addItem(backgroundsItem)

        if isBundledApp {
            let loginItem = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            loginItem.target = self
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(loginItem)
        }

        menu.addItem(.separator())

        let helpItem = NSMenuItem(title: "Mueve iconos entre grupos con ⌘+arrastrar", action: nil, keyEquivalent: "")
        helpItem.isEnabled = false
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Salir de BarManager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        // Truco estándar: asignar el menú, abrirlo y soltarlo para que el
        // clic izquierdo siga llegando a la acción del botón.
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func revealAllFromMenu() {
        state = .revealAll
    }

    @objc private func externalToggle() {
        state = (state == .collapsed) ? .expanded : .collapsed
    }

    @objc private func externalReveal() {
        state = (state == .revealAll) ? .expanded : .revealAll
    }

    @objc private func toggleAlwaysHidden() {
        alwaysHiddenEnabled.toggle()
        if !alwaysHiddenEnabled, state == .revealAll {
            state = .expanded
        } else {
            apply()
        }
    }

    @objc private func toggleAutoCollapse() {
        autoCollapseEnabled.toggle()
        scheduleAutoCollapseIfNeeded()
    }

    @objc private func toggleGroupBackgrounds() {
        groupBackgroundsEnabled.toggle()
        refreshGroupBackgrounds()
        scheduleBackgroundsRefresh()
    }

    // MARK: - Abrir al iniciar sesión

    private var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("BarManager: no se pudo cambiar el inicio de sesión: \(error)")
        }
    }

    // MARK: - Dibujo

    /// Barra vertical fina; discontinua para el separador de «siempre ocultos».
    private static func separatorImage(dashed: Bool) -> NSImage {
        let size = NSSize(width: separatorLength, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: size.width / 2, y: 2))
            path.line(to: NSPoint(x: size.width / 2, y: size.height - 2))
            path.lineWidth = 2
            path.lineCapStyle = .round
            if dashed {
                path.setLineDash([0.5, 4.5], count: 2, phase: 0)
            }
            NSColor.black.withAlphaComponent(0.45).setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
