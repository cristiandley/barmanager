# Cask para Homebrew. Va en el repo del tap:
#   github.com/cristiandley/homebrew-tap → Casks/barmanager.rb
# Tras cada release: actualizar `version` y `sha256` (lo imprime release.sh).
#
# Instalación (mientras la app no esté notarizada):
#   brew install --no-quarantine cristiandley/tap/barmanager
cask "barmanager" do
  version "1.0.0"
  sha256 "REEMPLAZAR_CON_EL_SHA256_DEL_ZIP"

  url "https://github.com/cristiandley/barmanager/releases/download/v#{version}/BarManager-#{version}.zip"
  name "BarManager"
  desc "Menu bar icon organizer with collapsible groups"
  homepage "https://github.com/cristiandley/barmanager"

  depends_on macos: ">= :ventura"

  app "BarManager.app"

  zap trash: [
    "~/Library/Preferences/com.cristiandley.barmanager.plist",
  ]
end
