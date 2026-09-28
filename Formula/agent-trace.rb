class AgentTrace < Formula
  desc "Normalize agent session transcripts and stream-json runs"
  homepage "https://github.com/stump-wtf/agent-trace"
  url "https://github.com/stump-wtf/agent-trace/archive/refs/tags/v0.7.1.tar.gz"
  sha256 "cc39ea76522ecfc859cfd8a97536bbcb0359ba3dc46a58d2a5daefbd9a642c54"
  license "MIT"
  head "https://github.com/stump-wtf/agent-trace.git", branch: "main"

  depends_on "go" => :build

  def install
    # No version flag to inject: the CLI has no buildinfo var yet, so the
    # install is a plain build. If one is added, mirror harness.rb's -X
    # ldflags and verify the symbol actually exists — a wrong -X target
    # fails silently.
    #
    # @joestump-agent 09/27/2026 - Added at v0.7.0.
    # @joestump-agent 09/27/2026 - Bumped to v0.7.1: the v0.7.0 tag was
    # re-pointed after its release failed, poisoning sum.golang.org for
    # go install; the tap tracks the good tag.
    system "go", "build", *std_go_args, "./cmd/agent-trace"
  end

  test do
    # The CLI has no version flag; prove the binary runs by handing it a
    # transcript and reading the session record it writes back.
    (testpath/"session.jsonl").write <<~EOS
      {"type":"user","timestamp":"2026-01-01T10:00:00Z","sessionId":"s","cwd":"/w","message":{"role":"user","content":"go"}}
    EOS
    assert_match "\"kind\":\"session\"",
                 shell_output("#{bin}/agent-trace normalize --harness claude-code #{testpath}/session.jsonl")
  end
end
