cask "herdr-app" do
  version "0.1.18"
  sha256 "fc1d3dd4255b2c00e5f128b6aa99c340546973f4f227949ef76e48aa8c55dd3f"

  url "https://github.com/CorrectRoadH/herdr-app/releases/download/v#{version}/herdr-app-macos-x86_64.tar.gz"
  name "Herdr"
  desc "Desktop app for the Herdr terminal workspace"
  homepage "https://github.com/CorrectRoadH/herdr-app"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :x86_64
  # The executable declares macOS 10.12, below Homebrew's minimum.
  depends_on :macos

  app "Herdr.app"
  binary "#{appdir}/Herdr.app/Contents/MacOS/Herdr", target: "herdr-app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Herdr.app"]
  end

  zap trash: "~/.config/herdr-app"

  caveats <<~EOS
    This Intel build is ad hoc signed and has not been notarized by Apple.
  EOS
end
