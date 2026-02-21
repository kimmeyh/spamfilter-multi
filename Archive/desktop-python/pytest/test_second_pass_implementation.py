#!/usr/bin/env python3
"""
Test script for second-pass email processing implementation
Tests the new _get_emails_from_folder method and second-pass processing logic
"""

import ast
import inspect
import os

def test_helper_method_exists():
    """Test that the _get_emails_from_folder helper method exists"""
    try:
        file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "withOutlookRulesYAML.py")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if the method exists
        assert '_get_emails_from_folder' in content, "_get_emails_from_folder method not found"
        print("✓ _get_emails_from_folder method found")
            
    except Exception as e:
        print(f"✗ Error reading file or assertion failed: {e}")
        raise

def test_second_pass_logic():
    """Test that second-pass processing logic has been added"""
    try:
        file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "withOutlookRulesYAML.py")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check for second-pass processing keywords
        second_pass_indicators = [
            'Second-pass processing:',
            'second_pass_emails',
            'second_pass_added_info',
            'Starting second-pass email processing',
            'Second-pass: Found',
            'Second-pass Processing Summary'
        ]
        
        found_indicators = []
        for indicator in second_pass_indicators:
            if indicator in content:
                found_indicators.append(indicator)
        
        print(f"✓ Found {len(found_indicators)}/{len(second_pass_indicators)} second-pass indicators")
        
        assert len(found_indicators) >= 4, f"Second-pass processing logic incomplete. Found only {len(found_indicators)}/{len(second_pass_indicators)} indicators"
        print("✓ Second-pass processing logic appears to be implemented")
            
    except Exception as e:
        print(f"✗ Error reading file or assertion failed: {e}")
        raise

def test_method_signature():
    """Test that the _get_emails_from_folder method has correct signature"""
    try:
        file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "withOutlookRulesYAML.py")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Parse the AST to find the method
        tree = ast.parse(content)
        
        method_found = False
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == '_get_emails_from_folder':
                method_found = True
                # Check method signature
                args = [arg.arg for arg in node.args.args]
                expected_args = ['self', 'folder', 'days_back']
                
                assert args == expected_args, f"Method signature incorrect. Expected: {expected_args}, Got: {args}"
                print(f"✓ Method signature correct: {args}")
                break
        
        assert method_found, "Method _get_emails_from_folder not found in AST"
        
    except Exception as e:
        print(f"✗ Error parsing file or assertion failed: {e}")
        raise

def test_after_prompt_update_rules():
    """Test that second-pass processing is placed after prompt_update_rules"""
    try:
        file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "withOutlookRulesYAML.py")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Find positions of key text
        prompt_update_pos = content.find('self.prompt_update_rules(')
        second_pass_pos = content.find('Second-pass processing:')
        
        assert prompt_update_pos != -1, "prompt_update_rules call not found"
        assert second_pass_pos != -1, "Second-pass processing not found"
        assert second_pass_pos > prompt_update_pos, "Second-pass processing not in correct position"
        
        print("✓ Second-pass processing correctly placed after prompt_update_rules")
            
    except Exception as e:
        print(f"✗ Error reading file or assertion failed: {e}")
        raise

def main():
    """Run all tests for second-pass implementation"""
    print("Testing second-pass email processing implementation")
    print("=" * 60)
    
    tests = [
        test_helper_method_exists,
        test_method_signature,
        test_second_pass_logic,
        test_after_prompt_update_rules
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        print(f"\nRunning {test.__name__}...")
        try:
            test()
            passed += 1
            print(f"✅ {test.__name__} PASSED")
        except AssertionError as e:
            print(f"❌ {test.__name__} FAILED: {e}")
        except Exception as e:
            print(f"❌ {test.__name__} ERROR: {e}")
    
    print("\n" + "=" * 60)
    print(f"Test Results: {passed} passed, {total - passed} failed")
    
    if passed == total:
        print("✅ All second-pass implementation tests PASSED!")
    else:
        print("❌ Some tests failed. Please check the implementation.")

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
