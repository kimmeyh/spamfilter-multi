#!/usr/bin/env python3
"""
Test import compatibility - check that our changes don't break the module structure
"""

import sys
import os

def test_import_without_win32com():
    """Test that we can at least parse the module even without win32com"""
    try:
        # Temporarily mock win32com and IPython to avoid import error
        import types
        mock_win32com = types.ModuleType('win32com')
        mock_client = types.ModuleType('win32com.client')
        mock_client.Dispatch = lambda x: None
        mock_win32com.client = mock_client
        sys.modules['win32com'] = mock_win32com
        sys.modules['win32com.client'] = mock_client
        
        # Mock IPython
        mock_ipython = types.ModuleType('IPython')
        sys.modules['IPython'] = mock_ipython
        
        # Add parent directory to path for import
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        
        # Try to import now
        from withOutlookRulesYAML import EMAIL_BULK_FOLDER_NAMES, OutlookSecurityAgent
        
        print(f"✓ Successfully imported EMAIL_BULK_FOLDER_NAMES: {EMAIL_BULK_FOLDER_NAMES}")
        print(f"✓ Successfully imported OutlookSecurityAgent class")
        
        # Check class signature
        import inspect
        sig = inspect.signature(OutlookSecurityAgent.__init__)
        params = list(sig.parameters.keys())
        print(f"✓ OutlookSecurityAgent.__init__ parameters: {params}")
        
        assert 'folder_names' in params, "'folder_names' parameter missing from __init__"
        print("✓ 'folder_names' parameter found in __init__")
        
    except Exception as e:
        assert False, f"Import test failed: {e}"

def main():
    print("Testing import compatibility...")
    print("=" * 50)
    
    try:
        test_import_without_win32com()
        print("\n✅ Import compatibility test PASSED!")
        return True
    except AssertionError as e:
        print(f"\n❌ Import compatibility test FAILED: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
