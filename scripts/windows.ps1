param(
    [ValidateSet("setup", "server", "test", "client", "build-windows", "build-android")]
    [string]$Action = "client",
    [string]$Godot = "godot"
)
$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
Set-Location (Split-Path $PSScriptRoot -Parent)
function Run([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed: $LASTEXITCODE" }
}
$Python = Join-Path (Get-Location) ".venv\Scripts\python.exe"
$env:XDG_CACHE_HOME = Join-Path (Get-Location) ".local\cache"
$env:DATABASE_URL = "postgresql+psycopg://postgres@127.0.0.1:55432/spin_kingdom"
switch ($Action) {
    "setup" {
        Run "py" @("-3.12", "-m", "venv", ".venv")
        if (Test-Path "windows-wheels") {
            Run $Python @("-m", "pip", "install", "--no-index", "--find-links", "windows-wheels", "-r", "backend/requirements.lock")
        } else {
            Run $Python @("-m", "pip", "install", "-r", "backend/requirements.lock")
        }
    }
    "server" {
        $Exists = docker ps -a --filter "name=^/spin-kingdom-db$" --format "{{.Names}}"
        if ($LASTEXITCODE -ne 0) { throw "Start Docker Desktop with Linux containers." }
        if ($Exists) { Run "docker" @("start", "spin-kingdom-db") }
        else {
            Run "docker" @("run", "-d", "--name", "spin-kingdom-db", "--restart", "unless-stopped",
                "-p", "127.0.0.1:55432:5432", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
                "-e", "POSTGRES_DB=spin_kingdom", "-v", "spin-kingdom-data:/var/lib/postgresql/data",
                "postgres:17-bookworm@sha256:3645570cccdfa447589da9f57dd740faa29b30938e861289a5574b6ca6b03826")
        }
        $Ready = $false
        for ($Attempt = 0; $Attempt -lt 30; $Attempt++) {
            docker exec spin-kingdom-db pg_isready -U postgres | Out-Null
            if ($LASTEXITCODE -eq 0) { $Ready = $true; break }
            Start-Sleep -Seconds 1
        }
        if (-not $Ready) { throw "PostgreSQL did not become ready." }
        Set-Location backend
        Run $Python @("-m", "app.migrate")
        Run $Python @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000")
    }
    "test" {
        $Exists = docker exec spin-kingdom-db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='spin_kingdom_test'"
        if ($LASTEXITCODE -ne 0) { throw "Start the server/database first." }
        if (([string]$Exists).Trim() -ne "1") { Run "docker" @("exec", "spin-kingdom-db", "createdb", "-U", "postgres", "spin_kingdom_test") }
        Run $Python @("-m", "ruff", "check", "backend", "scripts")
        Run $Python @("-m", "ruff", "format", "--check", "backend", "scripts")
        Run $Python @("scripts/gdtool.py", "format", "--check", "client/scripts", "client/tests")
        Run $Python @("scripts/gdtool.py", "lint", "client/scripts", "client/tests")
        Set-Location backend
        Run $Python @("-m", "pytest", "-q")
    }
    "client" { Run $Godot @("--path", "client") }
    "build-windows" {
        New-Item -ItemType Directory -Force build | Out-Null
        Run $Godot @("--headless", "--path", "client", "--export-debug", "Windows Debug", "../build/spin-kingdom.exe")
    }
    "build-android" {
        New-Item -ItemType Directory -Force build | Out-Null
        Run $Godot @("--headless", "--path", "client", "--export-debug", "Android Debug", "../build/spin-kingdom-debug.apk")
    }
}
