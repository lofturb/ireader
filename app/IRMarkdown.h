#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IRMarkdown : NSObject

+ (NSAttributedString *)attributedStringFromMarkdown:(NSString *)markdown
                                            baseFont:(UIFont *)baseFont
                                           textColor:(UIColor *)textColor
                                         accentColor:(UIColor *)accentColor;

@end
