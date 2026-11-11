class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  version "0.16.8"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :sequoia
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.16.8/concord-0.16.8-darwin-arm64.tar.gz"
    sha256 "7f908a3ae0e5d38b165016df315b369fe098da623ba206a3df4989aa3d0de81d"
  end

  on_linux do
    depends_on arch: :x86_64
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.16.8/concord-0.16.8-linux-x64.tar.gz"
    sha256 "942c164960b1665162c5ed7003f935fbde0c66f567b2ae6e09a4f6b20d0142dc"
  end

  depends_on "git"
  preserve_rpath
  # The executable is compressed until post-install, so this link is temporarily
  # unresolved. Keep Homebrew's cleaner from deleting the installed entry point.
  skip_clean "bin/concord"

  def native_checksums
    JSON.parse(OS.mac? ? '{"app/dist/native/darwin-arm64/hawdb.node":"5498216806a11d08bc5fb132baf889b94d2fa2b087a2bc9a72d49cad7a33328c","app/dist/native/darwin-arm64/rg":"c6baa09a2502a65282cf332c17522c62a99a9f0804ddfe1a000e7896d89fb390","app/node_modules/@esbuild/darwin-arm64/bin/esbuild":"10b6243df618d374bb2d5c9cfbe7052e1405f6aa4e53a6164f11a91b9f2e1384","app/node_modules/@typescript/typescript-darwin-arm64/lib/tsc":"29f5eb8daa5c8cf6ef1c0cb79fbcf47c0cfdf26edabdf148bb779d0b2d56cebc","bin/concord":"8b1ce32fa13093782b5655198319e0b579f1413a414a92b68b13f2dd404c237b","runtime/rg":"c6baa09a2502a65282cf332c17522c62a99a9f0804ddfe1a000e7896d89fb390"}' : '{"app/dist/native/linux-x64-glibc/hawdb.node":"47e858cb6ebeaba1a7c4f26732b791d62b16f7e624f7aacc57fb5f23cb3c8e3b","app/node_modules/@esbuild/linux-x64/bin/esbuild":"e1698a3d5c6c0798fee4fd3b5cc816651f460c63d390a7a26ea4beb0b1884100","app/node_modules/@typescript/typescript-linux-x64/lib/tsc":"a183b1956edbe7e7d98f2249858eedf2d8a9790809cc4909db1276e202faaa70","bin/concord":"ad826529336a17a7edb3426bd7074ff571cf35172d138cdc9faf6096eaa99b56","runtime/lib/libatomic.so.1":"9d8a34468e614a71a6427dbabb0ac24eb8cb1e324dc6aa3bf95eb6f59201f000","runtime/lib/libgcc_s.so.1":"d93224d2b0dab4247598be683adca02f5cf00586f99c187579cd7e92058fb7cb","runtime/lib/libstdc++.so.6":"61bb2c0a20ddc52916eb2ee610901a64c57a7aba19cef18dc956028feffbd6ff","runtime/rg":"e62198eb19b136b88c330af83647b5a962cb99b6b1f066758568f12de1974849"}')
  end

  def native_binaries
    magic = %w[7f454c46 feedface cefaedfe feedfacf cffaedfe cafebabe bebafeca cafebabf bfbafeca]
    libexec.glob("**/*").select do |path|
      path.file? && !path.symlink? && magic.include?(path.binread(4).unpack1("H*"))
    end
  end

  def install
    libexec.install Dir["*", ".*"] - [".", ".."]
    bin.install_symlink libexec/"bin/concord"
    # ELF relocation corrupts Bun payloads; Mach-O relocation invalidates signatures.
    # Hide every native file (including external tools) until post-install.
    native_binaries.each { |binary| system "gzip", "-n", binary }
  end

  def post_install
    native_checksums.each_key do |relative|
      binary = libexec/"#{relative}.gz"
      system "gunzip", binary if binary.exist?
    end
  end

  test do
    assert_equal "concord v#{version}", shell_output("#{bin}/concord --version").strip
    require "digest"
    expected = native_checksums
    actual = native_binaries.to_h do |binary|
      [binary.relative_path_from(libexec).to_s, Digest::SHA256.file(binary).hexdigest]
    end
    assert_equal expected, actual, "Installed native bytes differ from the verified release archive"
    if OS.mac?
      native_binaries.each { |binary| system "/usr/bin/codesign", "--verify", binary }
      refute_match "com.apple.quarantine", shell_output("/usr/bin/xattr -r #{libexec}")
    end
    # HawDB syncs database ancestors through the filesystem mount. Landlock
    # denies reading / in Linux's test sandbox; keep its writable tmpfs workaround.
    require "tmpdir"
    test_root = OS.linux? ? "/dev/shm" : testpath.to_s
    Dir.mktmpdir("concord-consumer-", test_root) do |consumer|
      Dir.chdir consumer do
        system "git", "init", "--quiet"
        system bin/"concord", "init", "--docs-only"
        system bin/"concord", "check"
        system bin/"concord", "cache", "clear"
        cold = JSON.parse(shell_output("#{bin}/concord test list --json"))
        assert_equal "miss", cold.fetch("cache").fetch("status"), cold.to_json
        warm = JSON.parse(shell_output("#{bin}/concord test list --json"))
        assert_equal "hit", warm.fetch("cache").fetch("status"), warm.to_json
      end
    end
  end
end
