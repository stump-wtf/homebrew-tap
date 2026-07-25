class Harness < Formula
  desc "Supervise long-running agent processes from a client-server TUI"
  homepage "https://github.com/stump-wtf/harness"
  url "https://github.com/stump-wtf/harness/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "7cde16232cc1f87cfb571b4bd021f32481e911f3fb2771e1ad1b685842ef0ff9"
  license "MIT"
  head "https://github.com/stump-wtf/harness.git", branch: "main"

  depends_on "go" => :build

  def install
    # Note the version lives in internal/buildinfo here, not internal/cli as in
    # the other stump.wtf formulae, and the module path is the Gitea one.
    ldflags = "-s -w -X gitea.stump.rocks/stump.wtf/harness/internal/buildinfo.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/harness"
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/harness --version")
  end
end
