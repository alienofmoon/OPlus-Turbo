#!/usr/bin/env bash
# ===================================================================
#  OPLUS-TURBO: SAFE ADB PERFORMANCE & BATTERY OPTIMIZER
#  For Oppo (ColorOS) | OnePlus (OxygenOS) | Realme (Realme UI)
#  https://github.com/alienofmoon/OPlus-Turbo
# ===================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}===================================================================${NC}"
    echo -e "${CYAN}      OPLUS-TURBO: SAFE ADB PERFORMANCE & BATTERY OPTIMIZER       ${NC}"
    echo -e "${CYAN}      For Oppo (ColorOS) | OnePlus (OxygenOS) | Realme (Realme UI) ${NC}"
    echo -e "${CYAN}      https://github.com/alienofmoon/OPlus-Turbo                  ${NC}"
    echo -e "${CYAN}===================================================================${NC}"
}

get_device() {
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}[!] Error: adb command not found. Please install Android Platform Tools.${NC}"
        exit 1
    fi

    DEVICE=$(adb devices | grep -w "device" | head -n 1 | awk '{print $1}')
    if [ -z "$DEVICE" ]; then
        echo -e "${RED}[!] Error: No authorized ADB device connected.${NC}"
        echo -e "${YELLOW}    Ensure USB Debugging is ON and tap 'Allow' on your phone screen.${NC}"
        exit 1
    fi
    echo "$DEVICE"
}

run_audit() {
    DEVICE=$1
    echo -e "\n${YELLOW}=== SYSTEM AUDIT & HEALTH CHECK (READ-ONLY) ===${NC}"
    MODEL=$(adb -s "$DEVICE" shell "getprop ro.product.model" | tr -d '\r')
    BRAND=$(adb -s "$DEVICE" shell "getprop ro.product.brand" | tr -d '\r')
    OS_VER=$(adb -s "$DEVICE" shell "getprop ro.build.version.release" | tr -d '\r')
    echo -e "${GREEN}[+] Device: $BRAND $MODEL (Android $OS_VER)${NC}"

    echo -e "\n${CYAN}[Display Refresh Rate]${NC}"
    adb -s "$DEVICE" shell "dumpsys display | grep -E 'mActiveModeId|renderFrameRate' | head -n 4"

    echo -e "\n${CYAN}[Battery & Thermals]${NC}"
    adb -s "$DEVICE" shell "dumpsys battery | grep -i temperature"

    echo -e "\n${CYAN}[Advertising Daemon Status]${NC}"
    AD_ALARMS=$(adb -s "$DEVICE" shell "dumpsys batterystats | grep -i 'AdsCoreService'" || true)
    if [ -n "$AD_ALARMS" ]; then
        echo -e "${RED}[!] Advertising Wakeup Alarms Found: $AD_ALARMS${NC}"
    else
        echo -e "${GREEN}[+] Zero active advertising wakeups.${NC}"
    fi

    echo -e "\n${CYAN}[Storage Status]${NC}"
    adb -s "$DEVICE" shell "df -h /data"
    echo -e "\n${GREEN}[+] Audit complete! Ready to optimize.${NC}"
}

