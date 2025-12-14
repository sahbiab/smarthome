# Script to replace .withOpacity() with .withValues() in all Dart files
# This fixes the deprecated API usage warnings

$files = @(
    "lib\auth\login.dart",
    "lib\auth\sign_up.dart",
    "lib\auth\start_page.dart",
    "lib\pages\camera\camera_page.dart",
    "lib\pages\face_recognition\add_person_page.dart",
    "lib\pages\face_recognition\face_data_explorer_page.dart",
    "lib\pages\face_recognition\recognize_person_page.dart",
    "lib\pages\home\home_page.dart",
    "lib\pages\rooms\room_detail_page.dart"
)

$totalReplacements = 0

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot "..\$file"
    
    if (Test-Path $fullPath) {
        Write-Host "Processing: $file" -ForegroundColor Cyan
        
        $content = Get-Content $fullPath -Raw -Encoding UTF8
        $originalContent = $content
        
        # Replace .withOpacity(value) with .withValues(alpha: value)
        # This regex handles various formatting styles
        $content = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'
        
        if ($content -ne $originalContent) {
            $replacements = ([regex]::Matches($originalContent, '\.withOpacity\(')).Count
            $totalReplacements += $replacements
            
            Set-Content $fullPath -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✓ Replaced $replacements instances" -ForegroundColor Green
        } else {
            Write-Host "  - No changes needed" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ File not found: $fullPath" -ForegroundColor Red
    }
}

Write-Host "`nTotal replacements: $totalReplacements" -ForegroundColor Yellow
Write-Host "Done!" -ForegroundColor Green
