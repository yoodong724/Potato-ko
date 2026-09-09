$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$patchRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$gameRoot = [IO.Path]::GetFullPath((Join-Path $patchRoot ".."))
$backupRoot = [IO.Path]::GetFullPath((Join-Path $patchRoot "backup"))
$logPath = Join-Path $patchRoot "uninstall.log"

$files = @(
    @{
        Relative = "PotatoFlowersInFullBloom_Data\StreamingAssets\aa\StandaloneWindows64\texts_translation_sc_assets_all_3cfe53aa2047b1220cb6fc3fc9930a31.bundle"
        PatchedHash = "300fc4df2bdc010966b0e3060a0a2896d9099d09aea6bb679d51eef5069960ed"
        BackupHashes = @("844cb08909e846c65add8eb5ede37b6e5c5897dc79c26df75dd872ddce685c7b", "a1dbaf7018b8e3728fd372e7bd0877b52a47aa3930322a8312cfb6dc64a115d5")
    },
    @{
        Relative = "PotatoFlowersInFullBloom_Data\StreamingAssets\aa\catalog.json"
        PatchedHash = "2a09a5100c9b5e2a80920dd5a726349aca2e7f7174b14caae3fc976c2fefae6f"
        BackupHashes = @("1df7378ac52160ec746d1dc8ad6b6d09b67fb0ce79b4d87f72853121238477c3", "2be7eefa423ec64806cc7e09a8b00b0248e46f83793d63c9af8ce40871885b7a")
    },
    @{
        Relative = "PotatoFlowersInFullBloom_Data\Managed\Assembly-CSharp.dll"
        PatchedHash = "fb8452f861dab9875230d8d04cfd3c3a9ac91f70a6a0109386c76af2618f07f5"
        BackupHashes = @("da7b6d5f9ce5971e72fd5e4d8ae4bd637c9f70904db4e1553dbc1e3d0d5a36b3")
    }
)

function Get-LowerHash([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "필수 파일이 없습니다: $path"
    }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Status([string]$message) {
    Write-Host $message
    Add-Content -LiteralPath $logPath -Value ("{0:u} {1}" -f [DateTime]::UtcNow, $message) -Encoding UTF8
}

try {
    Set-Content -LiteralPath $logPath -Value ("{0:u} 복원 시작" -f [DateTime]::UtcNow) -Encoding UTF8
    if (Get-Process -Name "PotatoFlowersInFullBloom" -ErrorAction SilentlyContinue) {
        throw "게임을 종료한 뒤 다시 실행해 주세요."
    }

    $alreadyRestored = $true
    foreach ($item in $files) {
        $backup = Join-Path $backupRoot $item.Relative
        $target = Join-Path $gameRoot $item.Relative
        $backupHash = Get-LowerHash $backup
        $targetHash = Get-LowerHash $target
        if ($item.BackupHashes -notcontains $backupHash) {
            throw "백업 파일 버전이 올바르지 않습니다: $($item.Relative)"
        }
        if ($targetHash -ne $backupHash) {
            $alreadyRestored = $false
            if ($targetHash -ne $item.PatchedHash) {
                throw "설치 후 게임 파일이 다시 변경되어 자동 복원을 중단했습니다: $($item.Relative)"
            }
        }
    }

    if ($alreadyRestored) {
        Write-Status "이미 설치 전 상태로 복원되어 있습니다."
        exit 0
    }

    $prepared = @()
    try {
        foreach ($item in $files) {
            $backup = Join-Path $backupRoot $item.Relative
            $target = Join-Path $gameRoot $item.Relative
            $temporary = "$target.potato-ko.restore.tmp"
            if (Test-Path -LiteralPath $temporary) {
                Remove-Item -LiteralPath $temporary -Force
            }
            Copy-Item -LiteralPath $backup -Destination $temporary
            if ((Get-LowerHash $temporary) -ne (Get-LowerHash $backup)) {
                throw "복원용 임시 파일 검증에 실패했습니다: $($item.Relative)"
            }
            $prepared += @{
                Item = $item
                Target = $target
                Temporary = $temporary
                OriginalHash = Get-LowerHash $target
            }
        }
        foreach ($entry in $prepared) {
            Move-Item -LiteralPath $entry.Temporary -Destination $entry.Target -Force
        }
        foreach ($item in $files) {
            $backup = Join-Path $backupRoot $item.Relative
            $target = Join-Path $gameRoot $item.Relative
            if ((Get-LowerHash $target) -ne (Get-LowerHash $backup)) {
                throw "복원 후 검증에 실패했습니다: $($item.Relative)"
            }
        }
    } catch {
        foreach ($entry in $prepared) {
            $backup = Join-Path $backupRoot $entry.Item.Relative
            $payload = Join-Path (Join-Path $patchRoot "files") $entry.Item.Relative
            if ($entry.OriginalHash -eq $entry.Item.PatchedHash) {
                Copy-Item -LiteralPath $payload -Destination $entry.Target -Force
            } else {
                Copy-Item -LiteralPath $backup -Destination $entry.Target -Force
            }
        }
        throw
    } finally {
        foreach ($entry in $prepared) {
            if (Test-Path -LiteralPath $entry.Temporary) {
                Remove-Item -LiteralPath $entry.Temporary -Force
            }
        }
    }

    Write-Status "복원 완료. 백업은 potato-ko\backup에 남겨 두었습니다."
    exit 0
} catch {
    Write-Status ("오류: " + $_.Exception.Message)
    exit 1
}
