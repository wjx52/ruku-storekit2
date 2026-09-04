TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

# Swift SK2 library (built as a separate dylib)
LIBRARY_NAME = mr_sw
mr_sw_FILES = SimpleStoreKit.swift
mr_sw_FRAMEWORKS = StoreKit Foundation
mr_sw_SWIFTFLAGS = -module-name mr_sw
mr_sw_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries
mr_sw_LDFLAGS = -rpath /usr/lib/swift

include $(THEOS_MAKE_PATH)/library.mk

# Main ObjC tweak
TWEAK_NAME = mr
mr_FILES = Tweak.xm \
           src/InsideAppStore.m \
           src/RuKuNetworkAPI.m \
           src/view/ListView.m \
           src/view/NewRuKuView.m \
           src/view/NewRuKuWindow.m \
           src/SPUncaughtExceptionHandler.m
mr_CFLAGS = -fobjc-arc
mr_FRAMEWORKS = UIKit Foundation StoreKit Security SystemConfiguration CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
