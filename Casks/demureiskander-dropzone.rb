cask "demureiskander-dropzone" do
  version "0.1.3"
  sha256 "ac7ddca9413f97c47be802cdc4ec9f1f296b8137e35ccc26fa3140fee890e1c1"

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
