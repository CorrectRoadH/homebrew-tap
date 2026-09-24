class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.7.4/concord-sdlc-0.7.4.tgz"
  version "0.7.4"
  sha256 "19975fa53fca6307af3258e488b49fec3c47c7f6f88ba2688ee99ea85cc7ee62"

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
