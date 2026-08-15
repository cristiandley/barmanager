# BarManager

App de barra de menús para macOS que colapsa y **agrupa** los iconos de estado
(estilo Hidden Bar / Ice), escrita en Swift puro con AppKit, sin dependencias.

## Grupos

La barra queda dividida en tres zonas por dos separadores propios:

```
┄  [siempre ocultos]  ┊  [ocultos]  |  [visibles]  ‹  🕐
```

- **Visibles** — a la derecha del separador sólido `|`. Siempre se ven.
- **Ocultos** — entre los dos separadores. Se ocultan al colapsar (clic en el chevron).
- **Siempre ocultos** — a la izquierda del separador discontinuo `┊`. Solo
  aparecen con ⌥ clic (o "Mostrar todo" en el menú).

Para mover un icono de un grupo a otro: **⌘ + arrastrar** el icono al otro lado
del separador (es la función nativa de macOS para reordenar la barra).

## Uso

El icono del chevron indica el estado:

| Icono | Estado | Acción al hacer clic |
|---|---|---|
| `‹` (monocromo) | Colapsado — hay iconos ocultos | Expandir |
| `›` (círculo rojo) | Expandido — se ve el grupo «ocultos» | Colapsar |
| 👁 (círculo naranja) | Mostrando todo, incluidos los «siempre ocultos» | — |

| Acción | Resultado |
|---|---|
| Clic en el chevron | Colapsa / expande el grupo «ocultos» |
| ⌥ clic | Muestra / esconde también el grupo «siempre ocultos» |
| Clic derecho | Menú: mostrar todo, activar grupos, auto-ocultar, abrir al iniciar sesión, salir |
| CLI | `BarManager toggle` / `BarManager reveal` (avisa a la instancia en ejecución) |

El grupo «siempre ocultos» viene desactivado por defecto; actívalo desde el
menú (clic derecho) cuando quieras un segundo nivel de ocultamiento.

### Fondos de grupos

Al expandir, cada grupo se resalta con una "píldora" de color: azul para el
grupo «ocultos», gris para los visibles. Se dibujan en una ventana transparente
colocada un nivel por debajo de los iconos de la barra (nivel 24 vs. 25), y la
extensión de cada grupo se calcula con `CGWindowListCopyWindowInfo` (solo
posiciones de ventanas; no requiere permisos). Se puede desactivar desde el
menú: "Fondos de grupos".

## Compilar y ejecutar

Prueba rápida (sin bundle):

```sh
swift run
```

App de verdad (`.app` con firma ad-hoc, sin icono en el Dock):

```sh
./Scripts/build-app.sh
open build/BarManager.app
```

> "Abrir al iniciar sesión" solo aparece en el menú cuando corre como `.app`.

## Publicar en Homebrew

1. Generar el artefacto del release (binario universal arm64 + x86_64):

   ```sh
   ./Scripts/release.sh 1.0.0
   ```

   Imprime la ruta del zip y su sha256. Con el repo en GitHub y el workflow de
   `.github/workflows/release.yml`, esto mismo ocurre solo al pushear un tag
   `v1.0.0` (crea el release con el zip adjunto).

2. Crear el repo del tap: `github.com/cristiandley/homebrew-tap`, copiar
   `packaging/barmanager.rb` a `Casks/barmanager.rb` y completar el `sha256`.

3. Instalar:

   ```sh
   brew install --no-quarantine cristiandley/tap/barmanager
   ```

   `--no-quarantine` hace falta mientras la firma sea ad-hoc; para eliminarlo
   hay que firmar con Developer ID y notarizar (Apple Developer Program). Eso
   también es requisito práctico para aspirar al repo oficial `homebrew/cask`,
   que además pide cierta tracción del proyecto (~75 estrellas en GitHub).

## Cómo funciona

No hay API pública para ocultar iconos de otras apps. El truco (el mismo de
Hidden Bar/Ice): cada separador es un `NSStatusItem`; para colapsar su grupo se
infla su `length` a ~10.000 px, empujando todo lo que esté a su izquierda fuera
de la pantalla. Expandir es devolverle su ancho normal.

## Limitaciones conocidas

- En Macs con notch, los iconos empujados pueden quedar debajo del notch en vez
  de fuera de pantalla; macOS ya oculta lo que no cabe, así que en la práctica
  funciona, pero el espacio útil es menor.
- La primera vez, macOS coloca los separadores juntos a la izquierda del reloj:
  acomódalos con ⌘ + arrastrar (la posición se recuerda entre sesiones).
