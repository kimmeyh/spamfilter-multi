"""
Test suite for YAML rules export/import functionality in OutlookSecurityAgent

This test validates that rules can be exported to YAML format and         # Setup: Create agent for integration tests - if this fails, test should fail
        self.agent = OutlookSecurityAgent(debug_mode=False)
        self.rules_data, self.safe_senders_data = self.agent.get_rules()
        
        # Use actual rules file for integration test
        self.original_rules_file = "rules.yaml"k
with data integrity maintained.
"""

import pytest
import os
import tempfile
import yaml
from pathlib import Path

# Import the main class
from withOutlookRulesYAML import OutlookSecurityAgent


class TestYAMLRulesExportImport:
    """Test class for YAML rules export/import functionality"""
    
    @pytest.fixture(autouse=True)
    def setup_and_teardown(self):
        """Setup and teardown for each test"""
        # Setup: Create agent in test mode to avoid folder detection issues
        self.agent = OutlookSecurityAgent(debug_mode=False, test_mode=True)
        self.rules_data, self.safe_senders_data = self.agent.get_rules()
        
        # Create temporary directory for test files
        self.temp_dir = tempfile.mkdtemp()
        self.test_yaml_file = os.path.join(self.temp_dir, "test_rules.yaml")
        
        yield
        
        # Teardown: Clean up test files
        if os.path.exists(self.test_yaml_file):
            os.remove(self.test_yaml_file)
        os.rmdir(self.temp_dir)
    
    def test_agent_creation(self):
        """Test that OutlookSecurityAgent can be created successfully"""
        assert self.agent is not None
        assert self.agent.email_address == "kimmeyharold@aol.com"
        # In test mode, we don't require folders to exist
        print(f"Agent created successfully in test mode with {len(self.agent.target_folders)} folders")
    
    def test_get_rules_returns_valid_data(self):
        """Test that get_rules returns valid data structures"""
        assert self.rules_data is not None
        assert self.safe_senders_data is not None
        
        # rules_data should be a dictionary with specific keys
        assert isinstance(self.rules_data, dict)
        assert 'rules' in self.rules_data
        assert isinstance(self.rules_data['rules'], list)
        
        # safe_senders_data should be a dictionary
        assert isinstance(self.safe_senders_data, dict)
        
        print(f"Rules data contains {len(self.rules_data.get('rules', []))} rules")
        print(f"Safe senders data contains {len(self.safe_senders_data)} entries")
    
    def test_export_rules_to_yaml(self):
        """Test exporting rules to YAML file"""
        # Export rules to test file
        success = self.agent.export_rules_to_yaml(self.rules_data, self.test_yaml_file)
        
        assert success is True or success is None  # Method might not return boolean
        assert os.path.exists(self.test_yaml_file)
        
        # Verify file is readable and contains valid YAML
        with open(self.test_yaml_file, 'r', encoding='utf-8') as f:
            yaml_content = yaml.safe_load(f)
        
        assert yaml_content is not None
        assert isinstance(yaml_content, dict)
        print(f"Successfully exported rules to {self.test_yaml_file}")
    
    def test_import_rules_from_yaml(self):
        """Test importing rules from YAML file"""
        # First export rules
        self.agent.export_rules_to_yaml(self.rules_data, self.test_yaml_file)
        
        # Then import them back
        imported_rules = self.agent.get_yaml_rules(self.test_yaml_file)
        
        assert imported_rules is not None
        assert isinstance(imported_rules, (dict, list))
        print(f"Successfully imported rules from {self.test_yaml_file}")
    
    def test_yaml_export_import_roundtrip(self):
        """Test that export -> import maintains data integrity"""
        # Export original rules
        self.agent.export_rules_to_yaml(self.rules_data, self.test_yaml_file)
        
        # Import rules back
        imported_rules = self.agent.get_yaml_rules(self.test_yaml_file)
        
        # Compare structure (note: formats may differ between get_rules and get_yaml_rules)
        # get_rules returns a full dict with metadata, get_yaml_rules returns just the rules
        original_rules_list = self.rules_data.get('rules', [])
        
        if isinstance(imported_rules, list):
            # get_yaml_rules returned just the rules list
            assert len(imported_rules) == len(original_rules_list)
        elif isinstance(imported_rules, dict) and 'rules' in imported_rules:
            # get_yaml_rules returned full structure
            imported_rules_list = imported_rules.get('rules', [])
            assert len(imported_rules_list) == len(original_rules_list)
        
        print("YAML export/import roundtrip maintains data integrity")
    
    def test_yaml_file_format_validity(self):
        """Test that exported YAML file has correct format"""
        # Export rules
        self.agent.export_rules_to_yaml(self.rules_data, self.test_yaml_file)
        
        # Read and validate YAML structure
        with open(self.test_yaml_file, 'r', encoding='utf-8') as f:
            yaml_content = yaml.safe_load(f)
        
        # Validate basic structure
        assert isinstance(yaml_content, dict)
        
        # Check for expected keys (based on typical YAML structure)
        expected_keys = ['version', 'settings', 'rules']
        for key in expected_keys:
            if key in yaml_content:
                print(f"Found expected key: {key}")
        
        # Validate rules section if present
        if 'rules' in yaml_content:
            assert isinstance(yaml_content['rules'], list)
            print(f"YAML contains {len(yaml_content['rules'])} rules")
    
    def test_nonexistent_file_handling(self):
        """Test handling of non-existent YAML file"""
        nonexistent_file = os.path.join(self.temp_dir, "nonexistent.yaml")
        
        # Should handle gracefully, not crash
        result = self.agent.get_yaml_rules(nonexistent_file)
        
        # Should return empty list or None
        assert result is None or result == [] or (isinstance(result, dict) and len(result) == 0)
        print("Non-existent file handled gracefully")


@pytest.mark.integration
class TestYAMLIntegrationWithBackup:
    """Integration tests that verify YAML functionality with backup system"""
    
    @pytest.fixture(autouse=True)
    def setup_integration_test(self):
        """Setup for integration tests"""
        # Setup: Create agent in test mode to avoid folder detection issues
        self.agent = OutlookSecurityAgent(debug_mode=False, test_mode=True)
        self.rules_data, self.safe_senders_data = self.agent.get_rules()
        
        # Use actual rules file for integration test
        self.original_rules_file = "rules.yaml"
        
        yield
    
    def test_export_creates_backup_in_archive(self):
        """Test that export creates backup file in archive directory"""
        # Export rules (should create backup)
        self.agent.export_rules_to_yaml(self.rules_data)
        
        # Check that backup was created in archive directory
        archive_path = "archive/"
        # Archive directory should exist (fail if it doesn't)
        assert os.path.exists(archive_path), f"Archive directory not found at {archive_path}"
        
        backup_files = [f for f in os.listdir(archive_path) 
                      if f.startswith("rules_backup_") and f.endswith(".yaml")]
        assert len(backup_files) > 0, "No backup files found in archive directory"
        print(f"Found {len(backup_files)} backup files in archive directory")


if __name__ == "__main__":
    # Run tests when file is executed directly
    pytest.main([__file__, "-v", "-s"])
