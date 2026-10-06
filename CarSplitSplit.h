//
//  CarSplitSplit.h — 分屏引擎对外接口
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSSplitManager : NSObject
+ (void)show;           // 显示/刷新分屏预览（手机屏）
+ (void)hide;           // 关闭分屏预览
+ (void)maybeAutoShow;  // CarPlay 连接后按设置自动显示
+ (void)probeSceneForApp:(NSString *)bundleID; // 桥接探针：输出 FBScene 探测日志
@end

NS_ASSUME_NONNULL_END
