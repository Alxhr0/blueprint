class Ghostty < Formula
  desc "GPU-accelerated terminal emulator"
  homepage "https://ghostty.org"
  url "https://release.files.ghostty.org/1.3.1/ghostty-x86_64-linux.zip"
  version "1.3.1"
  license "MIT"

  def install
    bin.install "ghostty"
  end
end
