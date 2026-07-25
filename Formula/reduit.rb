class Reduit < Formula
  desc "Cache Proton Mail locally with semantic search and a stdio MCP server"
  homepage "https://github.com/stump-wtf/reduit"
  url "https://github.com/stump-wtf/reduit/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "63da072f569a627141ae4b9bd2838bd8978cb7ce1df5851518f279d368e45cee"
  license "MIT"
  head "https://github.com/stump-wtf/reduit.git", branch: "main"

  depends_on "go" => :build

  def install
    ldflags = "-s -w -X github.com/joestump/reduit/internal/cli.Version=v#{version}"
    system "go", "build", *std_go_args(ldflags: ldflags), "./cmd/reduit"
  end

  test do
    # reduit has no `version` subcommand — it exposes `--version`, which prints
    # "reduit version <Version>" from the ldflags stamp above.
    assert_match "v#{version}", shell_output("#{bin}/reduit --version")
  end
end
