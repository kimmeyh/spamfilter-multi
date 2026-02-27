import unittest
import os
import json
import sys

# Add the directory containing withOutlookRulesCSV.py to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from withOutlookRulesYAML import OutlookSecurityAgent

class TestOutlookRulesCSV(unittest.TestCase):

    def setUp(self):
        """Set up test environment"""
        # Create agent in test mode to avoid folder detection issues
        self.agent = OutlookSecurityAgent(test_mode=True)
        self.rules_json, self.safe_senders = self.agent.get_rules()  # get_rules returns a tuple
        self.yaml_file = "test_rules.yaml"

    def tearDown(self):
        """Clean up test environment"""
        if os.path.exists(self.yaml_file):
            os.remove(self.yaml_file)

    def test_export_import_rules_yaml(self):
        """Test exporting and importing rules to/from YAML"""
        # Export rules to YAML
        export_result = self.agent.export_rules_to_yaml(self.rules_json, self.yaml_file)
        self.assertTrue(export_result, "Export should return True on success")

        # Import rules from YAML
        imported_rules = self.agent.get_yaml_rules(self.yaml_file)
        
        # Create timestamp-aware comparison (ignore metadata.last_modified differences)
        def normalize_for_comparison(rules_data):
            """Remove timestamps that change during export for comparison"""
            import copy
            import json
            
            # Deep copy to avoid modifying original
            normalized = copy.deepcopy(rules_data)
            
            # Remove changing timestamps from rules
            if isinstance(normalized, dict) and "rules" in normalized:
                for rule in normalized["rules"]:
                    if isinstance(rule, dict) and "metadata" in rule:
                        if isinstance(rule["metadata"], dict) and "last_modified" in rule["metadata"]:
                            rule["metadata"]["last_modified"] = "NORMALIZED_TIMESTAMP"
            
            return normalized

        # Compare normalized versions (ignoring timestamps)
        normalized_original = normalize_for_comparison(self.rules_json)
        normalized_imported = normalize_for_comparison(imported_rules)
        
        # Check if they match after normalization
        if normalized_original == normalized_imported:
            print("DEBUG test: Rules match (ignoring timestamps)! PASSED")
        else:
            # If they don't match, print out the differences
            differences = self.agent.compare_rules(normalized_original, normalized_imported)
            print("Differences found:")
            print(json.dumps(differences, indent=2))
            self.fail("The imported rules do not match the original rules (excluding timestamps)")
        
        # Assert they match
        self.assertEqual(normalized_original, normalized_imported, "The imported rules do not match the original rules (excluding timestamps)")

if __name__ == '__main__':
    unittest.main()
