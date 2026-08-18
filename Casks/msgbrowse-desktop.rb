cask "msgbrowse-desktop" do
  version "0.5.0"
  sha256 "852648718cd05c2f40bdb3fdc31f8a0ac08422b7bc0714a58dafb52b020def9b"

  # Served from the canonical Gitea release asset, not the GitHub mirror —
  # the mirror lags behind Gitea (and its push credential has broken entirely
  # in the past), so the zip is attached to the Gitea release and downloaded
  # from here. The URL is stable per tag.
  url "https://gitea.stump.rocks/stump.wtf/msgbrowse/releases/download/v#{version}/msgbrowse-desktop_darwin_universal.zip"
  name "msgbrowse"
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://gitea.stump.rocks/stump.wtf/msgbrowse"

  # livecheck follows the canonical Gitea tags. The old GitHub-mirror livecheck
  # (and the note about prereleases below) no longer applies: the canonical
  # release is on Gitea.
  livecheck do
    url "https://gitea.stump.rocks/stump.wtf/msgbrowse.git"
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
