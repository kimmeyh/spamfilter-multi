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

# A Python interpreter fed by a heredoc on the same line:
#   python - <<'EOF'   python3 <<EOF   py -3 - << "END"
$opener = [regex]::new(
    '(?m)(?:^|[\s;&|(])(?:python3?|py)(?:\.exe)?\b[^\n]*?<<-?\s*([''"]?)([A-Za-z_][A-Za-z0-9_]*)\1')

foreach ($m in $opener.Matches($cmd)) {
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
