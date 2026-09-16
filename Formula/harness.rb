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

  # Daemon Service Definition
  #
  # Lets `brew services start harness` stand the daemon up instead of making
  # people hand-author ~/Library/LaunchAgents/dev.harness.daemon.plist with
  # absolute paths substituted in. Mirrors that plist from the run-as-a-service
  # guide: `daemon start` runs in the FOREGROUND (--detach is the opt-in
  # background mode, and a self-backgrounding process makes launchd respawn
  # forever), relaunch on a crash but not after a clean `harness daemon stop`,
  # and the daemon's own log kept separate from each harness's logs.
  #
  # PATH is the one thing this cannot fully solve — see `caveats`.
  #
  # @joestump 09/16/2026 - Added the service block for stump-wtf/harness#6.
  service do
    run [opt_bin/"harness", "daemon", "start"]
    keep_alive successful_exit: false
    run_at_load true
    environment_variables PATH: std_service_path_env
    log_path "#{Dir.home}/Library/Logs/harness-daemon.log"
    error_log_path "#{Dir.home}/Library/Logs/harness-daemon.log"
  end

  def caveats
    <<~EOS
      Run the daemon in the background:
        brew services start harness

      A service does not read your shell profile, and agent CLIs are looked up
      on PATH when a harness spawns. This service's PATH is Homebrew plus the
      system directories, so an agent installed elsewhere -- ~/.local/bin, an
      npm/bun global prefix, mise or asdf shims -- will NOT be found, and the
      harness fails at spawn rather than at `brew services start`.

      If that applies to you, set PATH for that harness in its `env_file`.
      (There is no `cmd` key to point at an absolute path -- the `harness`
      enum picks the executable.)

      On macOS, `brew services` runs this in your GUI login session, so agents
      inherit your login Keychain: a claude-code harness needs no env_file.
    EOS
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/harness --version")

    # The service must run the daemon in the foreground. If a future change
    # makes `daemon start` self-background, launchd respawns it forever and
    # `brew services` reports it as constantly crashing -- so pin the shape of
    # the service definition, not just that one exists.
    assert_equal ["#{opt_bin}/harness", "daemon", "start"], service.command
    refute_includes service.command, "--detach"
  end
end
