class Concord < Formula
  desc "Local SDLC CLI for contracts, test evidence, and engineering memory"
  homepage "https://github.com/CorrectRoadH/Concord"
  version "0.17.1"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :sequoia
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.17.1/concord-0.17.1-darwin-arm64.tar.gz"
    sha256 "cfaae0c28cfea0bd4eac649e62ea28d1eb6fedd45babfabade53643edf8a21f5"
  end

  on_linux do
    depends_on arch: :x86_64
    url "https://github.com/CorrectRoadH/Concord/releases/download/v0.17.1/concord-0.17.1-linux-x64.tar.gz"
    sha256 "16abb2e462d04244cb0564cb2039982b494935aaaa3f7c8e681e9b7e0c50989b"
  end

  depends_on "git"
  preserve_rpath
  # The executable is compressed until post-install, so this link is temporarily
  # unresolved. Keep Homebrew's cleaner from deleting the installed entry point.
  skip_clean "bin/concord"

  def compressed_native_paths
    JSON.parse(OS.mac? ? '["app/dist/native/darwin-arm64/lib/libhawdb_ffi.dylib","app/node_modules/@esbuild/darwin-arm64/bin/esbuild","app/node_modules/@typescript/typescript-darwin-arm64/lib/tsc","bin/concord","runtime/rg"]' : '["app/dist/native/linux-x64-glibc/lib/libhawdb_ffi.so","app/node_modules/@esbuild/linux-x64/bin/esbuild","app/node_modules/@typescript/typescript-linux-x64/lib/tsc","bin/concord","runtime/lib/libatomic.so.1","runtime/lib/libgcc_s.so.1","runtime/lib/libstdc++.so.6","runtime/rg"]')
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
    compressed_native_paths.each do |relative|
      binary = libexec/"#{relative}.gz"
      system "gunzip", binary if binary.exist?
    end
  end
end
