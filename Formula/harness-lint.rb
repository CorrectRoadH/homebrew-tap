class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.2.4"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.4/harness-lint-macos-aarch64"
    sha256 "de084cd3f3a551f34ebc506527fec08a4f533777b701d82d3c5ac21558029566"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.4/harness-lint-linux-x86_64"
    sha256 "23f69e0f62b13bb19e2076a4a547741abf916a88bdf52dee8f3a82e5437ecb22"
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
