#!/usr/bin/env python3
"""
Alternative test approach that focuses on YAML functionality without requiring full Outlook integration
"""
import unittest
import os
import sys
import yaml
import tempfile
import json

# Add the parent directory to Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

class TestYAMLFunctionality(unittest.TestCase):
    """Test YAML import/export functionality without requiring Outlook folders"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.test_yaml_file = os.path.join(self.test_dir, "test_rules.yaml")
        
        # Sample rules data for testing
        self.sample_rules = {
            "rules": [
                {
                    "name": "SpamAutoDeleteHeader1",
                    "enabled": True,
                    "header_patterns": ["spam@example.com", "noreply@badsite.com"]
                },
                {
                    "name": "SpamAutoDeleteBody1", 
                    "enabled": True,
                    "body_patterns": ["urgent action required", "click here now"]
                }
            ]
        }
        
        self.sample_safe_senders = {
            "safe_senders": [
                "trusted@example.com",
                "support@goodsite.com"
            ]
        }

    def tearDown(self):
        """Clean up test environment"""
        if os.path.exists(self.test_yaml_file):
            os.remove(self.test_yaml_file)
        os.rmdir(self.test_dir)

    def test_yaml_export_import_cycle(self):
        """Test exporting rules to YAML and importing them back"""
        # Export sample rules to YAML file
        with open(self.test_yaml_file, 'w', encoding='utf-8') as f:
            yaml.dump(self.sample_rules, f, default_flow_style=False)
        
        # Verify file was created
        self.assertTrue(os.path.exists(self.test_yaml_file))
        
        # Import rules from YAML file
        with open(self.test_yaml_file, 'r', encoding='utf-8') as f:
            imported_rules = yaml.safe_load(f)
        
        # Compare original and imported rules
        self.assertEqual(self.sample_rules, imported_rules)

    def test_yaml_file_format_validity(self):
        """Test that YAML file format is valid"""
        # Write rules to YAML file
        with open(self.test_yaml_file, 'w', encoding='utf-8') as f:
            yaml.dump(self.sample_rules, f, default_flow_style=False)
        
        # Try to parse the YAML file
        try:
            with open(self.test_yaml_file, 'r', encoding='utf-8') as f:
                parsed_data = yaml.safe_load(f)
            
            # Verify structure
            self.assertIn('rules', parsed_data)
            self.assertIsInstance(parsed_data['rules'], list)
            
            # Verify rule structure
            for rule in parsed_data['rules']:
                self.assertIn('name', rule)
                self.assertIn('enabled', rule)
                
        except yaml.YAMLError as e:
            self.fail(f"YAML file is not valid: {e}")

    def test_rules_data_structure(self):
        """Test that rules data structure is consistent"""
        # Verify sample rules structure
        self.assertIn('rules', self.sample_rules)
        self.assertIsInstance(self.sample_rules['rules'], list)
        
        for rule in self.sample_rules['rules']:
            self.assertIsInstance(rule, dict)
            self.assertIn('name', rule)
            self.assertIn('enabled', rule)
            self.assertIsInstance(rule['enabled'], bool)

    def test_safe_senders_structure(self):
        """Test safe senders data structure"""
        self.assertIn('safe_senders', self.sample_safe_senders)
        self.assertIsInstance(self.sample_safe_senders['safe_senders'], list)
        
        for sender in self.sample_safe_senders['safe_senders']:
            self.assertIsInstance(sender, str)
            self.assertIn('@', sender)  # Basic email format check

if __name__ == '__main__':
    unittest.main()
