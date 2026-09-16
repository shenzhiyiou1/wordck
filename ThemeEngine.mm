#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
static NSDictionary *WTThemeAssets;
static NSMutableDictionary *WTThemeMeta;
static NSString *WTStoragePath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"WeChatThemeEngine"];
}
static NSString *WTBundleThemesPath(void) {
    return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks/WeChatThemeEngine/themes"];
}
static NSString *WTImportedThemesPath(void) {
    NSString *path = [WTStoragePath() stringByAppendingPathComponent:@"ImportedThemes"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}
static NSString *WTSelectedThemeFile(void) {
    return [WTStoragePath() stringByAppendingPathComponent:@"selected-theme"];
}
static NSString *WTSelectedThemeName(void) {
    NSString *name = [NSString stringWithContentsOfFile:WTSelectedThemeFile() encoding:NSUTF8StringEncoding error:nil];
    return [name length] > 0 ? name : @"dark-green";
}
static NSString *WTThemePath(NSString *themeName) {
    NSString *path = [WTImportedThemesPath() stringByAppendingPathComponent:themeName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    return [WTBundleThemesPath() stringByAppendingPathComponent:themeName];
}
static NSDictionary *WTValidatedAssets(NSDictionary *config) {
    id rawAssets = config[@"assets"];
    if (![rawAssets isKindOfClass:[NSDictionary class]]) return nil;

    NSMutableDictionary *validated = [NSMutableDictionary dictionary];
    for (NSString *name in rawAssets) {
        if (![name isKindOfClass:[NSString class]]) continue;
        id entry = rawAssets[name];
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        id replace = entry[@"replace"];
        if (![replace isKindOfClass:[NSString class]] || [replace length] == 0) continue;
        validated[name] = @{ @"replace": replace };
    }
    return validated;
}

static void WTLoadTheme(void) {
    NSString *name = WTSelectedThemeName();
    NSString *path = [WTThemePath(name) stringByAppendingPathComponent:@"theme.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *newAssets = nil;
    NSDictionary *newMeta = nil;

    if (data) {
        NSError *error = nil;
        id config = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if ([config isKindOfClass:[NSDictionary class]] && !error) {
            newAssets = WTValidatedAssets(config);
            newMeta = config;
        }
    }

    @synchronized([UIImage class]) {
        WTThemeAssets = newAssets;
        WTThemeMeta = newMeta;
    }
}

static void WTShowMessage(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Theme Engine" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [controller presentViewController:alert animated:YES completion:nil];
    });
}
static NSArray *WTThemeDirectories(NSString *base) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *items = [manager contentsOfDirectoryAtPath:base error:&error];
    if (error) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *item in items) {
        NSString *path = [base stringByAppendingPathComponent:item];
        BOOL directory = NO;
        if ([manager fileExistsAtPath:path isDirectory:&directory] && directory) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"theme.json"]]) {
                [result addObject:item];
            }
        }
    }
    return result;
}
static UIViewController *WTTopViewController(void) {
    UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}
