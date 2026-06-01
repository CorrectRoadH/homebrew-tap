class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.2.0"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.0/harness-lint-macos-aarch64"
    sha256 "7bf303ea0aa11fa8e30093654aecf8a9692f35de025ea17d873681f84acd1497"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.0/harness-lint-linux-x86_64"
    sha256 "e03e24349c5e1e4bd3c37038c008462f85160687408597972b931f25e368c241"
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
