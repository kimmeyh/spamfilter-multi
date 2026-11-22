"""Compile the regex dialect of the rule files with Python's re module (F330, Sprint 85).

Shared helper of scripts/validate-yaml-rules.py and scripts/test-regex-patterns.py. The PowerShell
originals compiled patterns with .NET (`[regex]::new(pattern, IgnoreCase)`). The app itself runs the
patterns with Dart RegExp, so neither engine is the real one: this module is a SYNTAX CHECK that
keeps the .NET behavior the originals had, not proof that Dart accepts a pattern.

.NET to Python `re` differences and how each is handled (ADR-0051 rule 4, card R-2):

    construct               .NET                      Python re                  handling
    named group             (?<n>x) and (?'n'x)       (?P<n>x)                   translated
    named back reference    \\k<n> and \\k'n'           (?P=n)                     translated
    absolute end            \\z                        \\Z                         translated
    end or before final LF  \\Z                        (no equivalent letter)     translated to (?=\\n?\\Z)
    escape character        \\e                        (bad escape)               translated to \\x1b
    leading inline flag     (?i)                      only allowed at the start  dropped: IGNORECASE is always on
    other inline flag       (?s) (?m) (?x) (?n) ...   mid-pattern is an error    NOT CHECKED
    scoped flags            (?i:x) (?-i:x)            same                       passed through ((?n:) NOT CHECKED)
    Unicode category        \\p{L}                     not supported              NOT CHECKED
    class subtraction       [a-z-[aeiou]]             not supported              NOT CHECKED
    start of match          \\G                        not supported              NOT CHECKED
    balancing group         (?<a-b>x)                 not supported              NOT CHECKED
    repeated group name     (?<n>a)(?<n>b)            error (redefinition)       NOT CHECKED
    atomic and possessive   (?>x) and x*+             supported from 3.11        passed through (ADR-0051: 3.12 or later)
    RegexOptions            IgnoreCase                re.IGNORECASE              always set (both originals used IgnoreCase)

"NOT CHECKED" means the pattern may well be valid in .NET and Dart but cannot be judged here; callers report
it separately from a real syntax error and never as one.

Known gaps (not detected): `{,n}` is a literal in .NET and `{0,n}` in Python (a meaning change, not a syntax
error); Python accepts `(?P<n>x)`, which .NET rejects.
"""
from __future__ import annotations

import re
import warnings


class NotChecked(Exception):
    """The pattern uses a construct this module cannot translate. Not a syntax error."""


class RegexSyntaxError(Exception):
    """The pattern is not valid even after translation."""


_NAMED_GROUP = re.compile(r"\(\?<([A-Za-z_]\w*)>")
_QUOTED_NAMED_GROUP = re.compile(r"\(\?'([A-Za-z_]\w*)'")
_ODD_NAMED_GROUP = re.compile(r"\(\?<[^=!>][^>]*>")  # (?<a-b>...) and other names Python cannot hold
_INLINE_FLAGS = re.compile(r"\(\?([A-Za-z]+)\)")
_SCOPED_FLAGS = re.compile(r"\(\?([A-Za-z]*(?:-[A-Za-z]*)?):")
_BACKREF = re.compile(r"<([A-Za-z_]\w*)>|'([A-Za-z_]\w*)'")


