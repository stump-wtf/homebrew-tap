#!/usr/bin/env ruby
# frozen_string_literal: true

# tap-bump: rewrite a formula's or cask's upstream pin when the upstream
# project publishes a new release (stump.wtf/homebrew-tap#40).
#
# It scans Formula/*.rb and Casks/*.rb, derives each file's upstream repo
# from its GitHub url line, finds the newest release of that repo, downloads
# the new artifact once to compute its sha256, and rewrites the url, sha256
# (and cask version) lines. Comments are never touched, so a file's bump
# history survives. It never runs git: branching, committing and PRs belong
# to .gitea/workflows/bump.yml.
#
# Modes that make the loop verifiable without waiting for a real release:
#   --dry-run        report what would change, write nothing
#   --json           machine-readable plan (combine with --dry-run)
#   --version TAG    pin an explicit target instead of the newest release
#   --releases-dir   fixture mode: read release JSON from disk, no API calls
#   --downloads-dir  fixture mode: hash local files instead of downloading
#
# Exit codes: 0 success (changed or already current), 2 an upstream fetch or
# download failed or a formula/cask has no parseable upstream GitHub url,
# 3 the request was invalid. A plan that leaves any project skipped or
# unresolved reports it per project and exits 2, never a silent no-op.

require "digest"
require "json"
require "optparse"
require "open3"
require "tempfile"

