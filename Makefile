INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = mr

mr_FILES = mr/mr/mr.xm \
           mr/mr/InsideAppStore.m \
           mr/mr/StoreKitBridge.m \
           mr/mr/StoreKit2Manager.swift \
           mr/mr/view/ListView.m \
           mr/mr/view/NewRuKuView.m \
           mr/mr/view/NewRuKuWindow.m \
           mr/mr/RuKuNetworkAPI.m \
           mr/mr/SPUncaughtExceptionHandler.m

mr_CFLAGS = -fobjc-arc
mr_SWIFTFLAGS = -import-objc-header mr/mr/mr-Bridging-Header.h
mr_FRAMEWORKS = UIKit Foundation StoreKit Security SystemConfiguration CoreGraphics
mr_EXTRA_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk
