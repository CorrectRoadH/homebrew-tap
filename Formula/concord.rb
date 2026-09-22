class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/concord-v0.6.0/concord-sdlc-0.6.0.tgz"
  version "0.6.0"
  sha256 "95c5824f10f0d15bec87e791334e78c1160eaccc2ad180d19563b6517a73a31f"

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
