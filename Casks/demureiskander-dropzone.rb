cask "demureiskander-dropzone" do
  version "0.1.6"
  sha256 "ecde59bd98b9d26b6825e02c92e763226973545bf0440458f5b461c78cb288cb"

  url "https://github.com/demureiskander/dropzone/releases/download/v#{version}/Dropzone-#{version}-macOS-arm64.dmg"
  name "Dropzone"
  desc "Open-source floating file shelf with shake, notch, and pointer following"
  homepage "https://github.com/demureiskander/dropzone"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Dropzone.app"

  uninstall quit: "io.github.demureiskander.dropzone"

  zap trash: [
    "~/Library/Preferences/io.github.demureiskander.dropzone.plist",
    "~/Library/Saved Application State/io.github.demureiskander.dropzone.savedState",
  ]

  caveats <<~EOS
    This is an alpha build, ad-hoc signed and not notarized by Apple.
    It is independent of the commercial Dropzone by Aptonic.
  EOS
end
