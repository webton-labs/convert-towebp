param (
    [string]$Path = ".",          # Папка для обработки (по умолчанию текущая)
    [int]$Quality = 90,           # Качество от 0 до 100
    [switch]$DeleteOriginal,      # Удалить оригинал после конвертации (ОПАСНО)
    [string]$CwebpPath = "cwebp"  # Путь к утилите, если она не в PATH
)

# Проверка существования утилиты
if (-not (Get-Command $CwebpPath -ErrorAction SilentlyContinue)) {
    Write-Error "Утилита '$CwebpPath' не найдена. Убедитесь, что libwebp установлен и добавлен в PATH."
    exit 1
}

# Получаем абсолютный путь
$RootPath = (Resolve-Path $Path).Path
Write-Host "Начинаем конвертацию в папке: $RootPath" -ForegroundColor Cyan
Write-Host "Качество: $Quality" -ForegroundColor Cyan
Write-Host "----------------------------------------"

# Расширения файлов для конвертации
$Extensions = @("*.png", "*.jpg", "*.jpeg", "*.bmp", "*.tiff", "*.tif")

# Получаем все файлы рекурсивно, исключая уже существующие .webp
$Files = Get-ChildItem -Path $RootPath -Include $Extensions -Recurse -File

$total = $Files.Count
$current = 0
$successCount = 0
$failCount = 0

if ($total -eq 0) {
    Write-Host "Файлы для конвертации не найдены." -ForegroundColor Yellow
    exit 0
}

foreach ($File in $Files) {
    $current++
    
    # Формируем имя выходного файла (заменяем расширение на .webp)
    $OutputPath = [System.IO.Path]::ChangeExtension($File.FullName, ".webp")
    
    # Пропускаем, если файл уже является webp (защита от зацикливания)
    if ($File.Extension -eq ".webp") { continue }

    # Прогресс-бар
    $percent = [math]::Round(($current / $total) * 100, 2)
    Write-Progress -Activity "Конвертация изображений" `
                   -Status "Обработка: $($File.Name)" `
                   -PercentComplete $percent `
                   -CurrentOperation "$current из $total"

    # Аргументы для cwebp
    $Arguments = "-q $Quality `"$($File.FullName)`" -o `"$OutputPath`""
    
    # Запуск процесса
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $CwebpPath
    $ProcessInfo.Arguments = $Arguments
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    $Process.Start() | Out-Null
    $Process.WaitForExit()

    if ($Process.ExitCode -eq 0) {
        Write-Host "[OK] $($File.Name)" -ForegroundColor Green
        $successCount++
        
        # Удаление оригинала (если указан флаг)
        if ($DeleteOriginal) {
            try {
                Remove-Item -Path $File.FullName -Force
                Write-Host "     -> Оригинал удален" -ForegroundColor DarkGray
            } catch {
                Write-Warning "Не удалось удалить оригинал: $($File.Name)"
            }
        }
    } else {
        Write-Host "[FAIL] $($File.Name) (Код ошибки: $($Process.ExitCode))" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "----------------------------------------"
Write-Host "Готово!" -ForegroundColor Cyan
Write-Host "Успешно: $successCount" -ForegroundColor Green
Write-Host "Ошибки: $failCount" -ForegroundColor Red