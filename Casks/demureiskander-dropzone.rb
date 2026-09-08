cask "demureiskander-dropzone" do
  version "0.1.5"
  sha256 "f9f70957f0b555395aaa24bdf2e359d2eefb1d655f877726bd8b191d4a1741cf"

  url "https://github.com/demureiskander/dropzone/releases/download/v#{version}/Dropzone-#{version}-macOS-arm64.dmg"
  name "Dropzone"
  desc "Open-source floating file shelf with shake, notch, and pointer following"
  homepage "https://github.com/demureiskander/dropzone"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Dropzone.app"

  caveats <<~EOS
    This is an alpha build, ad-hoc signed and not notarized by Apple.
    It is independent of the commercial Dropzone by Aptonic.
  EOS
end