module TapBump
  ARCHIVE_URL = %r{https://github\.com/(?<owner>[^/" ]+)/(?<repo>[^/" ]+)/archive/refs/tags/(?<tag>[^" ]+)\.tar\.gz}.freeze
  ASSET_URL   = %r{https://github\.com/(?<owner>[^/" ]+)/(?<repo>[^/" ]+)/releases/download/(?<tag>[^/" ]+)/(?<asset>[^" ]+)}.freeze
  URL_LINE    = /^\s*url\s+"/.freeze
  SHA_LINE    = /^\s*sha256\s+"(?<sha>[0-9a-f]{64})"/.freeze
  VERSION_LINE = /^\s*version\s+"(?<ver>[^"]+)"/.freeze

  Error = Class.new(StandardError)

  module_function

  # Compare only the leading numeric segments: "v0.13.0" -> [0,13,0,0].
  def version_key(str)
    (str.to_s.scan(/\d+/).map(&:to_i) + [0, 0, 0, 0])[0, 4]
  end

  # -1/0/1 across version keys.
  def cmp(a, b)
    version_key(a) <=> version_key(b)
  end

  def bare(tag)
    tag.sub(/\Av/, "")
  end

  def curl_get(url)
    cmd = ["curl", "-fsSL", "--max-time", "60", "-H", "Accept: application/vnd.github+json"]
    token = ENV["GITHUB_TOKEN"].to_s
    cmd += ["-H", "Authorization: Bearer #{token}"] unless token.empty?
    cmd << url
    last = nil
    3.times do |attempt|
      out, err, status = Open3.capture3(*cmd)
      return out if status.success?

      last = "GET #{url} failed (curl exit #{status.exitstatus}): #{err.strip}"
      sleep(5 * (attempt + 1)) unless attempt == 2
    end
    raise Error, last
  end

  def sha256_of(url, downloads_dir: nil)
    if downloads_dir
      path = File.join(downloads_dir, File.basename(url))
      raise Error, "fixture download missing for #{url} (expected #{path})" unless File.exist?(path)

      Digest::SHA256.file(path).hexdigest
    else
      Tempfile.create("tap-bump") do |f|
        _out, err, status = Open3.capture3("curl", "-fsSL", "--max-time", "300", "-o", f.path, url)
        raise Error, "download #{url} failed: #{err.strip}" unless status.success?

        Digest::SHA256.file(f.path).hexdigest
      end
    end
  end

  def releases_for(repo, api_base:, releases_dir:)
    if releases_dir
      owner, name = repo.split("/", 2)
      path = File.join(releases_dir, "#{owner}_#{name}.json")
      return File.exist?(path) ? JSON.parse(File.read(path)) : []
    end

    JSON.parse(curl_get("#{api_base}/repos/#{repo}/releases?per_page=100"))
  rescue JSON::ParserError => e
    raise Error, "bad release JSON for #{repo}: #{e.message}"
  end

  # Newest non-draft release; prereleases only when nothing stable exists.
  def pick_release(releases)
    usable = releases.reject { |r| r["draft"] }
    stable = usable.reject { |r| r["prerelease"] }
    (stable.empty? ? usable : stable).max_by { |r| version_key(r["tag_name"]) }
  end

  def latest_tag(repo, api_base:, releases_dir:)
    if releases_dir
      owner, name = repo.split("/", 2)
      path = File.join(releases_dir, "#{owner}_#{name}.tags.json")
      return [] unless File.exist?(path)

      JSON.parse(File.read(path)).map { |t| t["name"] }
    else
      JSON.parse(curl_get("#{api_base}/repos/#{repo}/tags?per_page=100")).map { |t| t["name"] }
    end
  end

  def target_tag(repo, pinned:, api_base:, releases_dir:)
    return [pinned, nil] if pinned

    releases = Array(releases_for(repo, api_base: api_base, releases_dir: releases_dir))
    release = pick_release(releases)
    return [release["tag_name"], release] if release

    tags = Array(latest_tag(repo, api_base: api_base, releases_dir: releases_dir))
    raise Error, "#{repo}: no releases and no tags found" if tags.empty?

    [tags.max_by { |t| version_key(t) }, nil]
  end

  def scan(root)
    Dir.glob(File.join(root, "Formula", "*.rb")).sort.map { |p| [p, :formula] } +
      Dir.glob(File.join(root, "Casks", "*.rb")).sort.map { |p| [p, :cask] }
  end

  def upstream_repo(path)
    File.foreach(path) do |line|
      next if line.lstrip.start_with?("#")

      m = line.match(ARCHIVE_URL) || line.match(ASSET_URL)
      return "#{m[:owner]}/#{m[:repo]}" if m
    end
    nil
  end

  def current_tag(path, kind)
    if kind == :cask
      File.foreach(path) do |line|
        next if line.lstrip.start_with?("#")

        match = line.match(VERSION_LINE)
        return match[:ver] if match
      end
      nil
    else
      File.foreach(path) do |line|
        next if line.lstrip.start_with?("#")

        m = line.match(ARCHIVE_URL) || line.match(ASSET_URL)
        return m[:tag] if m
      end
      nil
    end
  end

  # Replace only within one line's quoted url attribute, never comments.
  def rewrite_url(line, new_url)
    indent = line[/\A\s*/]
    "#{indent}url \"#{new_url}\"\n"
  end

  def set_line_sha(line, sha)
    indent = line[/\A\s*/]
    "#{indent}sha256 \"#{sha}\"\n"
  end

  def set_version(line, ver)
    indent = line[/\A\s*/]
    "#{indent}version \"#{ver}\"\n"
  end

  # Rewrite one file to new_tag. Returns true if content changed.
  def bump_file(path, kind, new_tag, release, downloads_dir: nil, write: true)
    lines = File.readlines(path)
    changed = false

    if kind == :cask
      old_ver = nil
      url_line_idx = nil
      template = nil
      lines.each_with_index do |line, idx|
        next if line.lstrip.start_with?("#")

        old_ver ||= (m = line.match(VERSION_LINE)) && m[:ver]
        if url_line_idx.nil? && (m = line.match(ASSET_URL) || line.match(ARCHIVE_URL))
          url_line_idx = idx
          template = line
        end
      end
      raise Error, "#{path}: no version line found" if old_ver.nil?
      raise Error, "#{path}: no github url found" if url_line_idx.nil?
      return false if cmp(old_ver, new_tag) >= 0

      new_bare = bare(new_tag)
      eff_url = template.dup
      eff_url.gsub!("\#{version}", new_bare)
      eff_url.gsub!(old_ver, new_bare) if eff_url.include?(old_ver)
      eff_url = eff_url[/url\s+"([^"]+)"/, 1]
      sha = sha256_of(eff_url, downloads_dir: downloads_dir)

      lines.each_with_index do |line, idx|
        next if line.lstrip.start_with?("#")

        if line.match(VERSION_LINE)
          lines[idx] = set_version(line, new_bare)
          changed = true
          break
        end
      end
      if (idx = lines.index { |l| !l.lstrip.start_with?("#") && l.match(SHA_LINE) })
        lines[idx] = set_line_sha(lines[idx], sha)
        changed = true
      else
        raise Error, "#{path}: no sha256 line found"
      end
      if template.include?(old_ver)
        lines[url_line_idx] = template.gsub(old_ver, new_bare)
        changed = true
      end
      File.write(path, lines.join) if changed && write
      return changed
    end

    new_bare = bare(new_tag)
    i = 0
    while i < lines.size
      line = lines[i]
      i += 1
      next if line.lstrip.start_with?("#")
      next unless line =~ URL_LINE

      m = line.match(ASSET_URL) || line.match(ARCHIVE_URL)
      next unless m
      next if cmp(m[:tag], new_tag) >= 0

      old_tag = m[:tag]
      old_bare = bare(old_tag)
      if m.names.include?("asset")
        want_asset = m[:asset].include?(old_bare) ? m[:asset].gsub(old_bare, new_bare) : m[:asset]
        from_release = release && Array(release["assets"]).find { |a| a["name"] == want_asset }
        new_url = from_release ? from_release["browser_download_url"]
                               : "https://github.com/#{m[:owner]}/#{m[:repo]}/releases/download/#{new_tag}/#{want_asset}"
      else
        new_url = line[/url\s+"([^"]+)"/, 1].sub(old_tag, new_tag)
      end
      sha = sha256_of(new_url, downloads_dir: downloads_dir)

      lines[i - 1] = rewrite_url(line, new_url)
      changed = true
      j = i
      j += 1 while j < lines.size && lines[j].lstrip.start_with?("#")
      if j < lines.size && lines[j].match(SHA_LINE) && !lines[j].match(URL_LINE)
        lines[j] = set_line_sha(lines[j], sha)
      else
        raise Error, "#{path}: no sha256 after url at line #{i}"
      end
      i = j + 1
    end
    File.write(path, lines.join) if changed && write
    changed
  end

  def plan(root, formula: nil, version: nil, api_base: "https://api.github.com",
           releases_dir: nil, downloads_dir: nil, apply: true, only_repo: nil)
    unresolved = []
    entries = scan(root).filter_map do |path, kind|
      repo = upstream_repo(path)
      if repo.nil?
        unresolved << { path: path, kind: kind }
        next
      end
      next if formula && File.basename(path, ".rb") != formula && File.basename(path, ".rb") != "#{formula}-desktop"
      next if only_repo && repo != only_repo

      { path: path, kind: kind, repo: repo, current: current_tag(path, kind) }
    end

    if entries.empty? && (formula || only_repo)
      wanted = formula ? "formula/cask named #{formula.inspect}" : "upstream repo #{only_repo.inspect}"
      return [{ "repo" => only_repo, "formula" => formula, "changed" => false,
                "error" => "no tracked file matches the requested #{wanted}" }]
    end

    groups = entries.group_by { |e| e[:repo] }
    results = []
    groups.each do |repo, files|
      res = { "repo" => repo, "files" => files.map { |f| f[:path] }, "changed" => false }
      name = files.map { |f| File.basename(f[:path], ".rb") }.find { |n| !n.end_with?("-desktop") } ||
             files.first[:path].split("/").last.delete_suffix(".rb")
      res["formula"] = name
      currents = files.map { |f| f[:current] }.compact
      res["current"] = currents.max_by { |t| version_key(t) }
      begin
        target, release = target_tag(repo, pinned: version, api_base: api_base, releases_dir: releases_dir)
        res["target"] = target
        res["note"] = "already current" if res["current"] && cmp(target, res["current"]) <= 0
        any = false
        files.each do |f|
          any = bump_file(f[:path], f[:kind], target, release, downloads_dir: downloads_dir, write: apply) || any
        end
        res["changed"] = any
      rescue Error => e
        res["error"] = e.message
      end
      results << res
    end
    unresolved.each do |u|
      results << { "repo" => nil, "formula" => File.basename(u[:path], ".rb"),
                   "kind" => u[:kind].to_s, "changed" => false,
                   "error" => "no upstream GitHub url in #{u[:path]}: the bump loop can never track this project" }
    end
    results.sort_by { |r| r["repo"].to_s }
  end

  def cli(argv)
    opts = { root: ".", api_base: "https://api.github.com", json: false, dry_run: false }
    OptionParser.new do |o|
      o.banner = "usage: tap-bump.rb [--dry-run] [--json] [--formula NAME] [--only-repo OWNER/REPO] [--version TAG] [--root DIR]"
      o.on("--root DIR") { |v| opts[:root] = v }
      o.on("--only-repo SLUG") { |v| v =~ /\A[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+\z/ or abort "invalid repo slug #{v}"
                                 opts[:only_repo] = v }
      o.on("--formula NAME") { |v| v =~ /\A[a-z0-9][a-z0-9-]*\z/ or abort "invalid formula name #{v}"
                               opts[:formula] = v }
      o.on("--version TAG") { |v| v =~ /\Av?[0-9][A-Za-z0-9._+-]*\z/ or abort "invalid version #{v}"
                              opts[:version] = v.start_with?("v") ? v : "v#{v}" }
      o.on("--api-base URL") { |v| opts[:api_base] = v.sub(%r{/+\z}, "") }
      o.on("--releases-dir DIR") { |v| opts[:releases_dir] = v }
      o.on("--downloads-dir DIR") { |v| opts[:downloads_dir] = v }
      o.on("--dry-run") { opts[:dry_run] = true }
      o.on("--json") { opts[:json] = true }
    end.parse!(argv)
    abort "no such directory #{opts[:root]}" unless Dir.exist?(opts[:root])

    results = plan(opts[:root], formula: opts[:formula], version: opts[:version],
                   api_base: opts[:api_base], releases_dir: opts[:releases_dir],
                   downloads_dir: opts[:downloads_dir], apply: !opts[:dry_run],
                   only_repo: opts[:only_repo])
    if opts[:json]
      puts JSON.pretty_generate(results)
    else
      results.each do |r|
        if r["error"]
          warn "tap-bump: #{r["repo"] || r["formula"]}: #{r["error"]}"
        elsif r["changed"]
          puts "bump #{r['formula']} #{r['current']} -> #{r['target']} (#{r['files'].size} file(s))"
        else
          puts "current #{r['formula']} #{r['current']} (target #{r['target']})"
        end
      end
    end
    results.any? { |r| r["error"] } ? 2 : 0
  end
end

exit TapBump.cli(ARGV) if $PROGRAM_NAME == __FILE__
