# Fix dangling library doc comments by adding "library;" directive

$files = @(
    "lib\core\services\email_availability_checker.dart",
    "lib\core\storage\scan_result_store.dart",
    "lib\core\storage\unmatched_email_store.dart",
    "lib\ui\screens\process_results_screen.dart",
    "test\integration\enhanced_deletion_test.dart",
    "test\integration\folder_selection_test.dart",
    "test\integration\results_display_test.dart",
    "test\integration\scan_provider_state_test.dart",
    "test\integration\scan_result_persistence_test.dart",
    "test\integration\sprint_6_quick_add_workflow_test.dart"
)

foreach ($file in $files) {
    $content = Get-Content $file -Raw
    # Add "library;" after first doc comment block (before first import or code)
    $content = $content -replace "(?m)(^///.*?\n(?:///.*?\n)*)\n(import |class |void |final )", '$1library;$2$2'
    $content | Set-Content $file -NoNewline
}

Write-Host "Fixed dangling library doc comments"
