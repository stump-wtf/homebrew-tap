cask "msgbrowse-desktop" do
  version "0.8.3"
  sha256 "11aacedbf5bea8323dcb87f06de5a4281b20281c92c51ad8bcea086deb45607e"

  # Release Assets Are Served From The GitHub Mirror
  #
  # The darwin .app is built by GitHub Actions (Gitea has no macOS runner), and
  # gitea.stump.rocks is an RFC1918 address reachable only from the LAN — so the
  # Gitea copy of this zip was both second-hand and unfetchable off-network. The
  # step that used to mirror it back to Gitea timed out on every tag from v0.6.0
  # on, which is why this cask sat at 0.5.0 for three releases. Point straight at
  # the release the build actually produces.
  #
  # `v#{version}` is interpolated deliberately: the CI tap-bump rewrites the
  # `version` line alone and the URL follows.
  #
  # @joestump 08/28/2026 - Repointed url/homepage/livecheck at the GitHub mirror
  # and bumped 0.5.0 -> 0.8.0.
  #
  # @joestump 08/30/2026 - Bumped 0.8.0 -> 0.8.1. The 08/28 formula bump only
  # touched Formula/msgbrowse.rb, so the desktop app stayed on 0.8.0; formula
  # and cask now go up together.
  url "https://github.com/stump-wtf/msgbrowse/releases/download/v#{version}/msgbrowse-desktop_darwin_universal.zip"
  name "msgbrowse"
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://stump-wtf.github.io/msgbrowse/"

  # Tags are mirrored from the canonical Gitea repo within seconds of a release,
  # and the mirror is the host this cask downloads from, so track tags here.
  livecheck do
    url "https://github.com/stump-wtf/msgbrowse.git"
    strategy :git
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :big_sur

  app "msgbrowse.app"

  # The .app and every binary it embeds — the python-build-standalone runtime,
  # sigexport, wtsexporter, imessage-exporter, syncthing — are AD-HOC signed
  # (`codesign -s -` in desktop.yml), not notarized with a Developer ID. Homebrew
  # quarantines cask downloads by default, and Gatekeeper then blocks not just
  # the app but the embedded binaries it spawns as subprocesses, which is what
  # breaks export/import. Strip the attribute so `brew install --cask` yields a
  # working app instead of one that dies on first launch.
  #
  # Delete this block once the owner-gated signing secrets in desktop.yml go
  # live and releases ship notarized — at that point quarantine is harmless and
  # leaving it stripped needlessly gives up a Gatekeeper check.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/msgbrowse.app"]
  end

  uninstall quit: "com.wails.msgbrowse"

  # Archives, the SQLite index, and config.yaml live under
  # os.UserConfigDir()/msgbrowse — on macOS, ~/Library/Application Support.
  zap trash: [
    "~/Library/Application Support/msgbrowse",
    "~/Library/Saved Application State/com.wails.msgbrowse.savedState",
  ]
end
