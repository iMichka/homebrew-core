class Sbcl < Formula
  desc "Steel Bank Common Lisp system"
  homepage "http://www.sbcl.org/"
  url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.3.10/sbcl-1.3.10-source.tar.bz2"
  sha256 "4a567aad91b316c22eb756dd8e502cfd9a95a4c660fb1fa2eb1e50e009b85777"

  head "git://sbcl.git.sourceforge.net/gitroot/sbcl/sbcl.git"

  bottle do
    sha256 "f9274daa67bb1c19304bce8df14224d3f929bdcf6a7d75f003fc2c8e57f8de6b" => :sierra
    sha256 "5a7df978f6113a563bfb919e4334cc18fd919b209bb14de62358313d205c1528" => :el_capitan
    sha256 "3859a8ac5b062a1b39a35e725f13b91225ab0a2f99896aad1cbdd9a1a0b13ff2" => :yosemite
    sha256 "0e86ce869f49e82d6820b45323cd65c7f2327560a128c064d0881680db44f75f" => :x86_64_linux
  end

  fails_with :llvm do
    build 2334
    cause "Compilation fails with LLVM."
  end

  option "32-bit"
  option "with-internal-xref", "Include XREF information for SBCL internals (increases core size by 5-6MB)"
  option "with-ldb", "Include low-level debugger in the build"
  option "without-sources", "Don't install SBCL sources"
  option "without-core-compression", "Build SBCL without support for compressed cores and without a dependency on zlib"
  option "without-threads", "Build SBCL without support for native threads"

  depends_on "zlib" unless OS.mac?

  # Current binary versions are listed at http://sbcl.sourceforge.net/platform-table.html
  resource "bootstrap64" do
    if OS.mac?
      url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.2.11/sbcl-1.2.11-x86-64-darwin-binary.tar.bz2"
      sha256 "057d3a1c033fb53deee994c0135110636a04f92d2f88919679864214f77d0452"
    elsif OS.linux?
      url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.3.3/sbcl-1.3.3-x86-64-linux-binary.tar.bz2"
      sha256 "e8b1730c42e4a702f9b4437d9842e91cb680b7246f88118c7443d7753e61da65"
    end
  end

  resource "bootstrap32" do
    if OS.mac?
      url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.1.6/sbcl-1.1.6-x86-darwin-binary.tar.bz2"
      sha256 "5801c60e2a875d263fccde446308b613c0253a84a61ab63569be62eb086718b3"
    elsif OS.linux?
      url "https://downloads.sourceforge.net/project/sbcl/sbcl/1.2.7/sbcl-1.2.7-x86-linux-binary.tar.bz2"
      sha256 "724425fe0d28747c7d31c6655e39fa8c27f9ef4608c482ecc60089bcc85fc31d"
    end
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-base-target-features.diff"
    sha256 "e101d7dc015ea71c15a58a5c54777283c89070bf7801a13cd3b3a1969a6d8b75"
  end if OS.mac?

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-make-doc.diff"
    sha256 "7c21c89fd6ec022d4f17670c3253bd33a4ac2784744e4c899c32fbe27203d87e"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-posix-tests.diff"
    sha256 "06908aaa94ba82447d64cf15eb8e011ac4c2ae4c3050b19b36316f64992ee21d"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/c5ffdb11/sbcl/patch-use-mach-exception-handler.diff"
    sha256 "089b8fdc576a9a32da0b2cdf2b7b2d8bfebf3d542ac567f1cb06f19c03eaf57d"
  end

  def write_features
    features = []
    features << ":sb-thread" if build.with? "threads"
    features << ":sb-core-compression" if build.with? "core-compression"
    features << ":sb-ldb" if build.with? "ldb"
    features << ":sb-xref-for-internals" if build.with? "internal-xref"

    File.open("customize-target-features.lisp", "w") do |file|
      file.puts "(lambda (list)"
      features.each do |f|
        file.puts "  (pushnew #{f} list)"
      end
      file.puts "  list)"
    end
  end

  def install
    write_features

    # Remove non-ASCII values from environment as they cause build failures
    # More information: https://bugs.gentoo.org/show_bug.cgi?id=174702
    ENV.delete_if do |_, value|
      ascii_val = value.dup
      ascii_val.force_encoding("ASCII-8BIT") if ascii_val.respond_to? :force_encoding
      ascii_val =~ /[\x80-\xff]/n
    end

    bootstrap = (build.build_32_bit? || !MacOS.prefer_64_bit?) ? "bootstrap32" : "bootstrap64"
    resource(bootstrap).stage do
      # We only need the binaries for bootstrapping, so don't install anything:
      command = "#{Dir.pwd}/src/runtime/sbcl"
      core = "#{Dir.pwd}/output/sbcl.core"
      xc_cmdline = "#{command} --core #{core} --disable-debugger --no-userinit --no-sysinit"

      cd buildpath do
        ENV["SBCL_ARCH"] = "x86" if build.build_32_bit?
        Pathname.new("version.lisp-expr").write('"1.0.99.999"') if build.head?
        system "./make.sh", "--prefix=#{prefix}", "--xc-host=#{xc_cmdline}"
      end
    end

    ENV["INSTALL_ROOT"] = prefix
    system "sh", "install.sh"

    if build.with? "sources"
      bin.env_script_all_files(libexec/"bin", :SBCL_SOURCE_ROOT => pkgshare/"src")
      pkgshare.install %w[contrib src]

      (lib/"sbcl/sbclrc").write <<-EOS.undent
        (setf (logical-pathname-translations "SYS")
          '(("SYS:SRC;**;*.*.*" #p"#{pkgshare}/src/**/*.*")))
        EOS
    end
  end

  test do
    (testpath/"simple.sbcl").write <<-EOS.undent
      (write-line (write-to-string (+ 2 2)))
    EOS
    output = shell_output("#{bin}/sbcl --script #{testpath}/simple.sbcl")
    assert_equal "4", output.strip
  end
end
