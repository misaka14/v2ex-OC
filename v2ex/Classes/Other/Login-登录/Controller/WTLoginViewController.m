//
//  WTLoginViewController.m
//  v2ex
//
//  Created by 无头骑士 GJ on 16/2/23.
//  Copyright © 2016年 无头骑士 GJ. All rights reserved.
//

#import "WTLoginViewController.h"

#import "WTTipView.h"


#import "NetworkTool.h"
#import "WTLogin2FARequestItem.h"
#import "WTLoginRequestItem.h"
#import "WTAccountViewModel.h"

#import "NSString+YYAdd.h"
#import "UIImageView+WebCache.h"
#import "UIImage+Extension.h"


@interface WTLoginViewController ()
/** 背景图片 */
@property (weak, nonatomic) IBOutlet UIImageView    *bgImageV;

@property (weak, nonatomic) IBOutlet UIView         *loginBgView;

/** 验证码图片 */
@property (weak, nonatomic) IBOutlet UIImageView    *verificationCodeImageV;
/** 用户名或邮箱 */
@property (weak, nonatomic) IBOutlet UITextField    *usernameOrEmailTextField;
/** 密码 */
@property (weak, nonatomic) IBOutlet UITextField    *passwordTextField;
/** 验证码 */
@property (weak, nonatomic) IBOutlet UITextField    *verificationCodeLabel;
/** 登陆按钮 */
@property (weak, nonatomic) IBOutlet UIButton       *loginButton;
/** 提示框View */
@property (nonatomic, weak) WTTipView               *tipView;
/** 定时器 */
@property (nonatomic, strong) NSTimer               *timer;
/** 登录请求参数  */
@property (nonatomic, strong) WTLoginRequestItem    *loginRequestItem;

/** 验证码顶部约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *verificationCodeTopLayoutCons;
/** 验证码码ContentView */
@property (weak, nonatomic) IBOutlet UIView *verificationCodeImageVBgView;
/** leftView的leading的约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leftViewLeadingLayoutCons;
/** 两步验证填写框 */
@property (weak, nonatomic) IBOutlet UITextField *twoFaTextF;
/** 两步验证确定按钮 */
@property (weak, nonatomic) IBOutlet UIButton *twoFaBtn;

@end

@implementation WTLoginViewController

#pragma mark - Life
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initView];
    
    [self initData];
    
}

#pragma mark - Private
- (void)initView
{
    // 测试代码
    self.loginButton.userInteractionEnabled = YES;
    
    // 1、添加圆角
    self.loginButton.layer.cornerRadius = 3;
    
    // 2、添加正在编辑监听事件
    [self.usernameOrEmailTextField addTarget: self action: @selector(textFieldEditingChanged) forControlEvents: UIControlEventEditingChanged];
    [self.passwordTextField addTarget: self action: @selector(textFieldEditingChanged) forControlEvents: UIControlEventEditingChanged];
    [self.verificationCodeLabel addTarget: self action: @selector(textFieldEditingChanged) forControlEvents: UIControlEventEditingChanged];
    [self.twoFaTextF addTarget: self action: @selector(twoFaTextFieldEditingChanged) forControlEvents: UIControlEventEditingChanged];
    
    self.title = @"帐号登录";
    
    self.loginBgView.layer.cornerRadius = 3;
    self.loginBgView.layer.masksToBounds = YES;
    
    // 3、为背景图片添加动画
    [self setBgImageVAnimation];
    
    [self timer];
    
    // 4、为 codeImageView 添加点击手势
    [self.verificationCodeImageV addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(setupCodeImage)]];
    
    // 5、如果是二次登录的话
    if (self.twoFArequestItem)
        self.leftViewLeadingLayoutCons.constant = -WTScreenWidth;
}

- (void)initData
{
    __weak typeof(self) weakSelf = self;
    void(^successBlock)(WTLoginRequestItem *) = ^(WTLoginRequestItem *loginRequestItem){
        weakSelf.loginRequestItem = loginRequestItem;
    };
    
    [[WTAccountViewModel shareInstance] getLoginReqItemWithSuccess: successBlock failure: nil];
}

/**
 *  为背景图片添加动画
 */
- (void)setBgImageVAnimation
{
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration: 15 delay: 0 options: 0 animations:^{
            
            self.bgImageV.transform = CGAffineTransformMakeScale(1.35, 1.35);
            
        } completion:^(BOOL finished) {
            
            [UIView animateWithDuration: 15 delay: 1 options: 0 animations:^{
               
                self.bgImageV.transform = CGAffineTransformIdentity;
                
            } completion: nil];
            
        }];
        
    });
}

- (void)stopTimer
{
    [self.timer invalidate];
}

