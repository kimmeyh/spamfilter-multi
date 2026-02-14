# Fix unused imports in test files

# test\adapters\email_providers\gmail_api_adapter_test.dart:4
(Get-Content "test\adapters\email_providers\gmail_api_adapter_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/email_message\.dart';$", "" | Set-Content "test\adapters\email_providers\gmail_api_adapter_test.dart"

# test\integration\credential_verification_test.dart:8
(Get-Content "test\integration\credential_verification_test.dart") -replace "^import 'package:spam_filter_mobile/adapters/email_providers/spam_filter_platform\.dart';$", "" | Set-Content "test\integration\credential_verification_test.dart"

# test\integration\email_scanner_readonly_mode_test.dart:3
(Get-Content "test\integration\email_scanner_readonly_mode_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/rule_set\.dart';$", "" | Set-Content "test\integration\email_scanner_readonly_mode_test.dart"

# test\integration\imap_adapter_test.dart:4
(Get-Content "test\integration\imap_adapter_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/email_message\.dart';$", "" | Set-Content "test\integration\imap_adapter_test.dart"

# test\integration\sprint_6_quick_add_workflow_test.dart:9 and :16
(Get-Content "test\integration\sprint_6_quick_add_workflow_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/safe_sender_list\.dart';$", "" | Set-Content "test\integration\sprint_6_quick_add_workflow_test.dart"
(Get-Content "test\integration\sprint_6_quick_add_workflow_test.dart") -replace "^import 'package:sqflite/sqflite\.dart';$", "" | Set-Content "test\integration\sprint_6_quick_add_workflow_test.dart"

# test\integration\yaml_loading_test.dart:5 and :6
(Get-Content "test\integration\yaml_loading_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/rule_set\.dart';$", "" | Set-Content "test\integration\yaml_loading_test.dart"
(Get-Content "test\integration\yaml_loading_test.dart") -replace "^import 'package:spam_filter_mobile/core/models/safe_sender_list\.dart';$", "" | Set-Content "test\integration\yaml_loading_test.dart"

Write-Host "Fixed unused imports in test files"
