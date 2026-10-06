//
//  CarSplitInternal.h
//  最小化私有类声明（编译期只声明、运行期由系统解析，避免依赖私有头文件/SDK）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 私有 CoreFoundation API：Darwin 通知中心（设置面板 ↔ SpringBoard 桥接）
// 不在公开头文件/SDK 中存在，weak_import 使链接器放行，符号运行期由 CoreFoundation 提供。
extern CFNotificationCenterRef CFNotificationCenterGetDarwinCenter(void) __attribute__((weak_import));

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allApplications;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END
