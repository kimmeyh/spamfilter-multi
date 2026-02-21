import pytest

from withOutlookRulesYAML import OutlookSecurityAgent


@pytest.fixture
def agent():
    # Instantiate in test_mode to avoid Outlook dependency
    return OutlookSecurityAgent(test_mode=True)


@pytest.mark.parametrize(
    "input_value, expected_anchor",
    [
        ("@a.b.c.ygllc.d.e.f", "ygllc"),
        ("user@x.y.z.acme.q.r", "acme"),
        ("sub.sub2.widgets.com", "widgets"),
        ("widgets.com", "widgets"),
    ],
)
def test_build_domain_regex_from_address(agent, input_value, expected_anchor):
    regex = agent.build_domain_regex_from_address(input_value)
    assert regex.startswith("@(?:[a-z0-9-]+\\.)*")
    assert f"{expected_anchor}\\.[a-z0-9.-]+$" in regex
