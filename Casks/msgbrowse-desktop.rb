cask "msgbrowse-desktop" do
  version "0.4.2"
  sha256 "6217f28bd0dce3f2686efeb6324b77d693e41777e65dca2d84d22bdd46ac0e92"

  url "https://github.com/stump-wtf/msgbrowse/releases/download/v#{version}/msgbrowse-desktop_darwin_universal.zip"
  name "msgbrowse"
  desc "Browse, search, and export iMessage, Signal, and WhatsApp conversations"
  homepage "https://github.com/stump-wtf/msgbrowse"

  # Every release is published as a prerelease until a Developer ID is
  # provisioned (see desktop.yml), and GitHub's /releases/latest skips
  # prereleases — so :github_latest would report "no version found". Match the
  # tags directly instead.
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
