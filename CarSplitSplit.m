//
//  CarSplitSplit.m — v0.2 分屏引擎（纯 Objective-C，无 Logos 指令）
//
//  本模块只使用公开 UIKit API + 运行时探测（performSelector + respondsToSelector），
//  保证在 CI 上可编译、在设备上可安全降级：
//   - 双面板容器 + 可拖拽分隔条：公开 API，直接可用
//   - App 画面实时桥接：私有 API 路径以"探测日志"形式输出，供真机迭代（见 ROADMAP v0.3）
//

#import "CarSplitSplit.h"
#import "CarSplitSupport.h"
#include "CarSplitInternal.h"
#import <UIKit/UIKit.h>

#pragma mark - 面板视图

@interface CSSplitPaneView : UIView
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UIButton *launchButton;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation CSSplitPaneView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title bundleID:(NSString *)bundleID {
    self = [super initWithFrame:frame];
    if (self) {
        self.bundleID = bundleID;
        self.backgroundColor = [UIColor colorWithWhite:0.13 alpha:1.0];
        self.layer.cornerRadius = 10.0;
        self.layer.masksToBounds = YES;

        _infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _infoLabel.text = [NSString stringWithFormat:@"%@\n%@", title, bundleID];
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = [UIFont systemFontOfSize:14.0];
        _infoLabel.numberOfLines = 0;
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_infoLabel];

        _launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_launchButton setTitle:@"启动 App" forState:UIControlStateNormal];
        [_launchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _launchButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
        _launchButton.layer.cornerRadius = 8.0;
        _launchButton.accessibilityIdentifier = bundleID;
        [_launchButton addTarget:self action:@selector(launchTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_launchButton];

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.text = @"等待桥接（v0.3）";
        _statusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        _statusLabel.font = [UIFont systemFontOfSize:12.0];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_statusLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    self.infoLabel.frame = CGRectMake(12, h * 0.30, w - 24, 52);
    self.launchButton.frame = CGRectMake(w * 0.25, h * 0.52, w * 0.5, 40);
    self.statusLabel.frame = CGRectMake(12, h * 0.68, w - 24, 20);
}

- (void)launchTapped:(id)sender {
    CSLog(@"[split] pane launch tapped: %@", self.bundleID);
    CSLaunchApp(self.bundleID);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [CSSplitManager probeSceneForApp:self.bundleID];
    });
}

@end

#pragma mark - 分屏容器控制器

@interface CSSplitViewController : UIViewController
@property (nonatomic, strong) CSSplitPaneView *paneA;
@property (nonatomic, strong) CSSplitPaneView *paneB;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) CGFloat ratio;
@end

@implementation CSSplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.ratio = 0.5;
    id v = [[NSUserDefaults alloc] initWithSuiteName:CSCPrefsSuite];
    float saved = [v floatForKey:@"splitRatio"];
    if (saved >= 0.3 && saved <= 0.7) self.ratio = saved;

    NSString *a = CSStringPref(@"appA", @"");
    NSString *b = CSStringPref(@"appB", @"");
    NSString *aName = [self appNameForBundleID:a] ?: @"App A";
    NSString *bName = [self appNameForBundleID:b] ?: @"App B";

    self.paneA = [[CSSplitPaneView alloc] initWithFrame:CGRectZero title:aName bundleID:a];
    self.paneB = [[CSSplitPaneView alloc] initWithFrame:CGRectZero title:bName bundleID:b];
    [self.view addSubview:self.paneA];
    [self.view addSubview:self.paneB];

    self.divider = [[UIView alloc] initWithFrame:CGRectZero];
    self.divider.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(onDividerPan:)];
    [self.divider addGestureRecognizer:pan];
    [self.view addSubview:self.divider];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"✕ 关闭" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.85];
    self.closeButton.layer.cornerRadius = 8.0;
    [self.closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    [self layoutPanes];
    CSLog(@"[split] container shown, ratio=%.2f apps=%@/%@", self.ratio, a, b);
}

- (NSString *)appNameForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return nil;
    Class W = NSClassFromString(@"LSApplicationWorkspace");
    id ws = W ? [W performSelector:NSSelectorFromString(@"defaultWorkspace")] : nil;
    NSArray *apps = ws ? [ws performSelector:NSSelectorFromString(@"allApplications")] : nil;
    for (id app in apps) {
        NSString *bid = nil;
        SEL s = NSSelectorFromString(@"bundleIdentifier");
        if ([app respondsToSelector:s]) bid = [app performSelector:s];
        if ([bid isEqualToString:bundleID]) {
            SEL n = NSSelectorFromString(@"localizedName");
            NSString *name = nil;
            if ([app respondsToSelector:n]) name = [app performSelector:n];
            return name.length ? name : bundleID;
        }
    }
    return bundleID;
}

