export THEOS_PACKAGE_SCHEME = roothide
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = bluetoothd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DualBT
DualBT_FILES = Tweak.x
DualBT_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
