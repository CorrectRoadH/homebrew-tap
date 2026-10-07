class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.11.7/concord-sdlc-0.11.7.tgz"
  version "0.11.7"
  sha256 "3b452824ef2ea4acb1bd7c8c6058e8eab8994042690338d9e23b5fa0ccec312c"

  depends_on "git"
  depends_on "node"
  depends_on "pnpm" => :build
  depends_on "ripgrep"

  on_macos do
    depends_on macos: :sequoia
  end

  preserve_rpath

  def install
    libexec.install Dir["*", ".*"] - [".", ".."]
    cd libexec do
      system Formula["pnpm"].opt_bin/"pnpm", "install", "--prod", "--frozen-lockfile", "--ignore-scripts", "--package-import-method=copy"
    end
    # Keep verified addons opaque to Homebrew's Mach-O relocation/signing.
    (libexec/"dist/native").glob("*/hawdb.node").each do |binary|
      system "gzip", "-n", binary
    end
    (bin/"concord").write <<~SH
      #!/bin/sh
      export PATH="#{Formula["node"].opt_bin}:$PATH"
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/dist/entry.js" "$@"
    SH
  end

  def post_install
    (libexec/"dist/native").glob("*/hawdb.node.gz").each do |binary|
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
      system bin/"concord", "cache", "clear"
      cold = JSON.parse(shell_output("#{bin}/concord test list --json"))
      assert_equal "miss", cold.fetch("cache").fetch("status")
      result = JSON.parse(shell_output("#{bin}/concord test list --json"))
      assert_equal "hit", result.fetch("cache").fetch("status")
    end
  end
end