- (void)layoutPanes {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat dividerW = 24.0;
    CGFloat aWidth = MAX(0.0, w * self.ratio - dividerW / 2.0);
    self.paneA.frame = CGRectMake(8, 40, aWidth - 8, h - 48);
    self.divider.frame = CGRectMake(w * self.ratio - dividerW / 2.0, 40, dividerW, h - 48);
    self.paneB.frame = CGRectMake(w * self.ratio + dividerW / 2.0 + 8, 40,
                                  w - (w * self.ratio + dividerW / 2.0 + 8) - 8, h - 48);
    self.closeButton.frame = CGRectMake(w - 92, 6, 84, 28);
}

- (void)onDividerPan:(UIPanGestureRecognizer *)g {
    CGFloat x = [g locationInView:self.view].x;
    CGFloat w = self.view.bounds.size.width;
    self.ratio = MAX(0.3, MIN(0.7, x / w));
    [self layoutPanes];
    if (g.state == UIGestureRecognizerStateEnded ||
        g.state == UIGestureRecognizerStateCancelled) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:CSCPrefsSuite];
        [d setFloat:self.ratio forKey:@"splitRatio"];
        CSLog(@"[split] ratio saved: %.2f", self.ratio);
    }
}

- (void)closeTapped:(id)sender {
    [CSSplitManager hide];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end

#pragma mark - 引擎单例

@interface CSSplitManager ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) CSSplitViewController *splitVC;
@end

@implementation CSSplitManager

+ (instancetype)shared {
    static CSSplitManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[CSSplitManager alloc] init]; });
    return m;
}

+ (void)show {
    CSSplitManager *m = [self shared];
    if (!CSBoolPref(@"preview_enabled", YES)) {
        CSLog(@"[split] preview_enabled=NO, show ignored");
        return;
    }
    if (!m.splitVC) {
        m.splitVC = [[CSSplitViewController alloc] init];
    }
    if (!m.window) {
        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        w.windowLevel = 1995.0f;  // 低于系统弹窗，高于普通窗口
        w.rootViewController = m.splitVC;
        w.backgroundColor = [UIColor blackColor];
        m.window = w;
    }
    [m.window setHidden:NO];
    [m.splitVC layoutPanes];
    CSLog(@"[split] window visible");
}

+ (void)hide {
    CSSplitManager *m = [self shared];
    if (m.window) {
        [m.window setHidden:YES];
        CSLog(@"[split] window hidden");
    }
}

+ (void)maybeAutoShow {
    if (!CSBoolPref(@"split_autostart", YES)) {
        CSLog(@"[split] split_autostart disabled, skip");
        return;
    }
    if (!CSBoolPref(@"preview_enabled", YES)) {
        CSLog(@"[split] preview disabled, skip auto show");
        return;
    }
    [self show];
}

#pragma mark - 实时画面桥接探测（v0.3 前置）

+ (void)probeSceneForApp:(NSString *)bundleID {
    if (!bundleID.length) return;
    Class mgrClass = NSClassFromString(@"FBSceneManager");
    if (!mgrClass) {
        CSLog(@"[bridge] FBSceneManager unavailable on this iOS");
        return;
    }
    id mgr = [mgrClass performSelector:NSSelectorFromString(@"sharedInstance")];
    if (!mgr) {
        CSLog(@"[bridge] FBSceneManager sharedInstance nil");
        return;
    }
    NSArray *scenes = nil;
    SEL scenesSel = NSSelectorFromString(@"scenes");
    if ([mgr respondsToSelector:scenesSel]) {
        scenes = [mgr performSelector:scenesSel];
    }
    CSLog(@"[bridge] FBSceneManager alive, scene count=%lu", (unsigned long)scenes.count);
    for (id scene in scenes) {
        NSString *sid = nil;
        SEL idSel = NSSelectorFromString(@"identifier");
        if ([scene respondsToSelector:idSel]) sid = [scene performSelector:idSel];
        if (sid.length && [sid hasPrefix:bundleID]) {
            id hostMgr = nil;
            SEL hSel = NSSelectorFromString(@"sceneHostManager");
            if ([scene respondsToSelector:hSel]) hostMgr = [scene performSelector:hSel];
            CSLog(@"[bridge] FOUND scene id=%@ hostManager=%@ (下一步：用 hostManager 拉取实时 layer)",
                  sid, hostMgr ? NSStringFromClass([hostMgr class]) : @"nil");
            return;
        }
    }
    CSLog(@"[bridge] no FBScene for %@ yet (请先在手机上启动该 App)", bundleID);
}

@end
