"""
pytest configuration file for OutlookMailSpamFilter tests
"""
import sys
import os
import pytest
from unittest.mock import Mock, MagicMock

# Add the parent directory to Python path so we can import the main module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock Outlook dependencies for testing
@pytest.fixture(autouse=True)
def mock_outlook_dependencies():
    """Automatically mock Outlook dependencies for all tests"""
    # Mock win32com.client if it's not available
    if 'win32com' not in sys.modules:
        sys.modules['win32com'] = Mock()
        sys.modules['win32com.client'] = Mock()
        
    # Mock IPython if it's not available
    if 'IPython' not in sys.modules:
        sys.modules['IPython'] = Mock()
        
    # Mock Outlook functionality
    mock_outlook = Mock()
    mock_namespace = Mock()
    mock_folder = Mock()
    
    # Setup mock folder structure
    mock_folder.Name = "Test Folder"
    mock_folder.Items = []
    mock_namespace.Folders = [mock_folder]
    mock_outlook.GetNamespace.return_value = mock_namespace
    
    if 'win32com.client' in sys.modules:
        sys.modules['win32com.client'].Dispatch = Mock(return_value=mock_outlook)
        
    yield
    
    # Clean up after test
    pass

@pytest.fixture
def mock_agent():
    """Create a mock OutlookSecurityAgent for testing"""
    from withOutlookRulesYAML import OutlookSecurityAgent
    
    # Create agent with mocked dependencies
    agent = Mock(spec=OutlookSecurityAgent)
    agent.debug_mode = True
    agent.outlook = None
    agent.namespace = None
    agent.target_folders = []
    
    # Mock common methods
    agent.get_rules.return_value = ({}, [])
    agent.export_rules_to_yaml.return_value = True
    agent.import_rules_yaml.return_value = {}
    
    return agent
