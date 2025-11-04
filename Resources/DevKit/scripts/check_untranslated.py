#!/usr/bin/env python3
"""
Check for untranslated strings where English and Chinese values are identical.
This indicates that Chinese translation is missing.

Usage:
    python3 check_untranslated.py [path/to/Localizable.xcstrings]
    
If no path is provided, defaults to FlowDown/Resources/Localizable.xcstrings

Exit codes:
    0 - All strings are properly translated
    1 - Found untranslated strings (or file errors)
"""

import json
import sys
import os

# Exceptions: strings that are the same in English and Chinese (proper nouns, brand names, etc.)
EXCEPTIONS = {
    "Discord",
    "FlowDown",
    "GitHub",
}

def check_untranslated(file_path):
    """Check for strings where en and zh-Hans have identical values."""
    
    # Read the file
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error in {file_path}: {e}")
        sys.exit(1)
    
    strings = data['strings']
    untranslated = []
    
    # Check each string
    for key, value in strings.items():
        # Skip strings marked as shouldTranslate=false
        if not value.get('shouldTranslate', True):
            continue
        
        locs = value.get('localizations', {})
        
        # Check if both en and zh-Hans exist
        if 'en' in locs and 'zh-Hans' in locs:
            en_value = locs['en'].get('stringUnit', {}).get('value', '')
            zh_value = locs['zh-Hans'].get('stringUnit', {}).get('value', '')
            
            # If values are identical and not empty, it's untranslated
            # Skip exceptions (proper nouns, brand names, etc.)
            if en_value and zh_value and en_value == zh_value and key not in EXCEPTIONS:
                untranslated.append({
                    'key': key,
                    'value': en_value
                })
    
    # Report results
    if untranslated:
        print(f"❌ Found {len(untranslated)} untranslated strings in {file_path}:")
        print()
        for item in untranslated:
            print(f"  Key: {item['key']}")
            print(f"  Value: {item['value']}")
            print()
        return False
    else:
        print(f"✅ All strings are properly translated in {file_path}")
        return True

if __name__ == '__main__':
    # Default path to the Localizable.xcstrings file
    default_file_path = os.path.join(
        os.path.dirname(__file__), 
        '..', '..', 
        'FlowDown', 
        'Resources', 
        'Localizable.xcstrings'
    )
    
    # Allow overriding the file path via command line argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_file_path
    
    print(f"📝 Checking for untranslated strings in: {file_path}")
    print()
    
    success = check_untranslated(file_path)
    sys.exit(0 if success else 1)

