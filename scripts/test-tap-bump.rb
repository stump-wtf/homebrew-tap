#!/usr/bin/env ruby
# frozen_string_literal: true

# Fixture tests for scripts/tap-bump.rb: no network, no git. Each case lays
# down a tiny tap in a tmpdir plus fixture release JSON and artifact files,
# runs the CLI, and asserts on the rewritten files, stdout and exit code.

require "digest"
require "json"
require "tmpdir"
require "fileutils"
require "open3"

SCRIPT = File.expand_path("tap-bump.rb", __dir__)
PASS = []
FAIL = []

def run(*args)
  out, err, status = Open3.capture3("ruby", SCRIPT, *args)
  [out, err, status.exitstatus]
end

def check(name)
  ok = yield
  (ok ? PASS : FAIL) << name
  puts "#{ok ? "ok" : "FAIL"} - #{name}"
rescue StandardError => e
  FAIL << name
  puts "FAIL - #{name} (#{e.class}: #{e.message})"
end

def sha_of(bytes)
  Digest::SHA256.hexdigest(bytes)
end

def make_tap(dir)
  FileUtils.mkdir_p(File.join(dir, "Formula"))
  FileUtils.mkdir_p(File.join(dir, "Casks"))
  FileUtils.mkdir_p(File.join(dir, "releases"))
  FileUtils.mkdir_p(File.join(dir, "dl"))
  dir
end

# --- archive-url formula -----------------------------------------------------

check "archive formula bumps url + sha, keeps comments" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "fixturetool.rb")
    File.write(f, <<~RB)
      class Fixturetool < Formula
        desc "fixture"
        url "https://github.com/stump-wtf/fixturetool/archive/refs/tags/v1.0.0.tar.gz"
        sha256 "#{"0" * 64}"
        license "MIT"
        # @joestump 10/01/2026 - Bumped to v1.0.0.
        def install; end
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_fixturetool.json"),
               JSON.generate([{ tag_name: "v1.1.0", prerelease: false, draft: false, assets: [] },
                             { tag_name: "v1.0.0", prerelease: false, draft: false, assets: [] }]))
    File.write(File.join(d, "dl", "v1.1.0.tar.gz"), "newbytes")
    out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                          "--downloads-dir", File.join(d, "dl"))
    body = File.read(f)
    code.zero? &&
      body.include?("archive/refs/tags/v1.1.0.tar.gz") &&
      body.include?(%(sha256 "#{sha_of("newbytes")}")) &&
      body.include?("Bumped to v1.0.0.") &&
      out.include?("bump fixturetool v1.0.0 -> v1.1.0")
  end
end

# --- release-asset formula with several platform urls ------------------------

check "asset formula rewrites every url via the release asset list" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "multiplat.rb")
    old_tag = "v0.5.0"
    urls = %w[darwin_arm64 darwin_amd64 linux_arm64 linux_amd64].map do |plat|
      [File.join("https://github.com/stump-wtf/multiplat/releases/download",
                 "#{old_tag}/multiplat_0.5.0_#{plat}.tar.gz"), sha_of("old-#{plat}")]
    end
    File.open(f, "w") do |io|
      io.puts "class Multiplat < Formula"
      urls.each do |u, s|
        io.puts "  url \"#{u}\""
        io.puts "  sha256 \"#{s}\""
      end
      io.puts "end"
    end
    release = { tag_name: "v0.6.0", prerelease: false, draft: false,
                assets: %w[darwin_arm64 darwin_amd64 linux_arm64 linux_amd64].map do |plat|
                  name = "multiplat_0.6.0_#{plat}.tar.gz"
                  { name: name,
                    browser_download_url: "https://github.com/stump-wtf/multiplat/releases/download/v0.6.0/#{name}" }
                end }
    File.write(File.join(d, "releases", "stump-wtf_multiplat.json"), JSON.generate([release]))
    urls.each_with_index do |_, i|
      File.write(File.join(d, "dl", "multiplat_0.6.0_#{%w[darwin_arm64 darwin_amd64 linux_arm64 linux_amd64][i]}.tar.gz"),
                 "bytes-#{i}")
    end
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    body = File.read(f)
    code.zero? &&
      %w[darwin_arm64 darwin_amd64 linux_arm64 linux_amd64].all? do |plat|
        body.include?("download/v0.6.0/multiplat_0.6.0_#{plat}.tar.gz") &&
          body.include?(sha_of("bytes-#{%w[darwin_arm64 darwin_amd64 linux_arm64 linux_amd64].index(plat)}"))
      end && body.scan(/url "/).size == 4 && !body.include?("v0.5.0")
  end
end

# --- cask with #{version} template -------------------------------------------

check "cask rewrites version + sha, keeps the url template" do
  Dir.mktmpdir do |d|
    make_tap(d)
    c = File.join(d, "Casks", "fixturetool-desktop.rb")
    File.write(c, <<~RB)
      cask "fixturetool-desktop" do
        version "1.0.0"
        sha256 "#{"1" * 64}"
        url "https://github.com/stump-wtf/fixturetool/releases/download/v\#{version}/desktop_universal.zip"
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_fixturetool.json"),
               JSON.generate([{ tag_name: "v1.2.0", prerelease: false, draft: false,
                                assets: [{ name: "desktop_universal.zip",
                                           browser_download_url: "https://github.com/stump-wtf/fixturetool/releases/download/v1.2.0/desktop_universal.zip" }] }]))
    File.write(File.join(d, "dl", "desktop_universal.zip"), "zipbytes")
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    body = File.read(c)
    code.zero? && body.include?('version "1.2.0"') &&
      body.include?(%(sha256 "#{sha_of("zipbytes")}")) &&
      body.include?('download/v#{version}/desktop_universal.zip')
  end
