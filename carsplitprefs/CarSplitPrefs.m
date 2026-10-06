//
//  CarSplitPrefs.m  —  Settings > CarSplit 设置面板
//
//  不链接 Preferences.framework，仅以最小声明让编译器通过，类在运行期由
//  preferenceloader 加载解析（越狱社区通用做法）。
//

#import <UIKit/UIKit.h>
#include <notify.h>

#pragma mark - Preferences 最小声明

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) id target;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
+ (id)preferenceSpecifierNamed:(NSString *)name
                        target:(id)target
                           set:(SEL)set
                           get:(SEL)get
                        detail:(Class)detail
                          cell:(int)cell
                          edit:(Class)edit;
@end

@interface PSListController : UIViewController
{
    NSMutableArray *_specifiers;
}
@property (nonatomic, retain) UITableView *table;
- (id)specifiers;
- (void)setSpecifiers:(id)specifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (PSSpecifier *)specifier;
- (void)setSpecifier:(PSSpecifier *)specifier;
- (PSSpecifier *)specifierForID:(NSString *)identifier;
- (void)reloadSpecifiers;
@end

#pragma mark - 私有框架最小声明

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allApplications;
@end

#pragma mark - 根设置页

@interface CarSplitRootListController : PSListController
@end

@implementation CarSplitRootListController

- (id)specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

// 分屏预览控制按钮 → Darwin 通知 → SpringBoard 中的引擎
- (void)showSplitPreview {
    notify_post("com.userspace.carsplit.split.show");
}

- (void)hideSplitPreview {
    notify_post("com.userspace.carsplit.split.hide");
}

@end

#pragma mark - 应用选择页

@interface CarSplitAppPickerController : PSListController
@end

@implementation CarSplitAppPickerController

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    self.title = [specifier name];
}

- (id)specifiers {
    if (_specifiers != nil) return _specifiers;

    NSMutableArray *list = [NSMutableArray array];

    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"选择应用"
                                                        target:self
                                                           set:NULL
                                                           get:NULL
                                                        detail:nil
                                                          cell:1  // PSGroupCell
                                                          edit:nil];
    [list addObject:group];

    Class W = NSClassFromString(@"LSApplicationWorkspace");
    id ws = nil;
    NSArray *apps = nil;
    if (W) {
        ws = [W performSelector:NSSelectorFromString(@"defaultWorkspace")];
        if (ws) {
            apps = [ws performSelector:NSSelectorFromString(@"allApplications")];
        }
    }

    NSString *key = [[self specifier] propertyForKey:@"key"] ?: @"appA";
    NSString *suite = [[self specifier] propertyForKey:@"defaults"] ?: @"com.userspace.carsplit";
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:suite];
    NSString *selected = [d stringForKey:key];

    for (LSApplicationProxy *app in apps) {
        NSString *bid = [app bundleIdentifier];
        NSString *name = [app localizedName];
        if (!bid.length) continue;

        PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:name.length ? name : bid
                                                         target:self
                                                            set:NULL
                                                            get:NULL
                                                         detail:nil
                                                           cell:3  // PSLinkCell
                                                           edit:nil];
        [sp setProperty:bid forKey:@"bundleID"];
        [sp setProperty:key forKey:@"pickerKey"];
        [sp setProperty:selected forKey:@"selectedBundleID"];
        [list addObject:sp];
    }

    _specifiers = list;
    return list;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *sp = [[self specifiers] objectAtIndex:indexPath.row];
    NSString *bid = [sp propertyForKey:@"bundleID"];
    NSString *key = [sp propertyForKey:@"pickerKey"];
    NSString *suite = [[self specifier] propertyForKey:@"defaults"] ?: @"com.userspace.carsplit";
    if (bid.length && key.length) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:suite];
        [d setObject:bid forKey:key];
        [d synchronize];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"com.userspace.carsplit.settings.changed" object:nil];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
