#!/usr/bin/env python3
"""Remove emojis from markdown files and replace with text equivalents."""

import os
import glob

# Emoji replacement mapping
EMOJI_MAP = {
    '✅': '[OK]',
    '❌': '[FAIL]',
    '⚠️': '[WARNING]',
    '🔄': '[PENDING]',
    '✨': '[NEW]',
    '🐛': '[BUG]',
    '🚫': '[STOP]',
    '🔍': '[INVESTIGATION]',
    '📋': '[CHECKLIST]',
    '📌': '[PIN]',
    '🎯': '[TARGET]',
    '💡': '[IDEA]',
    '🚀': '[LAUNCH]',
    '👍': '[APPROVE]',
    '👎': '[REJECT]',
    '🔧': '[CONFIG]',
    '🛠️': '[TOOLS]',
    '💻': '[CODE]',
    '📝': '[NOTES]',
    '🎨': '[DESIGN]',
    '🧪': '[TEST]',
}

def remove_emojis_from_file(filepath):
    """Remove emojis from a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    for emoji, replacement in EMOJI_MAP.items():
        content = content.replace(emoji, replacement)

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8', newline='') as f:
            f.write(content)
        return True
    return False

def main():
    docs_dir = r'D:\Data\Harold\github\spamfilter-multi\docs'
    files_changed = 0

    for filepath in glob.glob(os.path.join(docs_dir, '**', '*.md'), recursive=True):
        if remove_emojis_from_file(filepath):
            files_changed += 1
            print(f'Updated: {filepath}')

    print(f'\nTotal files changed: {files_changed}')

if __name__ == '__main__':
    main()
