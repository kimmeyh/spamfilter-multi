# Fix unused variables in test files

# database_lifecycle_test.dart:31, 32
$content = Get-Content "test\integration\database_lifecycle_test.dart"
$content = $content -replace "^\s*final safeSenderStore = ", "    // final safeSenderStore = " # Comment out unused
$content = $content -replace "^\s*final testDbPath = ", "    // final testDbPath = " # Comment out unused
$content | Set-Content "test\integration\database_lifecycle_test.dart"

# delete_to_trash_test.dart:130, 148
$content = Get-Content "test\integration\delete_to_trash_test.dart"
$content = $content -replace "^\s*final ImapClient _mockClient;", "  // final ImapClient _mockClient; // Reserved for future use"
$content = $content -replace "^\s*final gmail\.GmailApi _mockApi;", "  // final gmail.GmailApi _mockApi; // Reserved for future use"
$content | Set-Content "test\integration\delete_to_trash_test.dart"

Write-Host "Fixed test unused variables"
