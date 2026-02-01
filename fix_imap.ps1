$content = Get-Content 'mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart' -Raw

$old1 = "    final messages = <EmailMessage>[];
    final sinceDate = DateTime.now().subtract(Duration(days: daysBack));

    _logger.i('Fetching messages from `$daysBack days back in folders: `$folderNames');"

$new1 = "    final messages = <EmailMessage>[];
    final sinceDate = daysBack > 0
        ? DateTime.now().subtract(Duration(days: daysBack))
        : null; // null = no date filter (scan all)

    _logger.i('Fetching messages from `${daysBack > 0 ? \"`$daysBack days back\" : \"all time\"} in folders: `$folderNames');"

$content = $content.Replace($old1, $new1)

$old2 = "        // Use IMAP SEARCH command with date filter
        final searchCriteria = 'SINCE `${_formatImapDate(sinceDate)}';"

$new2 = "        // Use IMAP SEARCH command with date filter (or ALL if no filter)
        final searchCriteria = sinceDate != null
            ? 'SINCE `${_formatImapDate(sinceDate)}'
            : 'ALL'; // Scan all emails"

$content = $content.Replace($old2, $new2)

Set-Content 'mobile-app/lib/adapters/email_providers/generic_imap_adapter.dart' -Value $content -NoNewline

Write-Host "Fixed IMAP adapter"
