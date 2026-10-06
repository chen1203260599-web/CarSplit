//
//  CarSplitInternal.h
//  最小化私有类声明（编译期只声明、运行期由系统解析，避免依赖私有头文件/SDK）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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
