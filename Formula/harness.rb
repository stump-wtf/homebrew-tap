class Harness < Formula
  desc "Supervise long-running agent processes from a client-server TUI"
  homepage "https://github.com/stump-wtf/harness"
  url "https://github.com/stump-wtf/harness/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "49ed18de8a9c3d4d981a6837eca6e820e5468c0513f8ff4206f40f2c11da85b9"
  license "MIT"
  head "https://github.com/stump-wtf/harness.git", branch: "main"

  depends_on "go" => :build

  def install
    # Note the version lives in internal/buildinfo here, not internal/cli as in
    # the other stump.wtf formulae, and the module path is the Gitea one.
    #
    # Both halves are load-bearing, and getting either wrong fails SILENTLY:
    # `go build -X` on a symbol that does not exist injects nothing and still
    # exits 0. Built from the v0.3.0 tarball, the line below reports
    # "harness v0.3.0"; the same build with internal/cli in place of
    # internal/buildinfo reports "harness dev" and exits 0.
    #
    # @joestump-agent 09/12/2026 - Bumped to v0.3.0 and verified both builds.
    ldflags = "-s -w -X gitea.stump.rocks/stump.wtf/harness/internal/buildinfo.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/harness"
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/harness --version")
  end
end
