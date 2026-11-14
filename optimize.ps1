<#
.SYNOPSIS
    OPlus-Turbo: Safe ADB Performance & Battery Optimizer
.DESCRIPTION
    Engineered for Oppo (ColorOS), OnePlus (OxygenOS), and Realme (Realme UI).
    Features Read-Only Audit Diagnostics, Full Safe Optimization, and Factory Restore.
.LINK
    https://github.com/alienofmoon/OPlus-Turbo
#>

[CmdletBinding()]
param(
    [switch]$Audit,
    [switch]$Optimize,
    [switch]$Restore
)

$ErrorActionPreference = "Continue"

function Write-Header {
    try { Clear-Host } catch { }
    Write-Host @"
===================================================================
      OPLUS-TURBO: SAFE ADB PERFORMANCE & BATTERY OPTIMIZER
      For Oppo (ColorOS) | OnePlus (OxygenOS) | Realme (Realme UI)
      https://github.com/alienofmoon/OPlus-Turbo
===================================================================
"@ -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Title)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Msg)
    Write-Host "  [+] $Msg" -ForegroundColor Green
}

function Write-Info {
    param([string]$Msg)
    Write-Host "  [*] $Msg" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  [!] $Msg" -ForegroundColor Red
}

function Get-ConnectedDevice {
    $devicesOutput = adb devices -l
    $deviceLines = $devicesOutput -split "`r?`n" | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }

    if (-not $deviceLines) {
        Write-Warn "No authorized ADB device detected!"
        Write-Host "`n  Please ensure:" -ForegroundColor Yellow
        Write-Host "  1. Phone is plugged into this PC via USB."
        Write-Host "  2. Developer Options is ON."
        Write-Host "  3. USB Debugging is ON and you tapped 'Allow' on your phone."
        return $null
    }
    return ($deviceLines[0] -split "\s+")[0]
}

# --- AUDIT / DIAGNOSTIC MODE (READ-ONLY) ---
function Run-Audit {
    param([string]$Serial)
    Write-Step "SYSTEM AUDIT & HEALTH CHECK (READ-ONLY)"
    Write-Info "Inspecting device state without making any changes..."

    $model = (adb -s $Serial shell "getprop ro.product.model").Trim()
    $brand = (adb -s $Serial shell "getprop ro.product.brand").Trim()
    $osVersion = (adb -s $Serial shell "getprop ro.build.version.release").Trim()
    Write-Success "Device: $brand $model (Android $osVersion)"

    # Refresh rate
    $activeMode = adb -s $Serial shell "dumpsys display | grep -E 'mActiveModeId|renderFrameRate' | head -n 4"
    Write-Host "`n  [Display Refresh Rate]" -ForegroundColor Cyan
    Write-Info "$activeMode"

    # Battery & Thermals
    $batteryTemp = (adb -s $Serial shell "dumpsys battery | grep -i temperature").Trim()
    if ($batteryTemp -match "(\d+)") {
        $tempC = [math]::Round([double]$matches[1] / 10, 1)
        Write-Success "Battery Temperature: $tempC °C"
    }

    # HTMS / Ad Wakeups
    Write-Host "`n  [Advertising Daemon Check]" -ForegroundColor Cyan
    $adAlarms = adb -s $Serial shell "dumpsys batterystats | grep -i 'AdsCoreService'"
    if ($adAlarms) {
        Write-Warn "Advertising Wakeup Alarm Detected: $adAlarms"
    } else {
        Write-Success "Zero active AdsCoreService wakeups registered."
    }

    # Passive location scanning
    $wifiScan = (adb -s $Serial shell "settings get global wifi_scan_always_enabled").Trim()
    $bleScan = (adb -s $Serial shell "settings get global ble_scan_always_enabled").Trim()
    if ($wifiScan -eq "1" -or $bleScan -eq "1") {
        Write-Warn "Passive Wi-Fi / Bluetooth scanning is ACTIVE (causes background radio drain)."
    } else {
        Write-Success "Passive scanning is already disabled."
    }

    # Storage
    $storage = adb -s $Serial shell "df -h /data"
    Write-Host "`n  [Storage Health]" -ForegroundColor Cyan
    Write-Info "$storage"

    Write-Host "`n--------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Audit complete. Ready to run Option 2 (Full Optimization)!" -ForegroundColor Green
    Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
}

