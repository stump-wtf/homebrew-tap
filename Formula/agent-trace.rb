class AgentTrace < Formula
  desc "Normalize agent session transcripts and stream-json runs"
  homepage "https://github.com/stump-wtf/agent-trace"
  url "https://github.com/stump-wtf/agent-trace/archive/refs/tags/v0.7.0.tar.gz"
  sha256 "98e6e2222746b21522ba56c1cc192f9cec6a95d0e7eca7be530f3a876b888ca0"
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