run_optimization() {
    DEVICE=$1
    echo -e "\n${YELLOW}=== 1. Tuning Display Fluidity & UI Responsiveness ===${NC}"
    MAX_FPS=$(adb -s "$DEVICE" shell "dumpsys display | grep -oE 'fps=[0-9.]+' | cut -d'=' -f2 | sort -rn | head -n1" | tr -d '\r')
    if [ -z "$MAX_FPS" ]; then
        MAX_FPS="120.0"
    fi
    echo -e "${GRAY}[*] Locking peak display refresh rate to ${MAX_FPS} Hz...${NC}"
    adb -s "$DEVICE" shell "settings put system min_refresh_rate $MAX_FPS"
    adb -s "$DEVICE" shell "settings put system peak_refresh_rate $MAX_FPS"
    adb -s "$DEVICE" shell "settings put system oplus_customize_screen_refresh_rate 2"
    adb -s "$DEVICE" shell "settings put global window_animation_scale 0.5"
    adb -s "$DEVICE" shell "settings put global transition_animation_scale 0.5"
    adb -s "$DEVICE" shell "settings put global animator_duration_scale 0.5"
    echo -e "${GREEN}[+] ${MAX_FPS} Hz locked and 0.5x animations applied.${NC}"

    echo -e "\n${YELLOW}=== 2. Taming Advertising Service (com.heytap.htms) ===${NC}"
    adb -s "$DEVICE" shell "pm unsuspend com.heytap.htms" 2>/dev/null || true
    adb -s "$DEVICE" shell "am set-standby-bucket com.heytap.htms restricted"
    adb -s "$DEVICE" shell "cmd appops set com.heytap.htms POST_NOTIFICATION ignore" 2>/dev/null || true
    echo -e "${GREEN}[+] HTMS restricted (ad wakeups frozen).${NC}"

    echo -e "\n${YELLOW}=== 3. Safe Subsystem Debloating (Lockscreen Ads, OEM Stubs & Analytics) ===${NC}"
    INSTALLED=$(adb -s "$DEVICE" shell "pm list packages" | tr -d '\r')

    DEBLOAT_LIST=(
        "com.heytap.pictorial" "com.coloros.pictorial" "com.glance.internet"
        "com.heytap.market" "com.oppo.market" "com.nearme.gamecenter" "com.heytap.gamecenter"
        "com.heytap.browser" "com.nearme.browser" "com.nearme.instant.platform"
        "com.facebook.appmanager" "com.facebook.services" "com.facebook.system"
        "com.heytap.habit.analysis" "com.oplus.postmanservice" "com.oplus.gleanerservice" "com.oplus.onetrace" "com.oplus.logkit"
        "com.nearme.statistics.rom" "com.oplus.statistics.rom" "com.coloros.feedback" "com.oppo.usercenter.contact"
        "com.oplus.bttestmode" "com.oplus.nfcengineertest"
        "com.netflix.partner.activation" "com.amazon.appmanager"
        "com.oppo.operationManual" "com.coloros.operationManual" "com.google.android.feedback"
    )

    for pkg in "${DEBLOAT_LIST[@]}"; do
        if echo "$INSTALLED" | grep -q "package:$pkg$"; then
            res=$(adb -s "$DEVICE" shell "pm uninstall -k --user 0 $pkg" 2>/dev/null || true)
            if echo "$res" | grep -q "Success"; then
                echo -e "${GREEN}[+] Uninstalled: $pkg${NC}"
            else
                adb -s "$DEVICE" shell "pm disable-user --user 0 $pkg" 2>/dev/null || true
                adb -s "$DEVICE" shell "pm suspend $pkg" 2>/dev/null || true
                adb -s "$DEVICE" shell "am set-standby-bucket $pkg restricted" 2>/dev/null || true
                echo -e "${GREEN}[+] Disabled & Suspended: $pkg${NC}"
            fi
        fi
    done

    echo -e "\n${YELLOW}=== 4. Global 30+ App Shield (Scanning Device) ===${NC}"

    TARGET_APPS=(
        "com.amazon.mShop.android.shopping" "in.amazon.mShop.android.shopping" "in.amazon.mShop.android.business.shopping"
        "com.ebay.mobile" "com.walmart.android" "com.target.ui" "com.einnovation.temu" "com.alibaba.aliexpresshd" "com.zzkko"
        "com.flipkart.android" "com.myntra.android" "com.meesho.supply" "com.ril.ajio" "com.shopsy.buyer" "com.reglobe.cashify"
        "com.olx.southasia" "com.olx.olx"
        "com.grofers.customerapp" "in.swiggy.android" "com.application.zomato" "com.zeptonow.android" "com.instacart.client" "com.dd.doordash" "com.ubercab.eats"
        "com.myairtelapp" "com.jio.myjio" "com.mizmowireless.acda" "com.vzw.hss.myverizon" "com.att.myWireless" "com.tmobile.pr.mytmobile"
        "com.ubercab" "com.olacabs.customer" "com.rapido.passenger" "com.makemytrip" "com.booking" "com.airbnb.android"
        "com.truecaller" "com.instagram.android" "com.twitter.android" "com.reddit.frontpage" "com.snapchat.android" "com.linkedin.android" "org.altruist.BajajExperia" "com.astronik.astrologer"
    )

    for app in "${TARGET_APPS[@]}"; do
        if echo "$INSTALLED" | grep -q "package:$app$"; then
            adb -s "$DEVICE" shell "am set-standby-bucket $app restricted" 2>/dev/null || true
            echo -e "${GREEN}[+] Restricted background sync: $app${NC}"
        fi
    done

    echo -e "\n${YELLOW}=== 5. Eliminating Passive Scanning, AdServices & Network Scoring ===${NC}"
    adb -s "$DEVICE" shell "settings put global wifi_scan_always_enabled 0"
    adb -s "$DEVICE" shell "settings put global ble_scan_always_enabled 0"
    adb -s "$DEVICE" shell "settings put global send_action_app_error 0"
    adb -s "$DEVICE" shell "settings put global adservices_measurement_enabled 0"
    adb -s "$DEVICE" shell "settings put global adservices_topics_enabled 0"
    adb -s "$DEVICE" shell "settings put global adservices_fledge_enabled 0"
    adb -s "$DEVICE" shell "settings put global network_scoring_ui_enabled 0"
    adb -s "$DEVICE" shell "settings put global network_recommendations_enabled 0"
    adb -s "$DEVICE" shell "settings put global network_recommendation_request_timeout_ms 0"
    adb -s "$DEVICE" shell "settings put global wifi_wakeup_enabled 0"
    adb -s "$DEVICE" shell "pm disable-user --user 0 com.google.android.printservice.recommendation" 2>/dev/null || true
    adb -s "$DEVICE" shell "pm disable-user --user 0 com.google.android.apps.wellbeing" 2>/dev/null || true
    echo -e "${GREEN}[+] Privacy Sandbox ad tracking, network scoring, and radio scanning disabled.${NC}"

    echo -e "\n${YELLOW}=== 6. Running Storage TRIM ===${NC}"
    adb -s "$DEVICE" shell "sm fstrim"
    echo -e "${GREEN}[+] Flash storage trimmed.${NC}"

    echo -e "\n${YELLOW}=== 7. Ahead-of-Time Native Compilation (AOT Speed & Profile) ===${NC}"
    echo -e "${GRAY}[*] Compiling core daily apps to native ARM64 machine code (speed)...${NC}"
    PRIORITY_APPS=(
        "com.android.systemui"
        "com.android.settings"
        "com.oplus.camera"
        "com.android.cameraextensions"
        "com.coloros.gallery3d"
        "com.brave.browser"
        "com.whatsapp"
        "com.whatsapp.w4b"
        "com.google.android.youtube"
        "com.instagram.android"
        "com.twitter.android"
        "com.truecaller"
    )
    for pApp in "${PRIORITY_APPS[@]}"; do
        if echo "$INSTALLED" | grep -q "package:$pApp$"; then
            adb -s "$DEVICE" shell "cmd package compile -m speed -f $pApp" 2>/dev/null || true
        fi
    done
    echo -e "${GRAY}[*] Pre-compiling remaining app bytecode (takes ~20-30s)...${NC}"
    adb -s "$DEVICE" shell "cmd package compile -m speed-profile -a" 2>/dev/null || true
    echo -e "${GREEN}[+] AOT Native Compilation complete!${NC}"

    echo -e "\n${GREEN}===================================================================${NC}"
    echo -e "${GREEN} OPTIMIZATION COMPLETE! Safe to unplug and turn off Developer Mode.${NC}"
    echo -e "${GREEN}===================================================================${NC}"
}

