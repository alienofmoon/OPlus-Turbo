<#
.SYNOPSIS
    OPlus-Turbo Revert Script (Restore Defaults)
.DESCRIPTION
    Reverts all changes made by optimize.ps1 back to ColorOS / OxygenOS / Realme UI factory defaults.
#>

[CmdletBinding()]
param()

$devicesOutput = adb devices -l
$deviceLines = $devicesOutput -split "`r?`n" | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }

if (-not $deviceLines) {
    Write-Host "No device detected via ADB." -ForegroundColor Red
    exit 1
}

$deviceSerial = ($deviceLines[0] -split "\s+")[0]
Write-Host "Restoring default settings on: $deviceSerial..." -ForegroundColor Cyan

# 1. Reset Refresh Rate to Auto-select
adb -s $deviceSerial shell "settings put system min_refresh_rate 0.0"
adb -s $deviceSerial shell "settings put system peak_refresh_rate 120.0"
adb -s $deviceSerial shell "settings put system oplus_customize_screen_refresh_rate 3"

# 2. Reset Animations to 1.0x
adb -s $deviceSerial shell "settings put global window_animation_scale 1.0"
adb -s $deviceSerial shell "settings put global transition_animation_scale 1.0"
adb -s $deviceSerial shell "settings put global animator_duration_scale 1.0"

# 3. Restore HTMS
adb -s $deviceSerial shell "am set-standby-bucket com.heytap.htms active"
adb -s $deviceSerial shell "cmd appops set com.heytap.htms POST_NOTIFICATION allow" 2>$null

# 4. Reinstall and re-enable uninstalled OEM apps
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
    adb -s $deviceSerial shell "cmd package install-existing $pkg" 2>$null | Out-Null
    adb -s $deviceSerial shell "pm enable $pkg" 2>$null | Out-Null
    adb -s $deviceSerial shell "pm unsuspend $pkg" 2>$null | Out-Null
    adb -s $deviceSerial shell "am set-standby-bucket $pkg active" 2>$null | Out-Null
}

# 5. Restore 30+ App Shield to Active
$targetApps = @(
    "com.amazon.mShop.android.shopping", "in.amazon.mShop.android.shopping", "in.amazon.mShop.android.business.shopping",
    "com.ebay.mobile", "com.walmart.android", "com.target.ui", "com.einnovation.temu", "com.alibaba.aliexpresshd", "com.zzkko",
    "com.flipkart.android", "com.myntra.android", "com.meesho.supply", "com.ril.ajio", "com.shopsy.buyer", "com.reglobe.cashify",
    "com.olx.southasia", "com.olx.olx",
    "com.grofers.customerapp", "in.swiggy.android", "com.application.zomato", "com.zeptonow.android", "com.instacart.client", "com.dd.doordash", "com.ubercab.eats",
    "com.myairtelapp", "com.jio.myjio", "com.mizmowireless.acda", "com.vzw.hss.myverizon", "com.att.myWireless", "com.tmobile.pr.mytmobile",
    "com.ubercab", "com.olacabs.customer", "com.rapido.passenger", "com.makemytrip", "com.booking", "com.airbnb.android",
    "com.truecaller", "com.instagram.android", "com.twitter.android", "com.reddit.frontpage", "com.snapchat.android", "com.linkedin.android", "org.altruist.BajajExperia", "com.astronik.astrologer"
)
foreach ($app in $targetApps) {
    adb -s $deviceSerial shell "am set-standby-bucket $app active" 2>$null | Out-Null
}

# 6. Restore Digital Wellbeing & Print Service
adb -s $deviceSerial shell "pm enable com.google.android.apps.wellbeing" 2>$null | Out-Null
adb -s $deviceSerial shell "pm enable com.google.android.printservice.recommendation" 2>$null | Out-Null

# 7. Reset Location Scanning, Network Scoring & Telemetry
adb -s $deviceSerial shell "settings put global wifi_scan_always_enabled 1"
adb -s $deviceSerial shell "settings put global ble_scan_always_enabled 1"
adb -s $deviceSerial shell "settings put global send_action_app_error 1"
adb -s $deviceSerial shell "settings put global adservices_measurement_enabled 1"
adb -s $deviceSerial shell "settings put global adservices_topics_enabled 1"
adb -s $deviceSerial shell "settings put global adservices_fledge_enabled 1"
adb -s $deviceSerial shell "settings put global network_scoring_ui_enabled 1"
adb -s $deviceSerial shell "settings put global network_recommendations_enabled 1"
adb -s $deviceSerial shell "settings put global wifi_wakeup_enabled 1"

Write-Host "All settings reverted to stock factory defaults!" -ForegroundColor Green