- (void)startAnimation
{
    [UIView animateWithDuration: 0.5 animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark 设置验证码图片
- (void)setupCodeImage
{
    // 0、设置不可点击
    self.verificationCodeImageV.userInteractionEnabled = NO;
    
    __weak typeof(self) weakSelf = self;
    // 1、设置验证码
    [[NetworkTool shareInstance] GETWithUrlString: self.loginRequestItem.verificationCode success:^(NSData *data) {
        
        // 0、重新加载一个新的验证码
        NSString *html = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        if ([html isEqualToString: @""])
        {
            [self initData];
            return;
        }
        
        
        // 1、设置验证码
        weakSelf.verificationCodeImageV.image = [UIImage imageWithData: data];
        
        // 2、设置可点击
        weakSelf.verificationCodeImageV.userInteractionEnabled = YES;
        
    } failure:^(NSError *error) {
        WTLog(@"getDataWithUrl Error:%@", error)
        // 2、设置可点击
        weakSelf.verificationCodeImageV.userInteractionEnabled = YES;
    }];
}

#pragma mark 登录成功的操作
- (void)loginSucessOperation:(BOOL)twoStepAuth item:(WTLogin2FARequestItem *)item;
{
    if (twoStepAuth)
    {
        self.twoFArequestItem = item;
        self.leftViewLeadingLayoutCons.constant = -WTScreenWidth;
        [UIView animateWithDuration: 0.5 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
    else
    {
        [self closeButtonClick];
        
        if (self.loginSuccessBlock) self.loginSuccessBlock();
        
        [[NSNotificationCenter defaultCenter] postNotificationName: WTLoginStateChangeNotification object: nil];
    }
}

#pragma mark - 事件
#pragma mark 登陆
- (IBAction)loginButton:(UIButton *)sender
{
    [self.view endEditing: YES];
    [self.loginButton setTitle: @"登陆中..." forState: UIControlStateNormal];

    NSString *username = [self.usernameOrEmailTextField.text stringByTrim];
    NSString *password = [self.passwordTextField.text stringByTrim];
    NSString *verificationCode = [self.verificationCodeLabel.text stringByTrim];
    
    __weak typeof(self) weakSelf = self;
    [[WTAccountViewModel shareInstance] loginWithLoginRequestItem: self.loginRequestItem username: username password: password verificationCodeValue: verificationCode success: ^(BOOL twoStepAuth, WTLogin2FARequestItem *item){
        
        [weakSelf loginSucessOperation: twoStepAuth item: item];
        
    } failure:^(NSError *error, WTLoginRequestItem *loginRequestItem) {
        
        [weakSelf.loginButton setTitle: @"登陆" forState: UIControlStateNormal];
        
        if (error.code == 400 || error.code == -1011)
        {
            [weakSelf.tipView showErrorTitle: error.userInfo[@"message"]];
            
            if (loginRequestItem)
                weakSelf.loginRequestItem = loginRequestItem;
            else
                [weakSelf initData];
        
            return;
        }
        [weakSelf.tipView showErrorTitle: @"服务器异常，请稍候重试"];
    }];
    
}
#pragma mark 关闭
- (IBAction)closeButtonClick
{
    [self stopTimer];
    [self dismissViewControllerAnimated: YES completion: nil];
}
- (IBAction)faBtnClick
{
    [self.twoFaBtn setTitle: @"登陆中..." forState: UIControlStateNormal];
    
    NSString *code = [self.twoFaTextF.text stringByTrim];
    self.twoFArequestItem.code = code;
    
     __weak typeof(self) weakSelf = self;
    [[WTAccountViewModel shareInstance] login2faWithLogin2FARequestItem: self.twoFArequestItem success:^{
        
        [weakSelf loginSucessOperation: NO item: nil];
        
    } failure:^(NSError *error) {
        [weakSelf.twoFaBtn setTitle: @"继续" forState: UIControlStateNormal];
        if (error.code == 400 || error.code == -1011)
        {
            [weakSelf.tipView showErrorTitle: error.userInfo[@"message"]];
        }
        [weakSelf.tipView showErrorTitle: @"服务器异常，请稍候重试"];
    }];
    
}

- (void)twoFaTextFieldEditingChanged
{
    self.twoFaBtn.userInteractionEnabled = self.twoFaTextF.text.length > 0;
}

- (void)textFieldEditingChanged
{
    if ([self.usernameOrEmailTextField.text stringByTrim].length > 0 && [self.passwordTextField.text stringByTrim].length > 0 && [self.verificationCodeLabel.text stringByTrim].length > 0)
    {
        self.loginButton.userInteractionEnabled = YES;
    }
    else
    {
        self.loginButton.userInteractionEnabled = NO;
    }
}
- (IBAction)verificationCodeEditingEnd
{
    self.verificationCodeImageVBgView.hidden = YES;
    self.verificationCodeTopLayoutCons.constant = 20;
    [self startAnimation];
}
- (IBAction)verificationCodeEditingBegin
{
    self.verificationCodeImageVBgView.hidden = NO;
    self.verificationCodeTopLayoutCons.constant = -120;
    [self startAnimation];
}


#pragma mark textFieldEditingChanged
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing: YES];
}

#pragma mark - 懒加载
#pragma mark tipView
- (WTTipView *)tipView
{
    if (_tipView == nil)
    {
        WTTipView *tipView = [WTTipView wt_viewFromXib];
        [self.view addSubview: tipView];
        _tipView = tipView;
        
        tipView.frame = CGRectMake(0, -44, self.view.width, 44);
    }
    return _tipView;
}

- (NSTimer *)timer
{
    if (_timer == nil)
    {
        _timer = [NSTimer scheduledTimerWithTimeInterval: 31 target: self selector: @selector(setBgImageVAnimation) userInfo: nil repeats: YES];
    }
    return _timer;
}

#pragma mark - Setter
- (void)setLoginRequestItem:(WTLoginRequestItem *)loginRequestItem
{
    _loginRequestItem = loginRequestItem;
    
    // 1、设置验证码
    [self setupCodeImage];
}

- (void)dealloc
{
    WTLog(@"WTLoginViewController dealloc")
}
@end
