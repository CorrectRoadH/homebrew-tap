class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.4.1"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.4.1/harness-lint-macos-aarch64"
    sha256 "050e3f95e70d9fd7833e91b96a46b5086fbf43fe12582e99c7d19d646867ca52"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.4.1/harness-lint-linux-x86_64"
    sha256 "f154bbf92c7a1a17060c2d0918fac01c64d9b99bdd87b5b584816c98693c02f9"
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
