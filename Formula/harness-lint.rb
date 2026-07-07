class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.6.0"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.6.0/harness-lint-macos-aarch64"
    sha256 "dece406e047a317f2e259e3e370e19c1c4413393eb0de700b57cb57a3a860da6"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.6.0/harness-lint-linux-x86_64"
    sha256 "139f5e8473127a03aede19439339081c9263f83ca7ab328a1eea0d3f8acdd319"
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
