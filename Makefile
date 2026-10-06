TARGET := iphone:clang:latest:14.5
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CarSplit

CarSplit_FILES = Tweak.x CarSplitSupport.m CarSplitSplit.m
CarSplit_CFLAGS = -fobjc-arc -Wno-arc-performSelector-leaks -Wno-deprecated-declarations
CarSplit_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += carsplitprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