@interface WTThemePickerController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@end
@implementation WTThemePickerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Theme Engine";
    UIBarButtonItem *importButton = [[UIBarButtonItem alloc] initWithTitle:@"Import" style:UIBarButtonItemStylePlain target:self action:@selector(importTheme:)];
    self.navigationItem.rightBarButtonItem = importButton;
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}
- (NSArray *)themes {
    NSMutableArray *result = [WTThemeDirectories(WTImportedThemesPath()) mutableCopy];
    for (NSString *name in WTThemeDirectories(WTBundleThemesPath())) {
        if (![result containsObject:name]) [result addObject:name];
    }
    return result;
}
- (void)importTheme:(id)sender {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.folder"]] asCopy:YES];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;
    NSURL *url = urls.firstObject;
    [url startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSString *folderName = url.lastPathComponent;
    NSString *target = [WTImportedThemesPath() stringByAppendingPathComponent:folderName];
    [[NSFileManager defaultManager] removeItemAtPath:target error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:target error:&error];
    [url stopAccessingSecurityScopedResource];
    if (error) {
        WTShowMessage([NSString stringWithFormat:@"Import failed: %@", error.localizedDescription]);
        return;
    }
    [self.tableView reloadData];
    WTShowMessage(@"Theme imported. Tap it to apply.");
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.themes.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ThemeCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ThemeCell"];
    NSString *name = self.themes[indexPath.row];
    cell.textLabel.text = name;
    cell.accessoryType = [name isEqualToString:WTSelectedThemeName()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = self.themes[indexPath.row];
    NSError *writeError = nil;
    [name writeToFile:WTSelectedThemeFile() atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (writeError) {
        WTShowMessage([NSString stringWithFormat:@"Save failed: %@", writeError.localizedDescription]);
        return;
    }
    WTLoadTheme();
    [tableView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WTShowMessage([NSString stringWithFormat:@"Theme applied: %@", name]);
    });
}
@end
@interface WTThemeManager : NSObject
@end
@implementation WTThemeManager
+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [[UIColor colorWithRed:0.18 green:0.77 blue:0.55 alpha:1.0] colorWithAlphaComponent:0.90];
        button.layer.cornerRadius = 26;
        button.layer.masksToBounds = YES;
        button.frame = CGRectMake(window.bounds.size.width - 78, window.bounds.size.height - 118, 52, 52);
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragThemeButton:)];
        [button addGestureRecognizer:pan];
        [button setTitle:@"T" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(openThemePicker:) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:button];
    });
}
+ (void)openThemePicker:(id)sender {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[WTThemePickerController alloc] init]];
    [WTTopViewController() presentViewController:navigation animated:YES completion:nil];
}
+ (void)dragThemeButton:(UIPanGestureRecognizer *)recognizer {
    UIView *button = recognizer.view;
    if (!button) return;
    UIView *superview = button.superview;
    if (!superview) return;
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [recognizer translationInView:superview];
        CGPoint center = button.center;
        center.x += translation.x;
        center.y += translation.y;
        button.center = center;
        [recognizer setTranslation:CGPointZero inView:superview];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = superview.bounds;
        CGFloat side = button.bounds.size.width;
        CGFloat x = CGRectGetMidX(button.frame);
        CGFloat y = CGRectGetMidY(button.frame);
        x = MAX(side / 2.0, MIN(bounds.size.width - side / 2.0, x));
        y = MAX(side / 2.0 + superview.safeAreaInsets.top, MIN(bounds.size.height - side / 2.0 - superview.safeAreaInsets.bottom, y));
        [UIView animateWithDuration:0.18 animations:^{
            button.center = CGPointMake(x, y);
        }];
    }
}
@end
@implementation UIImage (WeChatThemeEngine)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WTLoadTheme();
        SEL original = @selector(imageNamed:);
        SEL replacement = @selector(WT_themedImageNamed:);
        Method originalMethod = class_getClassMethod(self, original);
        Method replacementMethod = class_getClassMethod(self, replacement);
        method_exchangeImplementations(originalMethod, replacementMethod);
    });
}
+ (UIImage *)WT_themedImageNamed:(NSString *)name {
    if (![name isKindOfClass:[NSString class]] || [name length] == 0) {
        return [self WT_themedImageNamed:name];
    }

    NSDictionary *assets = nil;
    @synchronized([UIImage class]) {
        assets = WTThemeAssets;
    }
    NSDictionary *entry = assets[name];
    if (![entry isKindOfClass:[NSDictionary class]]) {
        return [self WT_themedImageNamed:name];
    }

    NSString *relative = entry[@"replace"];
    if (![relative isKindOfClass:[NSString class]] || [relative length] == 0) {
        return [self WT_themedImageNamed:name];
    }

    NSString *base = WTThemePath(WTSelectedThemeName());
    NSString *path = [base stringByAppendingPathComponent:relative];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image) return image;
    return [self WT_themedImageNamed:name];
}
@end
