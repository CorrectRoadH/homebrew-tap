class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.7.10/concord-sdlc-0.7.10.tgz"
  version "0.7.10"
  sha256 "b70f2cd494b9a68023127889b80d664c306f6385e28b82e30d6a54f810ae5064"

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
