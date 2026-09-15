ARCHS = arm64
TARGET = iphone:clang:latest:15.0

include $(THEOS)/theos/makefiles/common.mk

TWEAK_NAME = WeChatThemeEngine

WeChatThemeEngine_FILES = Tweak.xm
WeChatThemeEngine_CFLAGS = -fobjc-arc
WeChatThemeEngine_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat || true"
