#!/usr/bin/env nu

#xiaomi poco x3 pro
##remove
adb shell pm uninstall -k --user 0 com.facebook.appmanager
adb shell pm uninstall -k --user 0 com.facebook.services
adb shell pm uninstall -k --user 0 com.facebook.system

##disable
###safe
adb shell pm disable-user --user 0 com.miui.analytics
adb shell pm disable-user --user 0 com.miui.cloudbackup
adb shell pm disable-user --user 0 com.miui.backup
adb shell pm disable-user --user 0 com.miui.micloudsync
adb shell pm disable-user --user 0 com.miui.cloudservice
adb shell pm disable-user --user 0 com.miui.notes
adb shell pm disable-user --user 0 com.miui.touchassistant
adb shell pm disable-user --user 0 com.miui.yellowpage
adb shell pm disable-user --user 0 com.miui.weather2
adb shell pm disable-user --user 0 com.miui.cleaner
adb shell pm disable-user --user 0 com.miui.player
adb shell pm disable-user --user 0 com.miui.videoplayer

###supossedly safe
adb shell pm disable-user --user 0 com.google.android.feedback
adb shell pm disable-user --user 0 com.xiaomi.joyose
adb shell pm disable-user --user 0 com.xiaomi.micloud.sdk
adb shell pm disable-user --user 0 com.xiaomi.midrop
adb shell pm disable-user --user 0 com.miui.mishare.connectivity
adb shell pm disable-user --user 0 com.miui.daemon
adb shell pm disable-user --user 0 com.miui.msa.global
adb shell pm disable-user --user 0 com.mi.android.globalFileexplorer
adb shell pm disable-user --user 0 com.xiaomi.payment
adb shell pm disable-user --user 0 com.google.android.marvin.talkback
adb shell pm disable-user --user 0 com.xiaomi.xmsfkeeper
adb shell pm disable-user --user 0 com.xiaomi.discover
adb shell pm disable-user --user 0 com.miui.bugreport

###not sure
# adb shell pm disable-user --user 0 com.android.bookmarkprovider
# adb shell pm disable-user --user 0 android.autoinstalls.config.Xiaomi.qssi
# adb shell pm disable-user --user 0 com.miui.audiomonitor
# adb shell pm disable-user --user 0 com.miui.miservice
# adb shell pm disable-user --user 0 com.xiaomi.xmsf
# adb shell pm disable-user --user 0 com.android.providers.partnerbookmarks