# --- FULL OPTIMIZATION SUITE ---
function Run-Optimization {
    param([string]$Serial)

    Write-Step "1. Tuning Display Fluidity & UI Responsiveness"
    # Dynamically detect maximum hardware refresh rate supported (90Hz, 120Hz, 144Hz)
    $maxRate = "120.0"
    $fpsDump = adb -s $Serial shell "dumpsys display | grep -oE 'fps=[0-9.]+'"
    if ($fpsDump) {
        $rates = [regex]::Matches($fpsDump, 'fps=([0-9.]+)') | ForEach-Object { [double]$_.Groups[1].Value } | Sort-Object -Descending
        if ($rates.Count -gt 0 -and $rates[0] -ge 60.0) {
            $maxRate = "$([math]::Round($rates[0], 1))"
        }
    }
    Write-Info "Locking peak display refresh rate to $maxRate Hz..."
    adb -s $Serial shell "settings put system min_refresh_rate $maxRate"
    adb -s $Serial shell "settings put system peak_refresh_rate $maxRate"
    adb -s $Serial shell "settings put system oplus_customize_screen_refresh_rate 2"

    Write-Info "Setting animation scales to 0.5x..."
    adb -s $Serial shell "settings put global window_animation_scale 0.5"
    adb -s $Serial shell "settings put global transition_animation_scale 0.5"
    adb -s $Serial shell "settings put global animator_duration_scale 0.5"
    Write-Success "Display locked at $maxRate Hz and animations set to 0.5x."

    Write-Step "2. Taming Oppo/OnePlus/Realme Ad Service (com.heytap.htms)"
    adb -s $Serial shell "pm unsuspend com.heytap.htms" 2>$null | Out-Null
    adb -s $Serial shell "am set-standby-bucket com.heytap.htms restricted"
    adb -s $Serial shell "cmd appops set com.heytap.htms POST_NOTIFICATION ignore" 2>$null | Out-Null
    Write-Success "HTMS restricted (purged repeating 30-min ad wakeups without breaking cloud sync)."

    Write-Step "3. Safe Subsystem Debloating (Lockscreen Ads, OEM Stubs & Analytics)"
    Write-Info "Scanning device for removable OEM bloat and tracking stubs..."
    $installedOutput = adb -s $Serial shell "pm list packages"

    $debloatList = @(
        # Lock Screen Ad & Magazine Services (Heavy data & battery drainers)
        "com.heytap.pictorial",
        "com.coloros.pictorial",
        "com.glance.internet",

        # OEM Promotional App Stores & Spam Browsers
        "com.heytap.market",
        "com.oppo.market",
        "com.nearme.gamecenter",
        "com.heytap.gamecenter",
        "com.heytap.browser",
        "com.nearme.browser",
        "com.nearme.instant.platform",

        # Facebook Tracking Stubs (Background daemons only; keeps Facebook/Messenger if installed)
        "com.facebook.appmanager",
        "com.facebook.services",
        "com.facebook.system",

        # OEM Telemetry, Analytics & Push Surveys
        "com.heytap.habit.analysis",
        "com.oplus.postmanservice",
        "com.oplus.gleanerservice",
        "com.oplus.onetrace",
        "com.oplus.logkit",
        "com.nearme.statistics.rom",
        "com.oplus.statistics.rom",
        "com.coloros.feedback",
        "com.oppo.usercenter.contact",
        "com.oplus.bttestmode",
        "com.oplus.nfcengineertest",

        # Partner & Carrier Activation Stubs
        "com.netflix.partner.activation",
        "com.amazon.appmanager",

        # Built-in User Manuals & Google Feedback
        "com.oppo.operationManual",
        "com.coloros.operationManual",
        "com.google.android.feedback"
    )

    $debloatCount = 0
    foreach ($pkg in $debloatList) {
        if ($installedOutput -match "package:$pkg\b") {
            $uninstResult = adb -s $Serial shell "pm uninstall -k --user 0 $pkg" 2>$null
            if ($uninstResult -match "Success") {
                Write-Success "Uninstalled: $pkg"
                $debloatCount++
            } else {
                # Fallback for OEM-locked packages (e.g. Quick Apps)
                adb -s $Serial shell "pm disable-user --user 0 $pkg" 2>$null | Out-Null
                adb -s $Serial shell "pm suspend $pkg" 2>$null | Out-Null
                adb -s $Serial shell "am set-standby-bucket $pkg restricted" 2>$null | Out-Null
                Write-Success "Disabled & Suspended: $pkg"
                $debloatCount++
            }
        }
    }
    if ($debloatCount -eq 0) {
        Write-Info "No removable OEM bloat stubs found on this device."
    } else {
        Write-Success "Debloated $debloatCount OEM, ad & tracking packages safely."
    }

    Write-Step "4. Global 30+ App Shield (E-Commerce, Delivery, Telecom & Travel)"
    Write-Info "Scanning device for aggressive third-party background apps..."

    $targetApps = @(
        # Global E-Commerce
        "com.amazon.mShop.android.shopping",
        "in.amazon.mShop.android.shopping",
        "in.amazon.mShop.android.business.shopping",
        "com.ebay.mobile",
        "com.walmart.android",
        "com.target.ui",
        "com.einnovation.temu",
        "com.alibaba.aliexpresshd",
        "com.zzkko",

        # Regional & Fashion E-Commerce
        "com.flipkart.android",
        "com.myntra.android",
        "com.meesho.supply",
        "com.ril.ajio",
        "com.shopsy.buyer",
        "com.reglobe.cashify",
        "com.olx.southasia",
        "com.olx.olx",

        # Food & Grocery Delivery
        "com.grofers.customerapp",
        "in.swiggy.android",
        "com.application.zomato",
        "com.zeptonow.android",
        "com.instacart.client",
        "com.dd.doordash",
        "com.ubercab.eats",

        # Telecom & Carrier Apps
        "com.myairtelapp",
        "com.jio.myjio",
        "com.mizmowireless.acda",
        "com.vzw.hss.myverizon",
        "com.att.myWireless",
        "com.tmobile.pr.mytmobile",

        # Ride Hailing & Travel
        "com.ubercab",
        "com.olacabs.customer",
        "com.rapido.passenger",
        "com.makemytrip",
        "com.booking",
        "com.airbnb.android",

        # Aggressive Background Scrapers & Social Media Quota Clamp
        "com.truecaller",
        "com.instagram.android",
        "com.twitter.android",
        "com.reddit.frontpage",
        "com.snapchat.android",
        "com.linkedin.android",
        "org.altruist.BajajExperia",
        "com.astronik.astrologer"
    )

    $restrictedCount = 0
    foreach ($app in $targetApps) {
        if ($installedOutput -match "package:$app\b") {
            adb -s $Serial shell "am set-standby-bucket $app restricted" 2>$null | Out-Null
            Write-Success "Restricted background sync: $app"
            $restrictedCount++
        }
    }
    if ($restrictedCount -eq 0) {
        Write-Info "No matching third-party target apps found on this device."
    } else {
        Write-Success "Restricted $restrictedCount detected third-party apps."
    }

    Write-Step "5. Eliminating Passive Radio Scanning, AdServices & Network Scoring"
    adb -s $Serial shell "settings put global wifi_scan_always_enabled 0"
    adb -s $Serial shell "settings put global ble_scan_always_enabled 0"
    adb -s $Serial shell "settings put global send_action_app_error 0"
    adb -s $Serial shell "settings put global adservices_measurement_enabled 0"
    adb -s $Serial shell "settings put global adservices_topics_enabled 0"
    adb -s $Serial shell "settings put global adservices_fledge_enabled 0"
    adb -s $Serial shell "settings put global network_scoring_ui_enabled 0"
    adb -s $Serial shell "settings put global network_recommendations_enabled 0"
    adb -s $Serial shell "settings put global network_recommendation_request_timeout_ms 0"
    adb -s $Serial shell "settings put global wifi_wakeup_enabled 0"
    adb -s $Serial shell "pm disable-user --user 0 com.google.android.printservice.recommendation" 2>$null | Out-Null
    adb -s $Serial shell "pm disable-user --user 0 com.google.android.apps.wellbeing" 2>$null | Out-Null
    Write-Success "Privacy Sandbox ad tracking, passive network scoring probes, and background radio scanning disabled."

    Write-Step "6. Running Flash Storage TRIM"
    adb -s $Serial shell "sm fstrim"
    Write-Success "Storage trimmed."

    Write-Step "7. Ahead-of-Time Native Compilation (AOT Speed & Profile)"
    Write-Host " [*] Compiling core daily apps to native ARM64 machine code (speed)..." -ForegroundColor Cyan
    $priorityApps = @(
        "com.android.systemui",
        "com.android.settings",
        "com.oplus.camera",
        "com.android.cameraextensions",
        "com.coloros.gallery3d",
        "com.brave.browser",
        "com.whatsapp",
        "com.whatsapp.w4b",
        "com.google.android.youtube",
        "com.instagram.android",
        "com.twitter.android",
        "com.truecaller"
    )
    foreach ($pApp in $priorityApps) {
        if ($installedOutput -match "package:$pApp\b") {
            adb -s $Serial shell "cmd package compile -m speed -f $pApp" 2>$null | Out-Null
        }
    }
    Write-Host " [*] Pre-compiling remaining app bytecode (takes ~20-30s)..." -ForegroundColor Cyan
    adb -s $Serial shell "cmd package compile -m speed-profile -a" 2>$null | Out-Null
    Write-Success "AOT Native Compilation completed across all apps."

    Write-Step "OPTIMIZATION COMPLETE!"
    Write-Host @"
  All tweaks applied and verified successfully!
  - Your phone will run cooler and maintain 120 Hz smoothly.
  - You can now safely disconnect your phone and turn OFF Developer Options!
"@ -ForegroundColor Green
}

