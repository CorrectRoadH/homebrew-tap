class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.3.0"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.3.0/harness-lint-macos-aarch64"
    sha256 "15d49e382d0e25fdc6b3313559d305f00d2fe3728a12a04e699141ef060dde1c"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.3.0/harness-lint-linux-x86_64"
    sha256 "eca3b306dcd9db3d2a4812dc1d835e573a734ad2ab087704af2e5ca57d7b0693"
  else
    odie "harness-lint currently publishes macOS arm64 and Linux x86_64 binaries only"
  end

  def install
    if OS.mac?
      bin.install "harness-lint-macos-aarch64" => "harness-lint"
    else
      bin.install "harness-lint-linux-x86_64" => "harness-lint"
    end
  end

  test do
    system "#{bin}/harness-lint", "--help"
  end
end
