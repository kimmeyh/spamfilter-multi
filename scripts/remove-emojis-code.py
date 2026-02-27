#!/usr/bin/env python3
"""Remove emojis from code files and replace with text equivalents."""

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
    mobile_app_dir = r'D:\Data\Harold\github\spamfilter-multi\mobile-app'
    files_changed = 0

    # Scan lib/ directory for .dart files
    lib_dir = os.path.join(mobile_app_dir, 'lib')
    for filepath in glob.glob(os.path.join(lib_dir, '**', '*.dart'), recursive=True):
        if remove_emojis_from_file(filepath):
            files_changed += 1
            print(f'Updated: {filepath}')

    # Scan test/ directory for .dart files
    test_dir = os.path.join(mobile_app_dir, 'test')
    for filepath in glob.glob(os.path.join(test_dir, '**', '*.dart'), recursive=True):
        if remove_emojis_from_file(filepath):
            files_changed += 1
            print(f'Updated: {filepath}')

    print(f'\nTotal code files changed: {files_changed}')

if __name__ == '__main__':
    main()
