class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.8.0/concord-sdlc-0.8.0.tgz"
  version "0.8.0"
  sha256 "0d8ca9a086930580142e289d96e2e5b832de087ca87e8fab231d6d4678b36c99"

  depends_on "git"
  depends_on "node"
  depends_on "ripgrep"

  def install
    system "npm", "install", *std_npm_args, "--ignore-scripts"
    (bin/"concord").write_env_script libexec/"bin/concord", PATH: "#{Formula["node"].opt_bin}:$PATH"
  end

  test do
    assert_equal "concord v#{version}", shell_output("#{bin}/concord --version").strip
    consumer = testpath/"consumer"
    consumer.mkpath
    Dir.chdir consumer do
      system "git", "init", "--quiet"
      system bin/"concord", "init", "--docs-only"
      system bin/"concord", "check"
    end
  end
end
