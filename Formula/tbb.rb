class Tbb < Formula
  desc "Rich and complete approach to parallelism in C++"
  homepage "https://www.threadingbuildingblocks.org/"
  url "https://github.com/intel/tbb/archive/v2020.1.tar.gz"
  version "2020_U1"
  sha256 "48d51c63b16787af54e1ee4aaf30042087f20564b4eecf9a032d5568bc2f0bf8"
  revision 1

  bottle do
    cellar :any
    sha256 "1f949738237859a87bf40da697d2adec6603c4dd4338c2fadc9f2b8b2f2dfe52" => :catalina
    sha256 "d299eab47b9b7e471b09f688d080d362b40ec71160cffe143b23130e07f3d221" => :mojave
    sha256 "e14f3b69b1850b912c4942100d24f70d5bf02ff8977af893e97fcca904aaac61" => :high_sierra
  end

  depends_on "cmake" => :build
  depends_on "swig" => :build
  depends_on "python@3.8"

  def install
    compiler = (ENV.compiler == :clang) ? "clang" : "gcc"
    system "make", "tbb_build_prefix=BUILDPREFIX", "compiler=#{compiler}"
    lib.install Dir["build/BUILDPREFIX_release/*.dylib"]

    # Build and install static libraries
    system "make", "tbb_build_prefix=BUILDPREFIX", "compiler=#{compiler}",
                   "extra_inc=big_iron.inc"
    lib.install Dir["build/BUILDPREFIX_release/*.a"]
    include.install "include/tbb"

    cd "python" do
      ENV["TBBROOT"] = prefix
      system "python3", *Language::Python.setup_install_args(prefix)
    end

    system "cmake", *std_cmake_args,
                    "-DINSTALL_DIR=lib/cmake/TBB",
                    "-DSYSTEM_NAME=Darwin",
                    "-DTBB_VERSION_FILE=#{include}/tbb/tbb_stddef.h",
                    "-P", "cmake/tbb_config_installer.cmake"

    (lib/"cmake"/"TBB").install Dir["lib/cmake/TBB/*.cmake"]
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <tbb/task_scheduler_init.h>
      #include <iostream>

      int main()
      {
        std::cout << tbb::task_scheduler_init::default_num_threads();
        return 0;
      }
    EOS
    system ENV.cxx, "test.cpp", "-L#{lib}", "-ltbb", "-o", "test"
    system "./test"
  end
end
