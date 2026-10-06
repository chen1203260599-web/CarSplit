//
//  CarSplitSupport.h — 各编译单元共享的工具函数
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CSCPrefsSuite;

BOOL CSBoolPref(NSString *key, BOOL def);
NSString *CSStringPref(NSString *key, NSString *def);
void CSLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
void CSLaunchApp(NSString *bundleID);

NS_ASSUME_NONNULL_END
