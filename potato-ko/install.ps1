$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$patchRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$gameRoot = [IO.Path]::GetFullPath((Join-Path $patchRoot ".."))
$payloadRoot = [IO.Path]::GetFullPath((Join-Path $patchRoot "files"))
$backupRoot = [IO.Path]::GetFullPath((Join-Path $patchRoot "backup"))
$logPath = Join-Path $patchRoot "install.log"

$files = @(
    @{
        Relative = "PotatoFlowersInFullBloom_Data\StreamingAssets\aa\StandaloneWindows64\texts_translation_sc_assets_all_3cfe53aa2047b1220cb6fc3fc9930a31.bundle"
        PayloadHash = "300fc4df2bdc010966b0e3060a0a2896d9099d09aea6bb679d51eef5069960ed"
        BackupHashes = @(
            "844cb08909e846c65add8eb5ede37b6e5c5897dc79c26df75dd872ddce685c7b",
            "a1dbaf7018b8e3728fd372e7bd0877b52a47aa3930322a8312cfb6dc64a115d5"
        )
        AcceptedHashes = @(
            "844cb08909e846c65add8eb5ede37b6e5c5897dc79c26df75dd872ddce685c7b",
            "a1dbaf7018b8e3728fd372e7bd0877b52a47aa3930322a8312cfb6dc64a115d5",
            "300fc4df2bdc010966b0e3060a0a2896d9099d09aea6bb679d51eef5069960ed"
        )
    },
    @{
        Relative = "PotatoFlowersInFullBloom_Data\StreamingAssets\aa\catalog.json"
        PayloadHash = "2a09a5100c9b5e2a80920dd5a726349aca2e7f7174b14caae3fc976c2fefae6f"
        BackupHashes = @(
            "1df7378ac52160ec746d1dc8ad6b6d09b67fb0ce79b4d87f72853121238477c3",
            "2be7eefa423ec64806cc7e09a8b00b0248e46f83793d63c9af8ce40871885b7a"
        )
        AcceptedHashes = @(
            "1df7378ac52160ec746d1dc8ad6b6d09b67fb0ce79b4d87f72853121238477c3",
            "2be7eefa423ec64806cc7e09a8b00b0248e46f83793d63c9af8ce40871885b7a",
            "2a09a5100c9b5e2a80920dd5a726349aca2e7f7174b14caae3fc976c2fefae6f"
        )
    },
    @{
        Relative = "PotatoFlowersInFullBloom_Data\Managed\Assembly-CSharp.dll"
        PayloadHash = "fb8452f861dab9875230d8d04cfd3c3a9ac91f70a6a0109386c76af2618f07f5"
        BackupHashes = @(
            "da7b6d5f9ce5971e72fd5e4d8ae4bd637c9f70904db4e1553dbc1e3d0d5a36b3"
        )
        AcceptedHashes = @(
            "da7b6d5f9ce5971e72fd5e4d8ae4bd637c9f70904db4e1553dbc1e3d0d5a36b3",
            "fb8452f861dab9875230d8d04cfd3c3a9ac91f70a6a0109386c76af2618f07f5"
        )
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
    Set-Content -LiteralPath $logPath -Value ("{0:u} 설치 시작" -f [DateTime]::UtcNow) -Encoding UTF8
    $gameExe = Join-Path $gameRoot "PotatoFlowersInFullBloom.exe"
    if ((Get-LowerHash $gameExe) -ne "509832ed1156966129a562894b833f10d65645348137db0235474599584a8e4d") {
        throw "지원하는 게임 버전이 아닙니다. 게임 파일 무결성을 확인해 주세요."
    }
    if (Get-Process -Name "PotatoFlowersInFullBloom" -ErrorAction SilentlyContinue) {
        throw "게임을 종료한 뒤 다시 실행해 주세요."
    }

    $alreadyInstalled = $true
    foreach ($item in $files) {
        $payload = Join-Path $payloadRoot $item.Relative
        $target = Join-Path $gameRoot $item.Relative
        $payloadHash = Get-LowerHash $payload
        $targetHash = Get-LowerHash $target
        if ($payloadHash -ne $item.PayloadHash) {
            throw "패치 파일이 손상되었습니다: $($item.Relative)"
        }
        if ($item.AcceptedHashes -notcontains $targetHash) {
            throw "게임 파일 버전이 다르거나 다른 패치로 변경되었습니다: $($item.Relative)"
        }
        if ($targetHash -ne $item.PayloadHash) {
            $alreadyInstalled = $false
        }
    }

    if ($alreadyInstalled) {
        Write-Status "이미 한글 패치가 설치되어 있습니다."
        exit 0
    }

    foreach ($item in $files) {
        $target = Join-Path $gameRoot $item.Relative
        $backup = Join-Path $backupRoot $item.Relative
        if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
            if ((Get-LowerHash $target) -eq $item.PayloadHash) {
                throw "일부 파일만 이미 패치되어 있고 원본 백업이 없습니다. Steam에서 게임 파일 무결성을 확인한 뒤 다시 실행해 주세요: $($item.Relative)"
            }
        }
    }

    foreach ($item in $files) {
        $target = Join-Path $gameRoot $item.Relative
        $backup = Join-Path $backupRoot $item.Relative
        if (Test-Path -LiteralPath $backup -PathType Leaf) {
            if ($item.BackupHashes -notcontains (Get-LowerHash $backup)) {
                throw "기존 백업 파일을 확인할 수 없습니다: $($item.Relative)"
            }
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
            Copy-Item -LiteralPath $target -Destination $backup
            if ((Get-LowerHash $backup) -ne (Get-LowerHash $target)) {
                throw "백업 검증에 실패했습니다: $($item.Relative)"
            }
        }
    }

    $prepared = @()
    try {
        foreach ($item in $files) {
            $payload = Join-Path $payloadRoot $item.Relative
            $target = Join-Path $gameRoot $item.Relative
            $temporary = "$target.potato-ko.tmp"
            if (Test-Path -LiteralPath $temporary) {
                Remove-Item -LiteralPath $temporary -Force
            }
            Copy-Item -LiteralPath $payload -Destination $temporary
            if ((Get-LowerHash $temporary) -ne $item.PayloadHash) {
                throw "임시 파일 검증에 실패했습니다: $($item.Relative)"
            }
            $prepared += @{ Item = $item; Target = $target; Temporary = $temporary }
        }
        foreach ($entry in $prepared) {
            Move-Item -LiteralPath $entry.Temporary -Destination $entry.Target -Force
        }
        foreach ($item in $files) {
            if ((Get-LowerHash (Join-Path $gameRoot $item.Relative)) -ne $item.PayloadHash) {
                throw "설치 후 검증에 실패했습니다: $($item.Relative)"
            }
        }
    } catch {
        foreach ($item in $files) {
            $backup = Join-Path $backupRoot $item.Relative
            $target = Join-Path $gameRoot $item.Relative
            if (Test-Path -LiteralPath $backup -PathType Leaf) {
                Copy-Item -LiteralPath $backup -Destination $target -Force
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

    Write-Status "설치 완료. 게임의 언어 선택에서 '한국어'를 선택하세요."
    exit 0
} catch {
    Write-Status ("오류: " + $_.Exception.Message)
    exit 1
}
