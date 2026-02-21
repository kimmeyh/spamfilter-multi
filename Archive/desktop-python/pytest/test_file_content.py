#!/usr/bin/env python3
"""
Test script to validate the folder list changes to withOutlookRulesYAML.py
This test validates file content directly without importing modules that require Outlook.
"""

import os
import re

def test_file_content():
    """Test the file content directly"""
    file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "withOutlookRulesYAML.py")
    
    assert os.path.exists(file_path), f"File not found: {file_path}"
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    tests_passed = 0
    tests_total = 0
    
    # Test 1: Check that EMAIL_BULK_FOLDER_NAMES exists
    tests_total += 1
    if 'EMAIL_BULK_FOLDER_NAMES = ["Bulk Mail", "bulk"]' in content:
        print("✓ EMAIL_BULK_FOLDER_NAMES properly defined with list containing 'Bulk Mail' and 'bulk'")
        tests_passed += 1
    else:
        print("✗ EMAIL_BULK_FOLDER_NAMES not found or incorrectly defined")
        
    # Test 2: Check that old EMAIL_BULK_FOLDER_NAME is commented out
    tests_total += 1
    if '# EMAIL_BULK_FOLDER_NAME = "Bulk Mail"' in content:
        print("✓ Old EMAIL_BULK_FOLDER_NAME properly commented out")
        tests_passed += 1
    else:
        print("✗ Old EMAIL_BULK_FOLDER_NAME not properly commented out")
        
    # Test 3: Check that __init__ method uses folder_names parameter (with optional test_mode)
    tests_total += 1
    if ('def __init__(self, email_address=EMAIL_ADDRESS, folder_names=EMAIL_BULK_FOLDER_NAMES, debug_mode=DEBUG):' in content or
        'def __init__(self, email_address=EMAIL_ADDRESS, folder_names=EMAIL_BULK_FOLDER_NAMES, debug_mode=DEBUG, test_mode=False):' in content):
        print("✓ __init__ method properly updated to use folder_names parameter")
        tests_passed += 1
    else:
        print("✗ __init__ method not properly updated")
        
    # Test 4: Check that target_folders is used (plural)
    tests_total += 1
    if 'self.target_folders = []' in content:
        print("✓ target_folders property properly defined as list")
        tests_passed += 1
    else:
        print("✗ target_folders property not found")
        
    # Test 5: Check that multiple folders are processed
    tests_total += 1
    if 'for folder_name in folder_names:' in content:
        print("✓ Code properly iterates through multiple folder names")
        tests_passed += 1
    else:
        print("✗ Code does not iterate through multiple folder names")
        
    # Test 6: Check that process_emails method handles multiple folders
    tests_total += 1
    if 'for target_folder in self.target_folders:' in content:
        print("✓ process_emails method properly handles multiple folders")
        tests_passed += 1
    else:
        print("✗ process_emails method does not handle multiple folders")
        
    # Test 7: Check that _find_folder_recursive method exists
    tests_total += 1
    if 'def _find_folder_recursive(self, root_folder, folder_name):' in content:
        print("✓ _find_folder_recursive method properly added")
        tests_passed += 1
    else:
        print("✗ _find_folder_recursive method not found")
        
    # Test 8: Check that all_emails_to_process is used instead of emails_to_process
    tests_total += 1
    if 'all_emails_to_process = []' in content and 'all_emails_added_info = []' in content:
        print("✓ New variable names for processing multiple folders properly used")
        tests_passed += 1
    else:
        print("✗ New variable names not properly implemented")
        
    print(f"\nTest Results: {tests_passed}/{tests_total} tests passed")
    
    assert tests_passed == tests_total, f"File content tests failed: {tests_passed}/{tests_total} tests passed"
    print("🎉 All file content tests passed!")

def main():
    """Run the test"""
    print("Testing folder list changes in withOutlookRulesYAML.py (file content)")
    print("=" * 70)
    
    try:
        test_file_content()
        print("\n✅ SUCCESS: All changes have been properly implemented!")
        print("\nSummary of changes made:")
        print("• Changed EMAIL_BULK_FOLDER_NAME to EMAIL_BULK_FOLDER_NAMES list")
        print("• Added 'bulk' folder to the list")
        print("• Updated __init__ method to accept folder_names parameter")
        print("• Modified folder processing to handle multiple folders")
        print("• Updated email processing to work with multiple folders")
        print("• Added missing _find_folder_recursive method")
        print("• Commented out old code instead of deleting it")
        return True
    except AssertionError as e:
        print(f"\n❌ FAILURE: {e}")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
