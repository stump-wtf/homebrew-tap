class Switchboard < Formula
  desc "Webhook intake board that verifies callers and routes work to agents"
  homepage "https://github.com/stump-wtf/switchboard"
  url "https://github.com/stump-wtf/switchboard/archive/refs/tags/v0.7.0.tar.gz"
  sha256 "1edccd5f34cc80dffce4d1629c91806fecb3f78f07525524db968eee5048fd38"
  license "MIT"
  head "https://github.com/stump-wtf/switchboard.git", branch: "main"

  depends_on "go" => :build

  def install
    # The module path is load-bearing: `go build -X` on a symbol that does not
    # exist injects nothing and still exits 0. The path below is the module
    # declaration in go.mod, and the "v" prefix matches goreleaser's {{.Tag}}
    # stamp, which the release workflow asserts the binary reports.
    #
    # @joestump-agent 09/29/2026 - First formula, at v0.6.0; built from the tag
    # tarball and verified `switchboard version` reports "switchboard v0.6.0".
    #
    # @joestump-agent 09/30/2026 - Bumped to v0.7.0; built from the tag tarball
    # and verified `switchboard version` reports "switchboard v0.7.0".
    ldflags = "-s -w -X github.com/stump-wtf/switchboard/internal/buildinfo.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/switchboard"
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/switchboard version")
  end
end
