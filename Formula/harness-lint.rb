class HarnessLint < Formula
  desc "GritQL rule ecosystem and AI feedback linter"
  homepage "https://github.com/CorrectRoadH/harness-lint"
  version "0.2.5"

  if OS.mac? && Hardware::CPU.arm?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.5/harness-lint-macos-aarch64"
    sha256 "6ca8b541b2df2b6cc5cb854037c64dec6d63029c7c001dc8e927925ce4b8d04e"
  elsif OS.linux? && Hardware::CPU.intel?
    url "https://github.com/CorrectRoadH/harness-lint/releases/download/v0.2.5/harness-lint-linux-x86_64"
    sha256 "b2887431cb3e1ba60b7d5f7f30b17eeac1dc87bfa0a3318a3b56dfb148db54a2"
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
