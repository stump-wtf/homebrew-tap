class Switchboard < Formula
  # @joestump-agent 10/25/2026 - Bumped to v0.11.0 by release-sweep.
  # @joestump-agent 11/08/2026 - Bumped to v0.12.0 by release-sweep.
  desc "Webhook intake board that verifies callers and routes work to agents"
  homepage "https://github.com/stump-wtf/switchboard"
  # @joestump-agent 10/22/2026 - Bumped to v0.10.0 by release-sweep.
  # @joestump-agent 10/19/2026 - Bumped to v0.9.0 by release-sweep.
  url "https://github.com/stump-wtf/switchboard/archive/refs/tags/v0.12.0.tar.gz"
  sha256 "270ff76729562b1146ab1f2c301092f7d7efea0d8a28919a01cfe4fc6b42622c"
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
    # @joestump-agent 10/16/2026 - Bumped to v0.8.0 by release-sweep.
    # and verified `switchboard version` reports "switchboard v0.7.0".
    ldflags = "-s -w -X github.com/stump-wtf/switchboard/internal/buildinfo.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/switchboard"
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/switchboard version")
  end
end
