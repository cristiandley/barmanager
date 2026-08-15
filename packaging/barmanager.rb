# Cask para Homebrew. Va en el repo del tap:
#   github.com/cristiandley/homebrew-tap → Casks/barmanager.rb
# Tras cada release: actualizar `version` y `sha256` (lo imprime release.sh).
#
#   brew install cristiandley/tap/barmanager
#
# La app está firmada ad-hoc (sin notarizar); el postflight limpia la
# cuarentena para que Gatekeeper no la bloquee. Al notarizar con Developer ID,
# eliminar el postflight.
cask "barmanager" do
  version "1.0.0"
  sha256 "6c5d2a2e049fbb257ca4b96399b91ba84347ba089808e9a0e529c89c352c31b0"

  url "https://github.com/cristiandley/barmanager/releases/download/v#{version}/BarManager-#{version}.zip"
  name "BarManager"
  desc "Menu bar icon organizer with collapsible groups"
  homepage "https://github.com/cristiandley/barmanager"

  app "BarManager.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/BarManager.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.cristiandley.barmanager.plist",
  ]
end
