<#
.SYNOPSIS
    PreToolUse hook that blocks staging EVERYTHING (`git add -A`, `--all`,
    `.`) unless the same command ran `git status` first. Enforces the
    CLAUDE.md rule "Don't stage a commit without looking at what you are
    staging" (Sprint 52 IMP-4).

.DESCRIPTION
    Fires on the Bash and PowerShell tools. Reads the JSON payload from stdin:

      - ALLOWS (exit 0) staging named paths, any command that runs
        `git status` BEFORE its `git add -A/--all/.`, and any command carrying
        the bypass token `allow_blind_staging`.
      - BLOCKS (exit 2) `git add -A`, `git add --all` or `git add .` with no
        earlier `git status` in the same command. stderr carries the fix.

    WHY: the rule existed and was broken again in Sprint 76 -- `git add -A`
    ran before `git status`, and a `0*` working file of Harold's went into a
    version-bump commit with no mention (retro IMP-4: prevention first, a rule
    alone did not prevent the recurrence).

    Text inside quotes is ignored, so a commit message that MENTIONS
    `git add -A` is not blocked -- a guard that fires on correct work trains
    people to bypass it. The one exception is a command handed to a shell in
    quotes (`bash -c "..."`, `powershell -Command "..."`), which is unwrapped
    and checked.

    Sprint 76 7.7.1 review widened what counts as "staging everything":
      - any case (`Git add -A`), `git.exe`, and global options before the
        subcommand (`git -c k=v add -A`, `git --no-pager add -A`);
      - combined or extra flags (`-fA`, `-v -A`, `-u`, `--update`) and the
        whole-tree pathspecs `.`, `./`, `:/`, also after `--`;
      - `git commit -a` / `-am` / `--all`, which stage every tracked change
        (a tracked 0* file included) without a separate `git add`.
    A `git status` whose output is thrown away (`> $null`, `> /dev/null`,
    `| Out-Null`) does not count as looking.

    An internal error in this hook ALLOWS the command (exit 0 with a note on
    stderr): a broken guard must not block all work. The test suite is what
    keeps it from breaking.

.NOTES
    Exit 0 = allow; Exit 2 = block (stderr fed to Claude).
    Bypass: include the literal token allow_blind_staging in the command.
    Tests: .claude/hooks/test-cases/staging-guard/ (run-test-cases.ps1).
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0  # unparseable payload: fail open
}

if ($payload.tool_name -and $payload.tool_name -notin @('Bash', 'PowerShell')) { exit 0 }

$cmd = $null
if ($payload.tool_input -and $payload.tool_input.command) {
    $cmd = [string]$payload.tool_input.command
}
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
if ($cmd -match 'allow_blind_staging') { exit 0 }

try {
    # Unwrap a command handed to a shell in quotes, so `bash -c "git add -A"`
    # is checked rather than discarded with the other quoted text.
    $shellWrap = '(?i)\b(?:bash|sh|pwsh|powershell)(?:\.exe)?\b[^"''\r\n;|&]*?\s-(?:c|Command)\s+(?:"([^"]*)"|''([^'']*)'')'
    $unwrapped = [regex]::Replace($cmd, $shellWrap, { param($m) ' ' + $m.Groups[1].Value + $m.Groups[2].Value + ' ' })

    # Drop quoted text (commit messages, echo strings) so only real commands count.
    $code = [regex]::Replace($unwrapped, '"[^"]*"|''[^'']*''', '""')

    # `git` (any case, optional .exe) plus global options, then the subcommand
    # and the rest of that command segment (up to ; & | or a line break).
    $gitPrefix = '(?i)\bgit(?:\.exe)?(?:\s+(?:-[Cc]\s+\S+|--?[A-Za-z][\w-]*(?:=\S+)?))*\s+'
    $segment = '([^;&|\r\n]*)'

    function Find-StageAll([string]$text) {
        foreach ($m in [regex]::Matches($text, $gitPrefix + 'add\b' + $segment)) {
            foreach ($tok in ($m.Groups[1].Value -split '\s+')) {
                if ($tok -cmatch '^-[A-Za-z]*[Au][A-Za-z]*$' -or
                    $tok -match '^(?i)--(?:all|update)$' -or
                    $tok -match '^(?:\.|\./|:/)$') { return $m }
            }
        }
        foreach ($m in [regex]::Matches($text, $gitPrefix + 'commit\b' + $segment)) {
            foreach ($tok in ($m.Groups[1].Value -split '\s+')) {
                if ($tok -cmatch '^-[A-Za-z]*a[A-Za-z]*$' -or $tok -match '^(?i)--all$') { return $m }
            }
        }
        return $null
    }

    $add = Find-StageAll $code
    if ($null -eq $add) { exit 0 }

    # A `git status` counts only when it runs earlier AND its output is seen.
    foreach ($st in [regex]::Matches($code, $gitPrefix + 'status\b' + $segment)) {
        if ($st.Index -ge $add.Index) { break }
        $rest = $st.Groups[1].Value
        $tail = $code.Substring($st.Index + $st.Length)
        if ($rest -match '>\s*(?:\$null|/dev/null|nul)\b' -or $tail -match '^\s*\|\s*Out-Null\b') { continue }
        exit 0
    }
} catch {
    [Console]::Error.WriteLine("[block-blind-staging] internal error, command allowed: $($_.Exception.Message)")
    exit 0
}

[Console]::Error.WriteLine(@"
[BLOCKED] Staging everything without looking first:
  $($add.Value)

CLAUDE.md (Sprint 52 IMP-4; enforced from the Sprint 76 retro, IMP-4): run
``git status --short`` FIRST and account for every entry -- in Sprint 76 a
``git add -A`` before the status check swept Harold's 0* working file into a
version-bump commit with no mention.

Do this instead, in ONE command:
  git status --short; git add -A; git commit ...
or stage the paths you mean by name.

If staging everything unseen is genuinely intended, re-run with the literal
token allow_blind_staging in the command.
"@)
exit 2
