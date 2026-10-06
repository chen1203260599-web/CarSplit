//
//  CarSplitSupport.m — 共享工具实现
//

#import "CarSplitSupport.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include "CarSplitInternal.h"

NSString * const CSCPrefsSuite = @"com.userspace.carsplit";

static NSUserDefaults *CSDefaults(void) {
    static NSUserDefaults *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [[NSUserDefaults alloc] initWithSuiteName:CSCPrefsSuite];
    });
    return d;
}

void CSLog(NSString *fmt, ...) {
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

BOOL CSBoolPref(NSString *key, BOOL def) {
    id v = [CSDefaults() objectForKey:key];
    return v ? [v boolValue] : def;
}

NSString *CSStringPref(NSString *key, NSString *def) {
    NSString *v = [CSDefaults() stringForKey:key];
    return v.length ? v : def;
}

void CSLaunchApp(NSString *bundleID) {
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
