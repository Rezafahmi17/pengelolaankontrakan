# ============================================================
#  JEKPOL - Script Jalankan Server & Info IP untuk Uji Coba HP
#  Jalankan di PowerShell:  .\jalankan_server.ps1
# ============================================================

Write-Host "============================================================" -ForegroundColor Green
Write-Host "     JEKPOL - POLINELA (SERVER & UJI COBA HP FISIK)         " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

# 1. Deteksi IP Wi-Fi Laptop (.NET DNS)
$wifiIp = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | 
    Where-Object { 
        $_.AddressFamily -eq 'InterNetwork' -and 
        $_.IPAddressToString -notlike '127.*' -and 
        $_.IPAddressToString -notlike '169.254*' -and 
        $_.IPAddressToString -notlike '192.168.56.*' 
    } | Select-Object -ExpandProperty IPAddressToString -First 1

if (-not $wifiIp) { $wifiIp = "192.168.18.11" }

Write-Host "[1] IP Wi-Fi Laptop Anda : " -NoNewline
Write-Host "$wifiIp" -ForegroundColor Yellow

# 2. Periksa Status Apache & MySQL
$apache = Get-Process httpd -ErrorAction SilentlyContinue
$mysql  = Get-Process mysqld -ErrorAction SilentlyContinue

if (-not $apache) {
    Write-Host "[2] Menjalankan Apache (XAMPP)..." -ForegroundColor Cyan
    Start-Process -FilePath "C:\xampp\apache\bin\httpd.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
} else {
    Write-Host "[2] Apache sudah aktif." -ForegroundColor Green
}

if (-not $mysql) {
    Write-Host "[3] Menjalankan MySQL (XAMPP)..." -ForegroundColor Cyan
    Start-Process -FilePath "C:\xampp\mysql\bin\mysqld.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $mysqlCheck = Get-Process mysqld -ErrorAction SilentlyContinue
    if (-not $mysqlCheck) {
        Write-Host "    -> Memperbaiki otomatis log Aria MySQL yang crash..." -ForegroundColor Yellow
        Remove-Item "C:\xampp\mysql\data\aria_log*" -Force -ErrorAction SilentlyContinue
        & "C:\xampp\mysql\bin\aria_chk.exe" -o "C:\xampp\mysql\data\mysql\*.MAI" *> $null
        Remove-Item "C:\xampp\mysql\data\aria_log*" -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath "C:\xampp\mysql\bin\mysqld.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
} else {
    Write-Host "[3] MySQL sudah aktif." -ForegroundColor Green
}

# 3. Sinkronisasi otomatis file API terbaru ke C:\xampp\htdocs\gojek_polinela\api
$targetApi = "C:\xampp\htdocs\gojek_polinela\api"
if (Test-Path "backend\api") {
    New-Item -ItemType Directory -Force -Path "$targetApi\lib", "$targetApi\handlers" | Out-Null
    Copy-Item -Path "backend\api\index.php", "backend\api\config.php" -Destination "$targetApi\" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "backend\api\lib\*.php" -Destination "$targetApi\lib\" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "backend\api\handlers\*.php" -Destination "$targetApi\handlers\" -Force -ErrorAction SilentlyContinue
    Write-Host "[4] File Backend API telah disinkronkan ke XAMPP." -ForegroundColor Green
}

# 4. URL API Backend
$apiUrl = "http://$wifiIp/gojek_polinela/api/index.php"
Write-Host ""
Write-Host "Alamat API Backend untuk HP : " -NoNewline
Write-Host "$apiUrl" -ForegroundColor Cyan

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " CARA UJI COBA DI BANYAK HP (ANDROID & iOS):" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "1. Pastikan Laptop dan seluruh HP terhubung ke Wi-Fi yang SAMA." -ForegroundColor White
Write-Host "2. Untuk HP ANDROID:" -ForegroundColor White
Write-Host "   - Buat file APK dengan perintah:" -ForegroundColor Gray
Write-Host "       flutter build apk --release" -ForegroundColor Cyan
Write-Host "   - File APK tersimpan di:" -ForegroundColor Gray
Write-Host "       build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
Write-Host "   - Kirim file APK tersebut ke WhatsApp / Google Drive HP penguji." -ForegroundColor Gray
Write-Host "   - Buka dan Install file APK di HP." -ForegroundColor Gray
Write-Host ""
Write-Host "3. Untuk HP iOS (iPhone):" -ForegroundColor White
Write-Host "   - Di terminal laptop, jalankan Flutter Web:" -ForegroundColor Gray
Write-Host "       flutter run -d web-server --web-port=8888 --web-hostname=0.0.0.0" -ForegroundColor Cyan
Write-Host "   - Buka browser Safari di iPhone, lalu ketik:" -ForegroundColor Gray
Write-Host "       http://${wifiIp}:8888" -ForegroundColor Green
Write-Host ""
Write-Host "4. Jika ganti Wi-Fi dan IP laptop berubah:" -ForegroundColor White
Write-Host "   - Di layar Login JEKPOL pada HP, TEKAN LAMA (Long Press) Logo JEKPOL." -ForegroundColor Yellow
Write-Host "   - Masukkan IP baru laptop Anda, lalu klik Simpan." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green