end

# --- formula + cask share one upstream ---------------------------------------

check "formula and cask of one repo bump together" do
  Dir.mktmpdir do |d|
    make_tap(d)
    fo = File.join(d, "Formula", "pairtool.rb")
    File.write(fo, <<~RB)
      class Pairtool < Formula
        url "https://github.com/stump-wtf/pairtool/archive/refs/tags/v2.0.0.tar.gz"
        sha256 "#{"2" * 64}"
      end
    RB
    ca = File.join(d, "Casks", "pairtool-desktop.rb")
    File.write(ca, <<~RB)
      cask "pairtool-desktop" do
        version "2.0.0"
        sha256 "#{"3" * 64}"
        url "https://github.com/stump-wtf/pairtool/releases/download/v\#{version}/app.zip"
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_pairtool.json"),
               JSON.generate([{ tag_name: "v2.1.0", prerelease: false, draft: false,
                                assets: [{ name: "app.zip",
                                           browser_download_url: "https://github.com/stump-wtf/pairtool/releases/download/v2.1.0/app.zip" }] }]))
    File.write(File.join(d, "dl", "v2.1.0.tar.gz"), "src")
    File.write(File.join(d, "dl", "app.zip"), "app")
    out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                          "--downloads-dir", File.join(d, "dl"))
    code.zero? &&
      File.read(fo).include?("refs/tags/v2.1.0.tar.gz") && File.read(fo).include?(sha_of("src")) &&
      File.read(ca).include?('version "2.1.0"') && File.read(ca).include?(sha_of("app")) &&
      out.include?("bump pairtool v2.1.0 (2 file(s))".sub("v2.1.0", "v2.0.0 -> v2.1.0"))
  end
end

# --- already current ----------------------------------------------------------

check "no change when the formula is already current" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "uptodate.rb")
    File.write(f, <<~RB)
      class Uptodate < Formula
        url "https://github.com/stump-wtf/uptodate/archive/refs/tags/v3.0.0.tar.gz"
        sha256 "#{"4" * 64}"
      end
    RB
    before = File.read(f)
    File.write(File.join(d, "releases", "stump-wtf_uptodate.json"),
               JSON.generate([{ tag_name: "v3.0.0", prerelease: false, draft: false, assets: [] }]))
    out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                          "--downloads-dir", File.join(d, "dl"))
    code.zero? && File.read(f) == before && out.include?("current uptodate")
  end
end

# --- release selection ---------------------------------------------------------

check "drafts ignored, prerelease used only when nothing stable" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "pretool.rb")
    File.write(f, <<~RB)
      class Pretool < Formula
        url "https://github.com/stump-wtf/pretool/archive/refs/tags/v1.0.0.tar.gz"
        sha256 "#{"5" * 64}"
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_pretool.json"),
               JSON.generate([{ tag_name: "v2.0.0", prerelease: true, draft: false, assets: [] },
                              { tag_name: "v1.5.0", prerelease: false, draft: true, assets: [] }]))
    File.write(File.join(d, "dl", "v2.0.0.tar.gz"), "pre")
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    code.zero? && File.read(f).include?("refs/tags/v2.0.0.tar.gz") && File.read(f).include?(sha_of("pre"))
  end
