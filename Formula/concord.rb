class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/homebrew-tap/releases/download/concord-v0.2.0/concord-sdlc-0.2.0.tgz"
  version "0.2.0"
  sha256 "5aa888d30ef6417f3709436b0db9783888be1e47269f3e59be550641277cfcdd"

  depends_on :linux
  depends_on "node"

  def install
    system "npm", "install", *std_npm_args, "--ignore-scripts"
    bin.install_symlink libexec.glob("bin/*")
  end

  test do
    consumer = testpath/"consumer"
    consumer.mkpath
    Dir.chdir consumer do
      system "git", "init", "--quiet"
      system bin/"concord", "init"
      system bin/"concord", "check"
    end
  end
end
