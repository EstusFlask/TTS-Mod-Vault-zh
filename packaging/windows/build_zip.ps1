[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$appSlug = 'TTS-Mod-Vault-zh'
$arch = 'x64'

$repoRoot = git -C $PSScriptRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    throw 'Could not resolve the repository root.'
}

Push-Location $repoRoot
try {
    $versionMatch = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1
    if (-not $versionMatch) {
        throw 'Could not read the version from pubspec.yaml.'
    }
    $version = $versionMatch.Matches[0].Groups[1].Value

    $fvm = Get-Command 'fvm' -ErrorAction SilentlyContinue
    $flutter = Get-Command 'flutter' -ErrorAction SilentlyContinue
    if ($fvm) {
        & $fvm.Source flutter build windows --release
    }
    elseif ($flutter) {
        & $flutter.Source build windows --release
    }
    else {
        throw 'Neither fvm nor flutter is available on PATH.'
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows build failed with exit code $LASTEXITCODE."
    }

    $bundle = Join-Path $repoRoot 'build\windows\x64\runner\Release'
    $requiredPaths = @(
        'tts_mod_vault.exe',
        'flutter_windows.dll',
        'pdfium.dll',
        'data\app.so',
        'data\flutter_assets'
    )
    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $bundle $relativePath))) {
            throw "Required Windows bundle item is missing: $relativePath"
        }
    }

    $distName = "$appSlug-$version-windows-$arch"
    $distRoot = Join-Path $repoRoot 'build\distributions'
    $stage = Join-Path $distRoot $distName
    $outZip = Join-Path $distRoot "$distName.zip"
    New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

    if (Test-Path -LiteralPath $stage) {
        $resolvedDist = [IO.Path]::GetFullPath($distRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolvedStage = [IO.Path]::GetFullPath($stage)
        if (-not $resolvedStage.StartsWith($resolvedDist, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove an unexpected staging path: $resolvedStage"
        }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -Path (Join-Path $bundle '*') -Destination $stage -Recurse -Force
    Copy-Item -LiteralPath 'LICENSE' -Destination (Join-Path $stage 'LICENSE')

    if (Test-Path -LiteralPath $outZip) {
        Remove-Item -LiteralPath $outZip -Force
    }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $outZip -CompressionLevel Optimal

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($outZip)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        foreach ($requiredEntry in @('tts_mod_vault.exe', 'flutter_windows.dll', 'pdfium.dll', 'data/app.so')) {
            if ($requiredEntry -notin $entryNames) {
                throw "Required entry is missing from the ZIP: $requiredEntry"
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    Write-Host "==> done: $outZip"
}
finally {
    Pop-Location
}

