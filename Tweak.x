//
//  CarSplit Tweak.x  —  v0.2.0
//
//  原创实现的 CarPlay 双应用方案，与任何商业插件无代码关系。
//
//  能力：
//   1. 让未做 CarPlay 适配的 App 也具备"可上屏"能力（车机应用列表可见、可启动）
//   2. CarPlay 连接后，按设置自动启动两个 App（App A 留在手机前台，App B 上到车机）
//   3. 分屏预览容器（v0.2）：手机屏上双面板 + 可拖拽分隔条，无需车机即可测试
//   4. 全量日志写入 /var/tmp/carsplit.log
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <unistd.h>
#import <notify.h>
#include "CarSplitInternal.h"
#include "CarSplitSupport.h"
#include "CarSplitSplit.h"

#pragma mark - 上屏能力钩子（运行时安全替换，方法不存在则静默跳过）

static void CSForceCarPlayCapable(Class cls, SEL sel) {
    if (!cls || !sel) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        CSLog(@"skip hook: %@ %s (method absent)", NSStringFromClass(cls), sel_getName(sel));
        return;
    }
    IMP orig = method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(^(id self) {
        if (CSBoolPref(@"allapps_carplay", YES)) return YES;
        return ((BOOL (*)(id, SEL))orig)(self, sel);
    });
    method_setImplementation(m, replacement);
    CSLog(@"hooked %@ %s -> YES (可上屏)", NSStringFromClass(cls), sel_getName(sel));
}

static void CSInstallEligibilityHooks(void) {
    Class lsProxy = NSClassFromString(@"LSApplicationProxy");
    if (lsProxy) {
        CSForceCarPlayCapable(lsProxy, NSSelectorFromString(@"isCarPlayCapable"));
        CSForceCarPlayCapable(lsProxy, NSSelectorFromString(@"carPlayCapable"));
    }
    Class sbApp = NSClassFromString(@"SBApplication");
    if (sbApp) {
        CSForceCarPlayCapable(sbApp, NSSelectorFromString(@"isCarPlayCapable"));
    }
}

#pragma mark - 自动启动

static void CSMaybeAutoStart(void) {
    if (!CSBoolPref(@"autostart", YES)) {
        CSLog(@"autostart disabled, skip");
        return;
    }
    NSString *a = CSStringPref(@"appA", @"");
    NSString *b = CSStringPref(@"appB", @"");
    if (!a.length && !b.length) {
        CSLog(@"autostart: no apps configured, skip");
        return;
    }
    CSLog(@"CarPlay connected: schedule launch A=%@ B=%@ in 4s", a, b);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CSLaunchApp(a);
        CSLaunchApp(b);
        [CSSplitManager maybeAutoShow];
    });
}

#pragma mark - Darwin 通知（libnotify 公开 API：设置面板 notify_post → SpringBoard 接收）

static void CSRegisterDarwinObservers(void) {
    uint32_t tokShow = 0, tokHide = 0;
    notify_register_dispatch("com.userspace.carsplit.split.show", &tokShow,
                             dispatch_get_main_queue(), ^(int t) {
        CSLog(@"darwin: split.show");
        [CSSplitManager show];
    });
    notify_register_dispatch("com.userspace.carsplit.split.hide", &tokHide,
                             dispatch_get_main_queue(), ^(int t) {
        CSLog(@"darwin: split.hide");
        [CSSplitManager hide];
    });
    CSLog(@"darwin observers registered (split.show / split.hide)");
}

#pragma mark - 注入入口

%ctor {
    @autoreleasepool {
        NSString *proc = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
        if ([proc isEqualToString:@"com.apple.springboard"]) {
            CSLog(@"CarSplit v0.2.0 loaded in SpringBoard (pid %d)", getpid());
            CSInstallEligibilityHooks();
            CSRegisterDarwinObservers();
            [[NSNotificationCenter defaultCenter]
                addObserverForName:@"CARSessionDidConnectNotification"
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification *note) {
                            CSMaybeAutoStart();
                        }];
            CSLog(@"observer registered: CARSessionDidConnectNotification");
        } else {
            CSLog(@"CarSplit loaded in %@ (no-op for this process)", proc);
        }
    }
}
