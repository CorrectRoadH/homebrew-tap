class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  version "0.15.0"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :sequoia
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.15.0/concord-0.15.0-darwin-arm64.tar.gz"
    sha256 "c9fb8b5cbf9f93a8489a765166fb71a5ed1be28a06bd24a97d8e66a9f4d6fb4f"
  end

  on_linux do
    depends_on arch: :x86_64
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.15.0/concord-0.15.0-linux-x64.tar.gz"
    sha256 "8eadd1abba5e2ebcf7ac7635e62ac0aed80d932c436f799ae271cf9a70c9d566"
  end

  depends_on "git"
  preserve_rpath
  # The executable is compressed until post-install, so this link is temporarily
  # unresolved. Keep Homebrew's cleaner from deleting the installed entry point.
  skip_clean "bin/concord"

  def native_checksums
    JSON.parse(OS.mac? ? '{"app/dist/native/darwin-arm64/hawdb.node":"a72a77135cab107ab6e354c51cb487475350a8c2881c4e3a9756c8ef7c568482","app/dist/native/darwin-arm64/rg":"c6baa09a2502a65282cf332c17522c62a99a9f0804ddfe1a000e7896d89fb390","app/node_modules/@esbuild/darwin-arm64/bin/esbuild":"10b6243df618d374bb2d5c9cfbe7052e1405f6aa4e53a6164f11a91b9f2e1384","app/node_modules/@typescript/typescript-darwin-arm64/lib/tsc":"29f5eb8daa5c8cf6ef1c0cb79fbcf47c0cfdf26edabdf148bb779d0b2d56cebc","bin/concord":"3f451f2872baf04dbcc5168d7cc027539d815dc2c0e038eb58b5e1d852ad72f7","runtime/rg":"c6baa09a2502a65282cf332c17522c62a99a9f0804ddfe1a000e7896d89fb390"}' : '{"app/dist/native/linux-x64-glibc/hawdb.node":"683d7165130afe0da1a87b840c9e57e3bae6a873331d87dea09872c505baf04b","app/node_modules/@esbuild/linux-x64/bin/esbuild":"e1698a3d5c6c0798fee4fd3b5cc816651f460c63d390a7a26ea4beb0b1884100","app/node_modules/@typescript/typescript-linux-x64/lib/tsc":"a183b1956edbe7e7d98f2249858eedf2d8a9790809cc4909db1276e202faaa70","bin/concord":"64a491193974e403281df7c03433026e3cf09a6a249dbb99e7c6895163c60876","runtime/lib/libatomic.so.1":"9d8a34468e614a71a6427dbabb0ac24eb8cb1e324dc6aa3bf95eb6f59201f000","runtime/lib/libgcc_s.so.1":"d93224d2b0dab4247598be683adca02f5cf00586f99c187579cd7e92058fb7cb","runtime/lib/libstdc++.so.6":"61bb2c0a20ddc52916eb2ee610901a64c57a7aba19cef18dc956028feffbd6ff","runtime/rg":"e62198eb19b136b88c330af83647b5a962cb99b6b1f066758568f12de1974849"}')
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
