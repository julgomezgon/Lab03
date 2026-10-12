# =============================================================================
# run_sim.ps1 - Compila y ejecuta todos los testbenches del Lab03
# Uso (desde Lab03/):  powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
# Los archivos .vcd quedan en sim/ para abrirlos con GTKWave.
# =============================================================================
$ErrorActionPreference = 'Continue'
Push-Location $PSScriptRoot

$src = @(
    '..\src\reg_bank.v',
    '..\src\comb_selector.v',
    '..\src\alu.v',
    '..\src\display_tm1637.v',
    '..\src\top.v'
)
$tbs = @('tb_alu', 'tb_reg_bank', 'tb_comb_selector', 'tb_display_tm1637', 'tb_top')
$failed = @()

try {
    foreach ($tb in $tbs) {
        Write-Host "`n==================== $tb ====================" -ForegroundColor Cyan
        & iverilog -g2012 -Wall -s $tb -o "$tb.vvp" @src "$tb.v"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error de compilacion en $tb" -ForegroundColor Red
            $failed += $tb
            continue
        }
        $out = & vvp -n "$tb.vvp" 2>&1
        $out | Where-Object { $_ -match 'FAIL|RESULTADO' } | ForEach-Object { Write-Host $_ }
        $summary = $out | Where-Object { $_ -match 'RESULTADO' } | Select-Object -Last 1
        if (-not $summary -or $summary -notmatch ' 0 errores' -or ($out -match '\[FAIL\]')) {
            $failed += $tb
        }
        Remove-Item "$tb.vvp" -ErrorAction SilentlyContinue
    }
}
finally {
    Pop-Location
}

Write-Host ''
if ($failed.Count -eq 0) {
    Write-Host 'TODOS LOS TESTBENCHES PASARON' -ForegroundColor Green
    exit 0
} else {
    Write-Host ("FALLARON: " + ($failed -join ', ')) -ForegroundColor Red
    exit 1
}