end

check "tags fallback when there are no releases" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "tagonly.rb")
    File.write(f, <<~RB)
      class Tagonly < Formula
        url "https://github.com/stump-wtf/tagonly/archive/refs/tags/v0.1.0.tar.gz"
        sha256 "#{"6" * 64}"
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_tagonly.json"), "[]")
    File.write(File.join(d, "releases", "stump-wtf_tagonly.tags.json"),
               JSON.generate([{ name: "v0.3.0" }, { name: "v0.2.0" }]))
    File.write(File.join(d, "dl", "v0.3.0.tar.gz"), "tag")
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    code.zero? && File.read(f).include?("refs/tags/v0.3.0.tar.gz")
  end
end

# --- pinned version -----------------------------------------------------------

check "--version to an older tag declines without writing" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "pinme.rb")
    File.write(f, <<~RB)
      class Pinme < Formula
        url "https://github.com/stump-wtf/pinme/archive/refs/tags/v2.0.0.tar.gz"
        sha256 "#{"7" * 64}"
      end
    RB
    before = File.read(f)
    File.write(File.join(d, "releases", "stump-wtf_pinme.json"), "[]")
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"), "--version", "v1.9.0")
    code.zero? && File.read(f) == before
  end
end

# --- dry-run json ----------------------------------------------------------------

check "--dry-run --json plans without writing" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "jsontool.rb")
    File.write(f, <<~RB)
      class Jsontool < Formula
        url "https://github.com/stump-wtf/jsontool/archive/refs/tags/v1.0.0.tar.gz"
        sha256 "#{"8" * 64}"
      end
    RB
    before = File.read(f)
    File.write(File.join(d, "releases", "stump-wtf_jsontool.json"),
               JSON.generate([{ tag_name: "v1.1.0", prerelease: false, draft: false, assets: [] }]))
    File.write(File.join(d, "dl", "v1.1.0.tar.gz"), "planonly")
    out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                          "--downloads-dir", File.join(d, "dl"), "--dry-run", "--json")
    plan = JSON.parse(out)
    code.zero? && File.read(f) == before && plan.size == 1 && plan[0]["repo"] == "stump-wtf/jsontool" &&
      plan[0]["formula"] == "jsontool" && plan[0]["target"] == "v1.1.0" &&
      plan[0]["changed"] == true && plan[0]["files"] == [f] && !plan[0].key?("error")
  end
end

# --- error path -----------------------------------------------------------------

check "missing fixture artifact exits 2 and writes nothing" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "broken.rb")
    File.write(f, <<~RB)
      class Broken < Formula
        url "https://github.com/stump-wtf/broken/archive/refs/tags/v1.0.0.tar.gz"
        sha256 "#{"9" * 64}"
      end
    RB
    before = File.read(f)
    File.write(File.join(d, "releases", "stump-wtf_broken.json"),
               JSON.generate([{ tag_name: "v1.1.0", prerelease: false, draft: false, assets: [] }]))
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    code == 2 && File.read(f) == before
  end
end

# --- idempotence ------------------------------------------------------------------

check "second run is a no-op" do
  Dir.mktmpdir do |d|
    make_tap(d)
    f = File.join(d, "Formula", "idem.rb")
    File.write(f, <<~RB)
      class Idem < Formula
        url "https://github.com/stump-wtf/idem/archive/refs/tags/v1.0.0.tar.gz"
        sha256 "#{"a" * 64}"
      end
    RB
    File.write(File.join(d, "releases", "stump-wtf_idem.json"),
               JSON.generate([{ tag_name: "v1.1.0", prerelease: false, draft: false, assets: [] }]))
    File.write(File.join(d, "dl", "v1.1.0.tar.gz"), "idem")
    run("--root", d, "--releases-dir", File.join(d, "releases"), "--downloads-dir", File.join(d, "dl"))
    after_first = File.read(f)
    _out, _err, code = run("--root", d, "--releases-dir", File.join(d, "releases"),
                           "--downloads-dir", File.join(d, "dl"))
    code.zero? && File.read(f) == after_first
  end
end

puts
puts "#{PASS.size} passed, #{FAIL.size} failed"
exit(FAIL.empty? ? 0 : 1)
