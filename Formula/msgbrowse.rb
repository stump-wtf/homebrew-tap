class Msgbrowse < Formula
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://github.com/stump-wtf/msgbrowse"
  url "https://github.com/stump-wtf/msgbrowse/archive/refs/tags/v0.4.4.tar.gz"
  sha256 "efe0dc9289d87e366db34da5069cb4a2ad12fb604722d8e8b3d9173313061243"
  license "MIT"
  head "https://github.com/stump-wtf/msgbrowse.git", branch: "main"

  depends_on "go" => :build

  def install
    # Version/Commit/BuildDate are injected into internal/cli by the upstream
    # Makefile. Reproduced here, minus Commit/BuildDate: a release tarball has
    # no git metadata, and baking a timestamp in would make the build
    # non-reproducible.
    ldflags = "-s -w -X github.com/joestump/msgbrowse/internal/cli.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/msgbrowse"
  end

  test do
    # `version` prints the ldflags-injected version, so this asserts both that
    # the binary runs and that the stamping above actually took effect.
    assert_match "v#{version}", shell_output("#{bin}/msgbrowse version")
  end
end