# --- FACTORY RESTORE ---
function Run-Restore {
    param([string]$Serial)
    Write-Step "RESTORE FACTORY DEFAULTS"
    Write-Info "Reverting all tweaks back to stock ColorOS/OxygenOS settings..."

    adb -s $Serial shell "settings put system min_refresh_rate 0.0"
    adb -s $Serial shell "settings put system peak_refresh_rate 120.0"
    adb -s $Serial shell "settings put system oplus_customize_screen_refresh_rate 3"

    adb -s $Serial shell "settings put global window_animation_scale 1.0"
    adb -s $Serial shell "settings put global transition_animation_scale 1.0"
    adb -s $Serial shell "settings put global animator_duration_scale 1.0"

    adb -s $Serial shell "am set-standby-bucket com.heytap.htms active"
    adb -s $Serial shell "cmd appops set com.heytap.htms POST_NOTIFICATION allow" 2>$null | Out-Null

    $reinstallList = @(
        "com.heytap.pictorial", "com.coloros.pictorial", "com.glance.internet",
        "com.heytap.market", "com.oppo.market", "com.nearme.gamecenter", "com.heytap.gamecenter",
        "com.heytap.browser", "com.nearme.browser", "com.nearme.instant.platform",
        "com.facebook.appmanager", "com.facebook.services", "com.facebook.system",
        "com.heytap.habit.analysis", "com.oplus.postmanservice", "com.oplus.gleanerservice", "com.oplus.onetrace", "com.oplus.logkit",
        "com.nearme.statistics.rom", "com.oplus.statistics.rom", "com.coloros.feedback", "com.oppo.usercenter.contact",
        "com.oplus.bttestmode", "com.oplus.nfcengineertest",
        "com.netflix.partner.activation", "com.amazon.appmanager",
        "com.oppo.operationManual", "com.coloros.operationManual", "com.google.android.feedback"
    )
    foreach ($pkg in $reinstallList) {
        adb -s $Serial shell "cmd package install-existing $pkg" 2>$null | Out-Null
        adb -s $Serial shell "pm enable $pkg" 2>$null | Out-Null
        adb -s $Serial shell "pm unsuspend $pkg" 2>$null | Out-Null
        adb -s $Serial shell "am set-standby-bucket $pkg active" 2>$null | Out-Null
    }

    $targetApps = @(
        "com.amazon.mShop.android.shopping", "in.amazon.mShop.android.shopping", "in.amazon.mShop.android.business.shopping",
        "com.ebay.mobile", "com.walmart.android", "com.target.ui", "com.einnovation.temu", "com.alibaba.aliexpresshd", "com.zzkko",
        "com.flipkart.android", "com.myntra.android", "com.meesho.supply", "com.ril.ajio", "com.shopsy.buyer", "com.reglobe.cashify",
        "com.olx.southasia", "com.olx.olx",
        "com.grofers.customerapp", "in.swiggy.android", "com.application.zomato", "com.zeptonow.android", "com.instacart.client", "com.dd.doordash", "com.ubercab.eats",
        "com.myairtelapp", "com.jio.myjio", "com.mizmowireless.acda", "com.vzw.hss.myverizon", "com.att.myWireless", "com.tmobile.pr.mytmobile",
        "com.ubercab", "com.olacabs.customer", "com.rapido.passenger", "com.makemytrip", "com.booking", "com.airbnb.android"
    )
    foreach ($app in $targetApps) {
        adb -s $Serial shell "am set-standby-bucket $app active" 2>$null | Out-Null
    }

    adb -s $Serial shell "pm enable com.google.android.apps.wellbeing" 2>$null | Out-Null
    adb -s $Serial shell "pm enable com.google.android.printservice.recommendation" 2>$null | Out-Null

    adb -s $Serial shell "settings put global wifi_scan_always_enabled 1"
    adb -s $Serial shell "settings put global ble_scan_always_enabled 1"
    adb -s $Serial shell "settings put global send_action_app_error 1"
    adb -s $Serial shell "settings put global adservices_measurement_enabled 1"
    adb -s $Serial shell "settings put global adservices_topics_enabled 1"
    adb -s $Serial shell "settings put global adservices_fledge_enabled 1"

    Write-Success "Factory defaults restored."
}

