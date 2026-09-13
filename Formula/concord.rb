class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/homebrew-tap/releases/download/concord-v0.2.1/concord-sdlc-0.2.1.tgz"
  version "0.2.1"
  sha256 "94d5ec0767773759b9fddfc2b7d3ecc46f5d3f6df86036af5f401b7dc3c71c06"

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
