class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.8.5/concord-sdlc-0.8.5.tgz"
  version "0.8.5"
  sha256 "133ebbcd6568e6a09c1ff360f752e5ef1a4a018b10574f464381b13121193154"

  depends_on "git"
  depends_on "node"
  depends_on "ripgrep"

  on_macos do
    depends_on macos: :sequoia
  end

  preserve_rpath

  def install
    system "npm", "install", *std_npm_args, "--ignore-scripts"
    # Keep verified addons opaque to Homebrew's Mach-O relocation/signing.
    (libexec/"lib/node_modules/concord-sdlc/dist/native").glob("*/hawdb.node").each do |binary|
      system "gzip", "-n", binary
    end
    (bin/"concord").write_env_script libexec/"bin/concord", PATH: "#{Formula["node"].opt_bin}:$PATH"
  end

  def post_install
    (libexec/"lib/node_modules/concord-sdlc/dist/native").glob("*/hawdb.node.gz").each do |binary|
      system "gunzip", binary
    end
  end

  test do
    assert_equal "concord v#{version}", shell_output("#{bin}/concord --version").strip
    consumer = testpath/"consumer"
    consumer.mkpath
    Dir.chdir consumer do
      system "git", "init", "--quiet"
      system bin/"concord", "init", "--docs-only"
      system bin/"concord", "check"
      system bin/"concord", "test", "list", "--json"
      result = JSON.parse(shell_output("#{bin}/concord test list --json"))
      assert_equal "hit", result.fetch("cache").fetch("status")
    end
  end
end
