import AppKit

// Modo CLI: `BarManager toggle` / `BarManager reveal` avisa a la instancia en
// ejecución y termina. Útil para scripts o atajos de teclado de terceros.
if CommandLine.arguments.count > 1 {
    let command = CommandLine.arguments[1]
    let names = ["toggle": "com.cristiandley.barmanager.toggle",
                 "reveal": "com.cristiandley.barmanager.reveal"]
    guard let name = names[command] else {
        FileHandle.standardError.write(Data("Uso: BarManager [toggle|reveal]\n".utf8))
        exit(2)
    }
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory: sin icono en el Dock ni menú propio; solo vive en la barra de menús.
app.setActivationPolicy(.accessory)
app.run()
