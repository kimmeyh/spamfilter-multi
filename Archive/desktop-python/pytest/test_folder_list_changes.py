#!/usr/bin/env python3
"""
Test script to validate the folder list changes to withOutlookRulesYAML.py
This test validates that the configuration changes work correctly without requiring Outlook.
"""

import sys
import os

# Add the parent directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_email_bulk_folder_names_variable():
    """Test that EMAIL_BULK_FOLDER_NAMES is properly defined"""
    try:
        from withOutlookRulesYAML import EMAIL_BULK_FOLDER_NAMES
        print(f"✓ EMAIL_BULK_FOLDER_NAMES found: {EMAIL_BULK_FOLDER_NAMES}")
        
        # Verify it's a list
        assert isinstance(EMAIL_BULK_FOLDER_NAMES, list), f"EMAIL_BULK_FOLDER_NAMES is not a list, type: {type(EMAIL_BULK_FOLDER_NAMES)}"
        print("✓ EMAIL_BULK_FOLDER_NAMES is a list")
            
        # Verify it contains "Bulk Mail" and "bulk"
        expected_folders = ["Bulk Mail", "bulk"]
        for folder in expected_folders:
            assert folder in EMAIL_BULK_FOLDER_NAMES, f"Missing expected folder: {folder}"
            print(f"✓ Found expected folder: {folder}")
        
    except ImportError as e:
        assert False, f"Failed to import EMAIL_BULK_FOLDER_NAMES: {e}"

def test_class_signature():
    """Test that the OutlookSecurityAgent class has updated signature"""
    try:
        # Import just the class definition to check its signature
        import inspect
        from withOutlookRulesYAML import OutlookSecurityAgent
        
        # Get the __init__ method signature
        init_signature = inspect.signature(OutlookSecurityAgent.__init__)
        params = list(init_signature.parameters.keys())
        
        print(f"✓ OutlookSecurityAgent.__init__ parameters: {params}")
        
        # Check that 'folder_names' parameter exists (not 'folder_name')
        assert 'folder_names' in params, "Missing 'folder_names' parameter"
        print("✓ Found 'folder_names' parameter")
            
        # Check that old 'folder_name' parameter is gone
        assert 'folder_name' not in params, "Old 'folder_name' parameter still exists"
        print("✓ Old 'folder_name' parameter correctly removed")
        
    except Exception as e:
        assert False, f"Failed to inspect class signature: {e}"

def test_commented_old_variable():
    """Test that the old EMAIL_BULK_FOLDER_NAME variable is commented out"""
    try:
        # Try to import the old variable - it should fail
        try:
            from withOutlookRulesYAML import EMAIL_BULK_FOLDER_NAME
            assert False, "Old EMAIL_BULK_FOLDER_NAME variable still exists (should be commented out)"
        except ImportError:
            print("✓ Old EMAIL_BULK_FOLDER_NAME variable properly commented out")
    except Exception as e:
        assert False, f"Unexpected error checking old variable: {e}"

def main():
    """Run all tests"""
    print("Testing folder list changes in withOutlookRulesYAML.py")
    print("=" * 60)
    
    tests = [
        test_email_bulk_folder_names_variable,
        test_class_signature,
        test_commented_old_variable,
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        print(f"\nRunning {test.__name__}...")
        try:
            test()
            print(f"✓ {test.__name__} PASSED")
            passed += 1
        except AssertionError as e:
            print(f"✗ {test.__name__} FAILED: {e}")
            failed += 1
        except Exception as e:
            print(f"✗ {test.__name__} FAILED with exception: {e}")
            failed += 1
    
    print("\n" + "=" * 60)
    print(f"Test Results: {passed} passed, {failed} failed")
    
    assert failed == 0, f"Some tests failed: {passed} passed, {failed} failed"
    print("🎉 All tests passed! The folder list changes are working correctly.")

if __name__ == "__main__":
    try:
        main()
        sys.exit(0)
    except AssertionError as e:
        print(f"❌ Tests failed: {e}")
        sys.exit(1)