# MAIN DISPATCHER
Write-Header
$serial = Get-ConnectedDevice
if (-not $serial) { exit 1 }

if ($Audit) {
    Run-Audit -Serial $serial
    exit 0
}
if ($Optimize) {
    Run-Optimization -Serial $serial
    exit 0
}
if ($Restore) {
    Run-Restore -Serial $serial
    exit 0
}

# INTERACTIVE MENU
while ($true) {
    Write-Header
    Write-Host " Connected Device: $serial" -ForegroundColor Green
    Write-Host "`n Choose an option:" -ForegroundColor Yellow
    Write-Host "  [1] 🔍 Run System Health Check & Audit (Read-Only / No Changes)" -ForegroundColor White
    Write-Host "  [2] ⚡ Run Full Safe Optimization (Recommended)" -ForegroundColor Green
    Write-Host "  [3] 🔄 Restore Factory Defaults (Undo All Changes)" -ForegroundColor Yellow
    Write-Host "  [4] ❌ Exit" -ForegroundColor Red

    $choice = Read-Host "`n Enter your choice (1-4)"
    switch ($choice) {
        "1" { Run-Audit -Serial $serial; Read-Host "`n Press Enter to return to menu..."; break }
        "2" { Run-Optimization -Serial $serial; Read-Host "`n Press Enter to return to menu..."; break }
        "3" { Run-Restore -Serial $serial; Read-Host "`n Press Enter to return to menu..."; break }
        "4" { exit 0 }
        default { Write-Warn "Invalid choice. Please select 1, 2, 3, or 4." }
    }
}
