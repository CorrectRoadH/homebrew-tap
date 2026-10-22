class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  url "https://github.com/CorrectRoadH/Concord/releases/download/v0.13.0/concord-sdlc-0.13.0.tgz"
  version "0.13.0"
  sha256 "ed72b5964e71a03e12d349cdedd3ad86efad5c790ed55576d068cf52f48a5959"

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
