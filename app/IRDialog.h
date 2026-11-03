#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IRDialogActionStyle) {
    IRDialogActionStyleDefault = 0,
    IRDialogActionStyleSelected,
    IRDialogActionStyleDestructive,
    IRDialogActionStyleCancel
};

typedef NS_ENUM(NSInteger, IRDialogStyle) {
    IRDialogStyleAlert = 0,
    IRDialogStyleSheet
};

@interface IRDialogAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) IRDialogActionStyle style;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(IRDialogActionStyle)style
                        handler:(void (^)(void))handler;
@end

// Dialogo propio: alerta centrada o hoja inferior. Sustituye por completo a
// UIAlertController y UIActionSheet.
@interface IRDialog : UIViewController

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message;
+ (instancetype)sheetWithTitle:(NSString *)title message:(NSString *)message;

@property (nonatomic, assign) IRDialogStyle style;
@property (nonatomic, assign) BOOL dismissOnTapOutside;
@property (nonatomic, readonly) NSArray<UITextField *> *textFields;
@property (nonatomic, readonly) NSArray<IRDialogAction *> *actions;

- (IRDialogAction *)addAction:(NSString *)title
                        style:(IRDialogActionStyle)style
                      handler:(void (^)(void))handler;
- (UITextField *)addTextFieldWithPlaceholder:(NSString *)placeholder
                                        text:(NSString *)text
                                      secure:(BOOL)secure;
- (void)presentIn:(UIViewController *)viewController;

+ (void)showAlertIn:(UIViewController *)vc title:(NSString *)title message:(NSString *)message;
+ (void)showErrorIn:(UIViewController *)vc error:(NSError *)error;
+ (void)showConfirmIn:(UIViewController *)vc
                title:(NSString *)title
              message:(NSString *)message
          destructive:(BOOL)destructive
         confirmTitle:(NSString *)confirmTitle
              handler:(void (^)(void))handler;
+ (void)showSheetIn:(UIViewController *)vc
              title:(NSString *)title
            actions:(NSArray<IRDialogAction *> *)actions;
+ (void)showPromptIn:(UIViewController *)vc
               title:(NSString *)title
             message:(NSString *)message
         placeholder:(NSString *)placeholder
                text:(NSString *)text
             handler:(void (^)(NSString *text))handler;
+ (void)showPasswordIn:(UIViewController *)vc
                 title:(NSString *)title
               message:(NSString *)message
               handler:(void (^)(NSString *password))handler;

@end

// Aviso breve inferior.
@interface IRToast : UIView
+ (void)showIn:(UIView *)view message:(NSString *)message;
+ (void)showIn:(UIView *)view message:(NSString *)message icon:(UIImage *)icon;
@end

// Progreso modal con cancelacion.
@interface IRHUD : UIView
+ (instancetype)showIn:(UIView *)view title:(NSString *)title cancel:(void (^)(void))cancel;
- (void)updateProgress:(double)progress text:(NSString *)text;
- (void)hide;
@end

// Aviso en linea (no modal).
@interface IRBanner : UIView
+ (void)showIn:(UIView *)view message:(NSString *)message style:(NSInteger)style;
@end
