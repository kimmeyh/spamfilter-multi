# Fix dangling library doc comments by adding "library;" directive

$files = @{
    "lib\core\storage\scan_result_store.dart" = 7
    "lib\core\storage\unmatched_email_store.dart" = 7
    "lib\ui\screens\process_results_screen.dart" = 28
    "test\integration\enhanced_deletion_test.dart" = 8
    "test\integration\folder_selection_test.dart" = 10
    "test\integration\results_display_test.dart" = 10
    "test\integration\scan_provider_state_test.dart" = 10
    "test\integration\scan_result_persistence_test.dart" = 13
    "test\integration\sprint_6_quick_add_workflow_test.dart" = 9
}

foreach ($file in $files.Keys) {
    $lineNum = $files[$file]
    $content = Get-Content $file
    # Insert "library;" at the specified line
    $content = $content[0..($lineNum-2)] + "library;" + "" + $content[($lineNum-1)..($content.Length-1)]
    $content | Set-Content $file
}

Write-Host "Fixed library directives"