run_restore() {
    DEVICE=$1
    echo -e "\n${YELLOW}=== RESTORING FACTORY DEFAULTS ===${NC}"
    adb -s "$DEVICE" shell "settings put system min_refresh_rate 0.0"
    adb -s "$DEVICE" shell "settings put system peak_refresh_rate 120.0"
    adb -s "$DEVICE" shell "settings put system oplus_customize_screen_refresh_rate 3"
    adb -s "$DEVICE" shell "settings put global window_animation_scale 1.0"
    adb -s "$DEVICE" shell "settings put global transition_animation_scale 1.0"
    adb -s "$DEVICE" shell "settings put global animator_duration_scale 1.0"
    adb -s "$DEVICE" shell "am set-standby-bucket com.heytap.htms active"
    adb -s "$DEVICE" shell "cmd appops set com.heytap.htms POST_NOTIFICATION allow" 2>/dev/null || true
    DEBLOAT_LIST=(
        "com.heytap.pictorial" "com.coloros.pictorial" "com.glance.internet"
        "com.heytap.market" "com.oppo.market" "com.nearme.gamecenter" "com.heytap.gamecenter"
        "com.heytap.browser" "com.nearme.browser" "com.nearme.instant.platform"
        "com.facebook.appmanager" "com.facebook.services" "com.facebook.system"
        "com.heytap.habit.analysis" "com.oplus.postmanservice" "com.oplus.gleanerservice" "com.oplus.onetrace" "com.oplus.logkit"
        "com.nearme.statistics.rom" "com.oplus.statistics.rom" "com.coloros.feedback" "com.oppo.usercenter.contact"
        "com.oplus.bttestmode" "com.oplus.nfcengineertest"
        "com.netflix.partner.activation" "com.amazon.appmanager"
        "com.oppo.operationManual" "com.coloros.operationManual" "com.google.android.feedback"
    )

    TARGET_APPS=(
        "com.amazon.mShop.android.shopping" "in.amazon.mShop.android.shopping" "in.amazon.mShop.android.business.shopping"
        "com.ebay.mobile" "com.walmart.android" "com.target.ui" "com.einnovation.temu" "com.alibaba.aliexpresshd" "com.zzkko"
        "com.flipkart.android" "com.myntra.android" "com.meesho.supply" "com.ril.ajio" "com.shopsy.buyer" "com.reglobe.cashify"
        "com.olx.southasia" "com.olx.olx"
        "com.grofers.customerapp" "in.swiggy.android" "com.application.zomato" "com.zeptonow.android" "com.instacart.client" "com.dd.doordash" "com.ubercab.eats"
        "com.myairtelapp" "com.jio.myjio" "com.mizmowireless.acda" "com.vzw.hss.myverizon" "com.att.myWireless" "com.tmobile.pr.mytmobile"
        "com.ubercab" "com.olacabs.customer" "com.rapido.passenger" "com.makemytrip" "com.booking" "com.airbnb.android"
        "com.truecaller" "com.instagram.android" "com.twitter.android" "com.reddit.frontpage" "com.snapchat.android" "com.linkedin.android" "org.altruist.BajajExperia" "com.astronik.astrologer"
    )

    for pkg in "${DEBLOAT_LIST[@]}"; do
        adb -s "$DEVICE" shell "cmd package install-existing $pkg" 2>/dev/null || true
        adb -s "$DEVICE" shell "pm enable $pkg" 2>/dev/null || true
        adb -s "$DEVICE" shell "pm unsuspend $pkg" 2>/dev/null || true
        adb -s "$DEVICE" shell "am set-standby-bucket $pkg active" 2>/dev/null || true
    done
    for app in "${TARGET_APPS[@]}"; do
        adb -s "$DEVICE" shell "am set-standby-bucket $app active" 2>/dev/null || true
    done
    adb -s "$DEVICE" shell "pm enable com.google.android.apps.wellbeing" 2>/dev/null || true
    adb -s "$DEVICE" shell "pm enable com.google.android.printservice.recommendation" 2>/dev/null || true
    adb -s "$DEVICE" shell "settings put global wifi_scan_always_enabled 1"
    adb -s "$DEVICE" shell "settings put global ble_scan_always_enabled 1"
    adb -s "$DEVICE" shell "settings put global send_action_app_error 1"
    adb -s "$DEVICE" shell "settings put global adservices_measurement_enabled 1"
    adb -s "$DEVICE" shell "settings put global adservices_topics_enabled 1"
    adb -s "$DEVICE" shell "settings put global adservices_fledge_enabled 1"
    adb -s "$DEVICE" shell "settings put global network_scoring_ui_enabled 1"
    adb -s "$DEVICE" shell "settings put global network_recommendations_enabled 1"
    adb -s "$DEVICE" shell "settings put global wifi_wakeup_enabled 1"
    echo -e "${GREEN}[+] Factory defaults restored.${NC}"
}

DEVICE=$(get_device)

if [ "$1" == "--audit" ]; then
    run_audit "$DEVICE"
    exit 0
elif [ "$1" == "--optimize" ]; then
    run_optimization "$DEVICE"
    exit 0
elif [ "$1" == "--restore" ]; then
    run_restore "$DEVICE"
    exit 0
fi

while true; do
    print_header
    echo -e " Connected Device: ${GREEN}$DEVICE${NC}\n"
    echo -e "${YELLOW} Choose an option:${NC}"
    echo -e "  [1] 🔍 Run System Health Check & Audit (Read-Only / No Changes)"
    echo -e "  [2] ⚡ Run Full Safe Optimization (Recommended)"
    echo -e "  [3] 🔄 Restore Factory Defaults (Undo All Changes)"
    echo -e "  [4] ❌ Exit\n"

    read -p " Enter your choice (1-4): " choice
    case $choice in
        1) run_audit "$DEVICE"; read -p " Press Enter to return to menu..." ;;
        2) run_optimization "$DEVICE"; read -p " Press Enter to return to menu..." ;;
        3) run_restore "$DEVICE"; read -p " Press Enter to return to menu..." ;;
        4) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