def translate(pattern: str) -> str:
    """Return the Python spelling of a .NET pattern. Raises NotChecked for an untranslatable construct."""
    out: list[str] = []
    i = 0
    n = len(pattern)
    in_class = False
    while i < n:
        c = pattern[i]
        if c == "\\":
            if i + 1 >= n:
                out.append(c)  # a trailing backslash: let re.compile report it
                i += 1
                continue
            d = pattern[i + 1]
            if d in "pP" and pattern[i + 2:i + 3] == "{":
                raise NotChecked("Unicode category \\" + d + "{...} is not supported by Python re")
            if not in_class:
                if d == "z":
                    out.append(r"\Z")
                    i += 2
                    continue
                if d == "Z":
                    out.append(r"(?=\n?\Z)")
                    i += 2
                    continue
                if d == "G":
                    raise NotChecked("\\G (start of previous match) is not supported by Python re")
                if d == "k":
                    m = _BACKREF.match(pattern, i + 2)
                    if m:
                        out.append("(?P=" + (m.group(1) or m.group(2)) + ")")
                        i = m.end()
                        continue
            if d == "e":
                out.append(r"\x1b")
                i += 2
                continue
            out.append(c + d)
            i += 2
            continue
        if in_class:
            if c == "-" and pattern[i + 1:i + 2] == "[":
                raise NotChecked("character class subtraction is not supported by Python re")
            if c == "]":
                in_class = False
            out.append(c)
            i += 1
            continue
        if c == "[":
            in_class = True
            out.append(c)
            i += 1
            if pattern[i:i + 1] == "^":
                out.append("^")
                i += 1
            if pattern[i:i + 1] == "]":  # a ] right after [ or [^ is a literal
                out.append("]")
                i += 1
            continue
        if c == "(" and pattern.startswith("(?", i):
            m = _NAMED_GROUP.match(pattern, i)
            if m:
                out.append("(?P<" + m.group(1) + ">")
                i = m.end()
                continue
            m = _QUOTED_NAMED_GROUP.match(pattern, i)
            if m:
                out.append("(?P<" + m.group(1) + ">")
                i = m.end()
                continue
            if _ODD_NAMED_GROUP.match(pattern, i):
                raise NotChecked("balancing or unusual group name is not supported by Python re")
            m = _INLINE_FLAGS.match(pattern, i)
            if m:
                if set(m.group(1).lower()) <= {"i"}:
                    i = m.end()  # IGNORECASE is always on, so (?i) changes nothing
                    continue
                raise NotChecked("inline flag (?" + m.group(1) + ") is not translated; Python allows it only at the start")
            m = _SCOPED_FLAGS.match(pattern, i)
            if m:
                if "n" in m.group(1).lower():
                    raise NotChecked("RegexOptions.ExplicitCapture flag (?n:) is not supported by Python re")
                out.append(m.group(0))
                i = m.end()
                continue
        out.append(c)
        i += 1
    return "".join(out)


def compile_net(pattern: str) -> tuple[re.Pattern, list[str]]:
    """Compile a .NET-style pattern case-insensitively. Returns (compiled, warning texts).

    Raises NotChecked when the pattern uses a construct that cannot be judged, RegexSyntaxError when
    the translated pattern is invalid. Python FutureWarning and DeprecationWarning texts (for example a
    possible nested set) come back as warnings.
    """
    translated = translate(pattern)
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        # re caches compiled patterns and returns a cached one WITHOUT parsing it again, so a warning
        # raised at parse time is raised only the first time a pattern is seen in a process. Purge first,
        # so every call reports its warnings (found Sprint 85: a second compile of the same pattern was
        # silently warning-free).
        re.purge()
        try:
            compiled = re.compile(translated, re.IGNORECASE)
        except re.error as exc:
            if "redefinition of group name" in str(exc):
                raise NotChecked("a group name is used twice (allowed by .NET, rejected by Python re)") from exc
            raise RegexSyntaxError(str(exc)) from exc
        except (RecursionError, OverflowError, ValueError) as exc:
            raise RegexSyntaxError(f"{type(exc).__name__}: {exc}") from exc
    return compiled, [f"{w.category.__name__}: {w.message}" for w in caught]


# The four literal-text shapes both PowerShell originals looked for in the pattern TEXT (not the compiled
# pattern). Kept as they were: it is a short list and misses (a+)+ and (\w+)*; widening it changes what warns.
DANGEROUS_PATTERNS: list[tuple[str, str]] = [
    (r"(\.\*){2,}", "Multiple .* in sequence (catastrophic backtracking risk)"),
    (r"\(\.\*\+", ".* followed by + (catastrophic backtracking risk)"),
    (r"\(\.\+\)\*", "(.+)* pattern (catastrophic backtracking risk)"),
    (r"\(\[.*\]\+\)\*", "([...]+)* pattern (catastrophic backtracking risk)"),
]


def performance_warnings(pattern: str) -> list[str]:
    """Descriptions of every DANGEROUS_PATTERNS shape found in the pattern text, in list order."""
    return [text for shape, text in DANGEROUS_PATTERNS if re.search(shape, pattern, re.IGNORECASE)]
