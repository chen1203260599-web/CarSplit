//
//  CarSplit Tweak.x  —  v0.1.0
//
//  原创实现的 CarPlay 双应用方案，与任何商业插件无代码关系。
//
//  v0.1 能力：
//   1. 让未做 CarPlay 适配的 App 也具备"可上屏"能力（车机应用列表可见、可启动）
//   2. CarPlay 连接后，按设置自动启动两个 App（App A 留在手机前台，App B 上到车机）
//   3. 全量日志写入 /var/tmp/carsplit.log，方便在设备上排查
//
//  v0.2（规划）：在车机/手机屏上把两个 App 并排渲染 + 可拖拽分隔条，见 docs/ROADMAP.md
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <unistd.h>
#include "CarSplitInternal.h"

static NSString * const CSCPrefsSuite = @"com.userspace.carsplit";

#pragma mark - 工具函数

static NSUserDefaults *CSDefaults(void) {
    static NSUserDefaults *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [[NSUserDefaults alloc] initWithSuiteName:CSCPrefsSuite];
    });
    return d;
}

static void CSLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });

    NSString *line = [NSString stringWithFormat:@"%@ [CarSplit] %@\n",
                      [df stringFromDate:[NSDate date]], msg];
    FILE *f = fopen("/var/tmp/carsplit.log", "a");
    if (f) {
        fwrite(line.UTF8String, 1, [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding], f);
        fclose(f);
    }
    NSLog(@"[CarSplit] %@", msg);
}

static BOOL CSBoolPref(NSString *key, BOOL def) {
    id v = [CSDefaults() objectForKey:key];
    return v ? [v boolValue] : def;
}

static NSString *CSStringPref(NSString *key, NSString *def) {
    NSString *v = [CSDefaults() stringForKey:key];
    return v.length ? v : def;
}

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

#pragma mark - 双应用启动

static void CSLaunchApp(NSString *bundleID) {
    if (!bundleID.length) {
        CSLog(@"launch skipped: empty bundle id");
        return;
    }
    Class W = NSClassFromString(@"LSApplicationWorkspace");
    if (!W) {
        CSLog(@"LSApplicationWorkspace missing, cannot launch %@", bundleID);
        return;
    }
    id ws = [W performSelector:NSSelectorFromString(@"defaultWorkspace")];
    if (!ws) {
        CSLog(@"defaultWorkspace nil");
        return;
    }
    BOOL ok = (BOOL)[ws performSelector:NSSelectorFromString(@"openApplicationWithBundleID:")
                             withObject:bundleID];
    CSLog(@"launch %@ -> %@", bundleID, ok ? @"OK" : @"FAILED");
}

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
    });
}

#pragma mark - 注入入口

%ctor {
    @autoreleasepool {
        NSString *proc = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
        if ([proc isEqualToString:@"com.apple.springboard"]) {
            CSLog(@"CarSplit v0.1.0 loaded in SpringBoard (pid %d)", getpid());
            CSInstallEligibilityHooks();
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
