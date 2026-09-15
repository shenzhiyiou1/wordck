#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSDictionary *WTThemeAssets;

static NSString *WTThemeBasePath(void) {
    return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks/WeChatThemeEngine"];
}

static void WTLoadTheme(void) {
    NSString *path = [WTThemeBasePath() stringByAppendingPathComponent:@"themes/dark-green/theme.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;

    NSError *error = nil;
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!config || error) return;

    WTThemeAssets = config[@"assets"];
}

__attribute__((constructor))
static void WTInitialize(void) {
    WTLoadTheme();
}

@interface UIImage (WeChatThemeEngine)
+ (UIImage *)WT_originalImageNamed:(NSString *)name;
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
    NSDictionary *entry = WTThemeAssets[name];
    NSString *relative = entry[@"replace"];
    if (relative) {
        NSString *base = [WTThemeBasePath() stringByAppendingPathComponent:@"themes/dark-green"];
        NSString *path = [base stringByAppendingPathComponent:relative];
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) return image;
    }

    return [self WT_themedImageNamed:name];
}

@end
