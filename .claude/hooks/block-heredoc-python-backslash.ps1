<#
.SYNOPSIS
    PreToolUse hook that blocks running Python from a shell heredoc when the
    heredoc body contains a backslash. Enforces CLAUDE.md IMP-3 (Sprint 72).

.DESCRIPTION
    Fires on the Bash tool. Reads the JSON payload from stdin and:

      - ALLOWS (exit 0) when the command does not feed a heredoc to a Python
        interpreter, when that heredoc body has no backslash, or when the
        command contains the bypass token `allow_heredoc_backslash`.
      - BLOCKS (exit 2) `python ... <<EOF ... EOF` (python, python3, py) whose
        body contains a backslash. stderr carries the corrective instruction.

    WHY: backslashes in a heredoc'd Python program pass through two escaping
    layers (the shell, then Python) and come out changed. Sprint 72: three
    times, once as an edit that printed "inserted" and changed nothing.
    Sprint 74: a `\n` in a Dart string literal was written as a real line
    break. CLAUDE.md IMP-3 already said "write helper scripts to a FILE in the
    scratchpad and run them by path"; the rule alone did not prevent the
    recurrence (Sprint 74 retro IMP-6), so this forcing function is added.

    Deliberately narrow: only a Python heredoc WITH a backslash is blocked.
    A heredoc without one is harmless and stays allowed, as does writing a
    file with `cat > f <<EOF` (not an interpreter), so correct work is not
    blocked -- a guard that fires on correct work trains people to bypass it.

    Sprint 75 retro IMP-2 extends it, by evidence, in two places:
      - ANY heredoc whose body contains a DOUBLE backslash (\\) is blocked: a
        JSON spec written through `cat > f <<'EOF'` lost every \\.
      - A bare `cat > file` with no input is blocked: it waits on stdin until
        the command times out (twice in Sprint 75).
    Single backslashes in a non-Python heredoc stay allowed.

.NOTES
    Exit 0 = allow; Exit 2 = block (stderr fed to Claude).
    Bypass: include the literal token allow_heredoc_backslash in the command.
    Tests: .claude/hooks/test-cases/heredoc-guard/ (run-test-cases.ps1).
#>

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0  # unparseable payload: fail open
}

if ($payload.tool_name -and $payload.tool_name -ne 'Bash') { exit 0 }

$cmd = $null
if ($payload.tool_input -and $payload.tool_input.command) {
    $cmd = [string]$payload.tool_input.command
}
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
if ($cmd -match 'allow_heredoc_backslash') { exit 0 }

# Every heredoc opener; the body is checked when the SAME LINE runs a Python
# interpreter -- before the << (`python - <<EOF`) or after it
# (`cat <<EOF | python -`), bare or path-prefixed (`/usr/bin/python3`,
# `C:\...\python.exe`). PR #440 review: the first version required whitespace
# or ;&|( before the interpreter and the interpreter before <<, so both of
# those shapes passed with a backslash in the body.
$opener = [regex]::new('(?m)^[^\n]*?<<-?\s*([''"]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*$')
$pythonToken = [regex]::new('(?:^|[\s;&|(/\\])(?:python3?|py)(?:\.exe)?(?=\s|$|[;&|)])')

# Sprint 75 retro IMP-2 (a): a bare `cat > file` -- an output redirect, no
# input (no heredoc, no `<`, not fed by a pipe) -- waits on stdin until the
# command times out. It happened twice in Sprint 75 (a stray `cat >` at the
# start of a compound command). Checked per command segment; a segment fed by
# a pipe never starts with `cat`, so `echo x | cat > f` stays allowed.
$segments = $cmd -split '(?:\r?\n|;|&&|\|\|)'
foreach ($seg in $segments) {
    if ($seg -match '^\s*cat\s*>{1,2}\s*("[^"]*"|''[^'']*''|[^\s<|]+)(\s+2>(&1|\S+))?\s*$') {
        [Console]::Error.WriteLine(@"
[BLOCKED] ``cat`` with an output redirect and NO input waits on stdin forever:
  $($seg.Trim())

Sprint 75 retro IMP-2: this hung a command until timeout twice. Write the file
with the Write tool, or give cat its input (a heredoc, < file, or a pipe).
"@)
        exit 2
    }
}

foreach ($m in $opener.Matches($cmd)) {
    if (-not $pythonToken.IsMatch($m.Value)) {
        # Sprint 75 retro IMP-2 (b): ANY heredoc, not only Python. A DOUBLE
        # backslash in a heredoc body came out as one: a JSON spec written with
        # `cat > specs.json <<'EOF'` lost every `\\` and failed to parse. Single
        # backslashes (a Windows path in a commit message) are unaffected and
        # stay allowed.
        $d = $m.Groups[2].Value
        $after = $cmd.Substring($m.Index + $m.Length)
        $end = [regex]::Match($after, "(?m)^\s*$([regex]::Escape($d))\s*$")
        $hbody = if ($end.Success) { $after.Substring(0, $end.Index) } else { $after }
        if ($hbody.Contains('\\')) {
            [Console]::Error.WriteLine(@"
[BLOCKED] A heredoc body contains a DOUBLE backslash (\\).

Sprint 75 retro IMP-2: a JSON spec written through a heredoc lost every \\
(it became \) and the file no longer parsed. Write the file with the Write
tool instead. If the backslashes are genuinely safe, re-run with the literal
token allow_heredoc_backslash in the command.
"@)
            exit 2
        }
        continue
    }
    $delim = $m.Groups[2].Value
    $rest = $cmd.Substring($m.Index + $m.Length)
    $close = [regex]::Match($rest, "(?m)^\s*$([regex]::Escape($delim))\s*$")
    $body = if ($close.Success) { $rest.Substring(0, $close.Index) } else { $rest }
    if ($body.Contains('\')) {
        $msg = @"
[BLOCKED] Python run from a heredoc whose body contains a backslash.

CLAUDE.md IMP-3 (Sprint 72; enforced from the Sprint 74 retro, IMP-6):
backslashes in a heredoc'd Python program pass through the shell AND Python
and come out changed -- a '\n' meant for a Dart string became a real line
break (Sprint 74), and an edit printed "inserted" while changing nothing
(Sprint 72).

Do this instead:
  1. Write the script to a FILE in the scratchpad with the Write tool.
  2. Run it by path:  python "<scratchpad>/script.py"
  3. The script asserts its anchors matched before writing.

If the backslash is genuinely safe here, re-run with the literal token
allow_heredoc_backslash in the command.
"@
        [Console]::Error.WriteLine($msg)
        exit 2
    }
}

exit 0
