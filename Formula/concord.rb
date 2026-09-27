class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.7.8/concord-sdlc-0.7.8.tgz"
  version "0.7.8"
  sha256 "5d5c51014a0de9719bb451b6d8c51cabdf9501cf16abfccd3cc2bed2ecdfdc9b"

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
