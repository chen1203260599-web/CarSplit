TARGET := iphone:clang:latest:14.5

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CarSplitPrefs

CarSplitPrefs_FILES = CarSplitPrefs.m
CarSplitPrefs_INSTALL_PATH = /Library/PreferenceBundles
CarSplitPrefs_CFLAGS = -fobjc-arc -Wno-arc-performSelector-leaks -Wno-deprecated-declarations
CarSplitPrefs_FRAMEWORKS = UIKit
CarSplitPrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
