class Harness < Formula
  desc "Supervise long-running agent processes from a client-server TUI"
  homepage "https://github.com/stump-wtf/harness"
  url "https://github.com/stump-wtf/harness/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "3f669172ac55252972feb953b924ce77cfb836505b795a61155510770116adb8"
  license "MIT"
  head "https://github.com/stump-wtf/harness.git", branch: "main"

  depends_on "go" => :build

  def install
    # Note the version lives in internal/buildinfo here, not internal/cli as in
    # the other stump.wtf formulae.
    #
    # The module path is load-bearing, and getting it wrong fails SILENTLY:
    # `go build -X` on a symbol that does not exist injects nothing and still
    # exits 0. This line read the old `gitea.stump.rocks/stump.wtf/harness`
    # path until v0.4.0, which stopped matching when the module moved to
    # `github.com/stump-wtf/harness` -- so a build of `main` reported
    # "harness dev" and exited 0, and `--HEAD` users got a dev build with no
    # symptom but the version string. The path below is the module declaration
    # in go.mod, which is the authority, not this recipe's history.
    #
    # @joestump-agent 09/12/2026 - Bumped to v0.3.0 and verified both builds.
    # @joestump-agent 09/23/2026 - Repointed the ldflag at the public module
    # path (the module moved in v0.4.0) and bumped to v0.4.0.
    ldflags = "-s -w -X github.com/stump-wtf/harness/internal/buildinfo.Version=v#{version}"
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
  # PATH is the one thing Homebrew does not solve for you: std_service_path_env
  # is Homebrew plus the system directories, and the daemon resolves an agent
  # executable on its OWN PATH when a harness spawns -- a harness `env_file`
  # cannot change that, because the lookup happens before the child environment
  # applies. So the common per-user install locations are appended here, which
  # is the only place the fix can live. Directories that do not exist are
  # harmless on PATH.
  #
  # `#{Dir.home}` rather than `~`: launchd does not expand a tilde, is why the
  # guide tells people to substitute their real home directory by hand.
  #
  # @joestump 09/16/2026 - Added the service block for stump-wtf/harness#6.
  # @joestump-agent 09/23/2026 - Appended the user install locations to PATH and
  # corrected the caveat, which told users to fix PATH in a harness env_file --
  # advice that cannot work (homebrew-tap#18).
  service do
    run [opt_bin/"harness", "daemon", "start"]
    keep_alive successful_exit: false
    run_at_load true
    # This block is instance_eval'd against a Homebrew::Service, and `brew
    # audit` builds that object WITHOUT running `install`. So the PATH cannot
    # come from a formula method (an earlier attempt called `service_path` and
    # raised "undefined local variable or method" under audit), nor from an
    # ivar set in install. It has to be computable right here.
    #
    # Built as an array join rather than one long interpolated string: that
    # keeps every line short without a backslash continuation, which
    # Layout/LineEndStringConcatenationIndentation then judges on alignment.
    user_dirs = [".local/bin", "go/bin", ".bun/bin", ".npm-global/bin",
                 ".local/share/mise/shims", ".asdf/shims"].map { |dir| "#{Dir.home}/#{dir}" }
    environment_variables PATH: ([std_service_path_env] + user_dirs).join(":")
    log_path "#{Dir.home}/Library/Logs/harness-daemon.log"
    error_log_path "#{Dir.home}/Library/Logs/harness-daemon.log"
  end

  def caveats
    <<~EOS
      Run the daemon in the background:
        brew services start harness

      A service does not read your shell profile, and the daemon resolves an
      agent CLI on its PATH when a harness spawns -- the executable is chosen
      before the harness's own environment applies, so putting PATH in a
      harness `env_file` will NOT work. This service's PATH is Homebrew plus
      the usual per-user install locations (~/.local/bin, ~/go/bin, ~/.bun/bin,
      ~/.npm-global/bin, and mise/asdf shims), which covers most agents.

      If your agent CLI lives somewhere else, add that directory to the
      service, or install the agent through Homebrew:
        brew edit harness
      An absolute path cannot be configured per harness instead: the `harness`
      enum picks the executable, and there is no `cmd` key.

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
