class Switchboard < Formula
  desc "Webhook intake board that verifies callers and patches work through to agents and a live web UI"
  homepage "https://github.com/stump-wtf/switchboard"
  url "https://github.com/stump-wtf/switchboard/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "853038382c8b6cb923152f09e863823e47058fdf9c20080e75eb9fe591f5306f"
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
    ldflags = "-s -w -X github.com/stump-wtf/switchboard/internal/buildinfo.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/switchboard"
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/switchboard version")
  end
end
