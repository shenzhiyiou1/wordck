#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSDictionary *WTThemeAssets;

static void WTLoadTheme(void) {
    NSString *path = @"/Library/Application Support/WeChatThemeEngine/themes/dark-green/theme.json";
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

%hook UIImage

+ (UIImage *)imageNamed:(NSString *)name {
    UIImage *original = %orig;

    NSDictionary *entry = WTThemeAssets[name];
    if (!entry || entry[@"replace"]) {
        NSString *relative = entry[@"replace"];
        if (relative) {
            NSString *base = @"/Library/Application Support/WeChatThemeEngine/themes/dark-green";
            NSString *path = [base stringByAppendingPathComponent:relative];
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if (image) return image;
        }
    }

    return original;
}

%end
