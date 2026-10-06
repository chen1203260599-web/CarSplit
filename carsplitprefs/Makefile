TARGET := iphone:clang:latest:14.5

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CarSplitPrefs

CarSplitPrefs_FILES = CarSplitPrefs.m
CarSplitPrefs_INSTALL_PATH = /Library/PreferenceBundles
CarSplitPrefs_CFLAGS = -fobjc-arc -Wno-arc-performSelector-leaks -Wno-deprecated-declarations
CarSplitPrefs_FRAMEWORKS = UIKit
# 不链接 Preferences 私有框架（SDK 不含），符号运行期由 Settings/Preferences 进程解析
CarSplitPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
