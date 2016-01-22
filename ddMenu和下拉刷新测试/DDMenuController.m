//
//  DDMenuController.m
//  DDMenuController
//
//  Created by Devin Doty on 11/30/11.
//  Copyright (c) 2011 toaast. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "DDMenuController.h"

#define kMenuFullWidth [UIScreen mainScreen].bounds.size.width
#define kMenuDisplayedWidth 130.0f  //左侧视图的显示宽度
#define kMenuOverlayWidth (self.view.bounds.size.width - kMenuDisplayedWidth)
#define kMenuBounceOffset 10.0f
#define kMenuBounceDuration .3f
#define kMenuSlideDuration .3f


@interface DDMenuController (Internal)
- (void)showShadow:(BOOL)val;
@end

@implementation DDMenuController

@synthesize delegate;

@synthesize leftViewController=_left;
@synthesize rightViewController=_right;
@synthesize rootViewController=_root;

@synthesize tap=_tap;
@synthesize pan=_pan;


- (id)initWithRootViewController:(UIViewController*)controller {
    if ((self = [super init])) {
        _root = controller;
        
    }
    return self;
}

- (id)init {
    if ((self = [super init])) {
        
    }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark Setters

- (void)setDelegate:(id<DDMenuControllerDelegate>)val {
    delegate = val;
    _menuFlags.respondsToWillShowViewController = [(id)self.delegate respondsToSelector:@selector(menuController:willShowViewController:)];
}



- (void)setLeftViewController:(UIViewController *)leftController {
    _left = leftController;
    _menuFlags.canShowLeft = (_left!=nil);
    [self resetNavButtons];
}


//若之前有root 则将其从堆栈中清除
- (void)setRootViewController:(UIViewController *)rootViewController {
    UIViewController *tempRoot = _root;
    _root = rootViewController;
    
    if (_root) {
        
        if (tempRoot) {
            [tempRoot.view removeFromSuperview];
            tempRoot = nil;
        }
        
        UIView *view = _root.view;
        view.frame = self.view.bounds;
        [self.view addSubview:view];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        pan.delegate = (id<UIGestureRecognizerDelegate>)self;
        [view addGestureRecognizer:pan];
        _pan = pan;
        
        UISwipeGestureRecognizer *swip = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swip:)];
        swip.delegate = (id<UIGestureRecognizerDelegate>)self;
        [view addGestureRecognizer:swip];
        _swip = swip;
        
    } else {
        
        if (tempRoot) {
            [tempRoot.view removeFromSuperview];
            tempRoot = nil;
        }
        
    }
    
    [self resetNavButtons];
}

- (void)setRootController:(UIViewController *)controller animated:(BOOL)animated {
    
    if (!controller) {
        [self setRootViewController:controller];
        return;
    }
    
    if (_menuFlags.showingLeftView) {
        
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        /*
         在一定的时间内关闭事件的传递。应用程序可以调用
         UIApplication
         的
         beginIgnoringInteractionEvents
         方法，并在随后调用
         endIgnoringInteractionEvents
         方法来实现这个目的。前一个方法使应用程序完全停止接收触摸事件消息，第二个方法则重启消息的接收。某些时候，当您的代码正在执行动画时，可能希望关闭事件的传递。
         */
        
        
        __block DDMenuController *selfRef = self;
        __block UIViewController *rootRef = _root;
        CGRect frame = rootRef.view.frame;
        frame.origin.x = rootRef.view.bounds.size.width;
        
        [UIView animateWithDuration:.1 animations:^{
            
            rootRef.view.frame = frame;
            
        } completion:^(BOOL finished) {
            
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            [selfRef setRootViewController:controller];
            _root.view.frame = frame;
            [selfRef showRootController:animated];
            
        }];
        
    } else {
        
        // just add the root and move to it if it's not center
        [self setRootViewController:controller];
        [self showRootController:animated];
        
    }
    
}



#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setRootViewController:_root]; // reset root
    
    if (!_tap) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        tap.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self.view addGestureRecognizer:tap];
        [tap setEnabled:NO];
        _tap = tap;
    }
    
}

- (void)viewDidUnload {
    [super viewDidUnload];
    _tap = nil;
    _pan = nil;
}

- (void)swip:(UISwipeGestureRecognizer *)gesture
{
    [gesture setEnabled:NO];
    
    [self showRootController:YES];
}

#pragma mark - GestureRecognizers---手势-------

- (void)pan:(UIPanGestureRecognizer*)gesture {
    
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        
        [self showShadow:YES];
        _panOriginX = self.view.frame.origin.x;        
        _panVelocity = CGPointMake(0.0f, 0.0f);
        if([gesture velocityInView:self.view].x > 0) {//滑动手势的矢量方法
            _panDirection = DDMenuPanDirectionRight;
        } else {
            _panDirection = DDMenuPanDirectionLeft;
        }

    }
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint velocity = [gesture velocityInView:self.view];
        if((velocity.x*_panVelocity.x + velocity.y*_panVelocity.y) < 0) {
            _panDirection = (_panDirection == DDMenuPanDirectionRight) ? DDMenuPanDirectionLeft : DDMenuPanDirectionRight;
        }
        
        _panVelocity = velocity;        
        CGPoint translation = [gesture translationInView:self.view]; //偏移量
        CGRect frame = _root.view.frame;
        frame.origin.x = _panOriginX + translation.x;
        
        if (frame.origin.x > 0.0f && !_menuFlags.showingLeftView) {// root向右滑动，frame>0 且leftView未显示
            
            if(_menuFlags.showingRightView) {
                _menuFlags.showingRightView = NO;
                [self.rightViewController.view removeFromSuperview];
            }
            
            if (_menuFlags.canShowLeft) {
                _menuFlags.showingLeftView = YES;
                CGRect frame = self.view.bounds;
				frame.size.width = kMenuFullWidth;
                self.leftViewController.view.frame = frame;
                [self.view insertSubview:self.leftViewController.view atIndex:0];
                
            } else {
                frame.origin.x = 0.0f; // ignore right view if it's not set
            }
            
        } else if (frame.origin.x < 0.0f && !_menuFlags.showingRightView) {
            
            if(_menuFlags.showingLeftView) {
                _menuFlags.showingLeftView = NO;
                [self.leftViewController.view removeFromSuperview];
            }
            
            if (_menuFlags.canShowRight) {
                
                _menuFlags.showingRightView = YES;
                CGRect frame = self.view.bounds;
				frame.origin.x += frame.size.width - kMenuFullWidth;
				frame.size.width = kMenuFullWidth;
                self.rightViewController.view.frame = frame;
                [self.view insertSubview:self.rightViewController.view atIndex:0];
     
            } else {
                frame.origin.x = 0.0f; // ignore left view if it's not set
            }
            
        }
        
        _root.view.frame = frame;

    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        
        //  Finishing moving to left, right or root view with current pan velocity
        [self.view setUserInteractionEnabled:NO];
        
        DDMenuPanCompletion completion = DDMenuPanCompletionRoot; // by default animate back to the root
        
        if (_panDirection == DDMenuPanDirectionRight && _menuFlags.showingLeftView) {
            completion = DDMenuPanCompletionLeft;
        } else if (_panDirection == DDMenuPanDirectionLeft && _menuFlags.showingRightView) {
            completion = DDMenuPanCompletionRight;
        }
        
        CGPoint velocity = [gesture velocityInView:self.view];    
        if (velocity.x < 0.0f) {
            velocity.x *= -1.0f;
        }
        BOOL bounce = (velocity.x > 800);
        CGFloat originX = _root.view.frame.origin.x;
        CGFloat width = _root.view.frame.size.width;
        CGFloat span = (width - kMenuOverlayWidth);
        CGFloat duration = kMenuSlideDuration; // default duration with 0 velocity
        
        
        if (bounce) {
            duration = (span / velocity.x); // bouncing we'll use the current velocity to determine duration 判定延长时间
        } else //移动的距离/左视图的距离 * 持续时间
        {
            duration = ((span - originX) / span) * duration; // user just moved a little, use the defult duration, otherwise it would be too slow
        }
        
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            if (completion == DDMenuPanCompletionLeft) {
                [self showLeftController:NO];
            } else if (completion == DDMenuPanCompletionRight) {
                [self showRightController:NO];
            } else {
                [self showRootController:NO];
            }
            [_root.view.layer removeAllAnimations];
            [self.view setUserInteractionEnabled:YES];
        }];
        
        
        CGPoint pos = _root.view.layer.position;
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        NSMutableArray *keyTimes = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        NSMutableArray *timingFunctions = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        
        [values addObject:[NSValue valueWithCGPoint:pos]];
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
        [keyTimes addObject:[NSNumber numberWithFloat:0.0f]];
        
        if (bounce) {            
            duration += kMenuBounceDuration;
            [keyTimes addObject:[NSNumber numberWithFloat:1.0f - ( kMenuBounceDuration / duration)]];
            if (completion == DDMenuPanCompletionLeft) {
                
                [values addObject:[NSValue valueWithCGPoint:CGPointMake(((width/2) + span) + kMenuBounceOffset, pos.y)]];
                
            } else if (completion == DDMenuPanCompletionRight) {
                
                [values addObject:[NSValue valueWithCGPoint:CGPointMake(-((width/2) - (kMenuOverlayWidth-kMenuBounceOffset)), pos.y)]];
                
            } else {
                
                // depending on which way we're panning add a bounce offset
                if (_panDirection == DDMenuPanDirectionLeft) {
                    [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) - kMenuBounceOffset, pos.y)]];
                } else {
                    [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) + kMenuBounceOffset, pos.y)]];
                }
                
            }
            
            [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            
        }
        if (completion == DDMenuPanCompletionLeft) {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) + span, pos.y)]];
        } else if (completion == DDMenuPanCompletionRight) {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(-((width/2) - kMenuOverlayWidth), pos.y)]];
        } else {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(width/2, pos.y)]];
        }
        
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        [keyTimes addObject:[NSNumber numberWithFloat:1.0f]];
        
        animation.timingFunctions = timingFunctions;
        animation.keyTimes = keyTimes;
        //animation.calculationMode = @"cubic";
        animation.values = values;
        animation.duration = duration;   
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [_root.view.layer addAnimation:animation forKey:nil];
        [CATransaction commit];   
    
    }
    
    
}

- (void)tap:(UITapGestureRecognizer*)gesture {
    
    [gesture setEnabled:NO];
    
    [self showRootController:YES];
    
}

-(void)setIsPushBackCell:(BOOL)isPushBackCell
{
    _isPushBackCell = isPushBackCell;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {

    // Check for horizontal pan gesture
    if (gestureRecognizer == _pan) {
        
        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer*)gestureRecognizer;
        CGPoint translation = [panGesture translationInView:self.view];
        CGPoint velocity = [panGesture velocityInView:self.view];
        if ([panGesture velocityInView:self.view].x < 600 && sqrt(translation.x * translation.x) / sqrt(translation.y * translation.y) > 1) {
            return YES;
        } 
        
        return NO;
    }

//    if (gestureRecognizer == _tap) {
//        
//        if (_root && (_menuFlags.showingRightView || _menuFlags.showingLeftView)) {
//            return CGRectContainsPoint(_root.view.frame, [gestureRecognizer locationInView:self.view]);
//        }
//        
//        return NO;
//        
//    }
    if (gestureRecognizer == _swip) {
        
        if (_root && (_menuFlags.showingRightView || _menuFlags.showingLeftView)) {
            return CGRectContainsPoint(_root.view.frame, [gestureRecognizer locationInView:self.view]);
        }
        
        return NO;
        
    }


    return YES;
   
}

//相同的手势是否被处理
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
//    if (gestureRecognizer==_tap) {
//        return YES;
//    }     
//   return YES;
    if ([otherGestureRecognizer.view isKindOfClass:[UITableView class]]) {
        return NO;
    }
return YES;
}


#pragma Internal Nav Handling 

- (void)resetNavButtons {
    if (!_root) return;
    
    UIViewController *topController = nil;
    if ([_root isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController *navController = (UINavigationController*)_root;
        if ([[navController viewControllers] count] > 0) {
            topController = [[navController viewControllers] objectAtIndex:0];
        }
        
    } else if ([_root isKindOfClass:[UITabBarController class]]) {
        
        UITabBarController *tabController = (UITabBarController*)_root;
        topController = [tabController selectedViewController];
        
    } else {
        
        topController = _root;
        
    }
    
    if (_menuFlags.canShowLeft) {
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_menu_icon.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showLeft:)];
        topController.navigationItem.leftBarButtonItem = button;
    } else {
        topController.navigationItem.leftBarButtonItem = nil;
    }
    
    if (_menuFlags.canShowRight) {
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_menu_icon.png"] style:UIBarButtonItemStyleBordered  target:self action:@selector(showRight:)];
        topController.navigationItem.rightBarButtonItem = button;
    } else {
        topController.navigationItem.rightBarButtonItem = nil;
    }
    
}

- (void)showShadow:(BOOL)val {
    if (!_root) return;
    
    _root.view.layer.shadowOpacity = val ? 0.8f : 0.0f;
    if (val) {
        _root.view.layer.cornerRadius = 4.0f;
        _root.view.layer.shadowOffset = CGSizeMake(0, 0);
        _root.view.layer.shadowRadius = 4.0f;
        _root.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
    }
    
}

- (void)showRootController:(BOOL)animated {
    
    [_tap setEnabled:NO];
    _root.view.userInteractionEnabled = YES;

    CGRect frame = _root.view.frame;
    frame.origin.x = 0.0f;

    BOOL _enabled = [UIView areAnimationsEnabled];
    if (!animated) {
        [UIView setAnimationsEnabled:NO];
    }
    
    [UIView animateWithDuration:.3 animations:^{
        
        _root.view.frame = frame;
        
    } completion:^(BOOL finished) {
        
        if (_left && _left.view.superview) {
            [_left.view removeFromSuperview];
        }
        
        if (_right && _right.view.superview) {
            [_right.view removeFromSuperview];
        }
        
        _menuFlags.showingLeftView = NO;
        _menuFlags.showingRightView = NO;

        [self showShadow:NO];
        
    }];
    
    if (!animated) {
        [UIView setAnimationsEnabled:_enabled];
    }
    
}

- (void)showLeftController:(BOOL)animated {
    if (!_menuFlags.canShowLeft) return;
    
    if (_right && _right.view.superview) {
        [_right.view removeFromSuperview];
        _menuFlags.showingRightView = NO;
    }
    
    if (_menuFlags.respondsToWillShowViewController) {
        [self.delegate menuController:self willShowViewController:self.leftViewController];
    }
    _menuFlags.showingLeftView = YES;
    [self showShadow:YES];

    UIView *view = self.leftViewController.view;
	CGRect frame = self.view.bounds;
	frame.size.width = kMenuFullWidth;
    view.frame = frame;
    [self.view insertSubview:view atIndex:0];
    [self.leftViewController viewWillAppear:animated];
    
    frame = _root.view.frame;
    frame.origin.x = CGRectGetMaxX(view.frame) - (kMenuFullWidth - kMenuDisplayedWidth);
    
    BOOL _enabled = [UIView areAnimationsEnabled];
    if (!animated) {
        [UIView setAnimationsEnabled:NO];
    }
    
    _root.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:.3 animations:^{
        _root.view.frame = frame;
    } completion:^(BOOL finished) {
        [_tap setEnabled:YES];
        
    }];
    
    if (!animated) {
        [UIView setAnimationsEnabled:_enabled];
    }
    
}



#pragma mark - Actions

- (void)showLeft:(id)sender {
    
    [self showLeftController:YES];
    
}

- (void)showRight:(id)sender {
    
    [self showRightController:YES];
    
}

//------------------wei.chen--------------------------
- (void)setEnableGesture:(BOOL)isEnable {
    [self.pan setEnabled:isEnable];
    [self.tap setEnabled:isEnable];//设置tap 显示左视图和右视图后  isenable 为yes  在这里  我就
    
}




#pragma mark - Root Controller Navigation

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    NSAssert((_root!=nil), @"no root controller set");
    
    UINavigationController *navController = nil;
    
    if ([_root isKindOfClass:[UINavigationController class]]) {
    
        navController = (UINavigationController*)_root;
    
    } else if ([_root isKindOfClass:[UITabBarController class]]) {
        
        UIViewController *topController = [(UITabBarController*)_root selectedViewController];
        if ([topController isKindOfClass:[UINavigationController class]]) {
            navController = (UINavigationController*)topController;
        }
        
    } 
    
    if (navController == nil) {
       
        NSLog(@"root controller is not a navigation controller.");
        return;
    }
    
   
    if (_menuFlags.showingRightView) {
        
        // if we're showing the right it works a bit different, we'll make a screen shot of the menu overlay, then push, and move everything over
        __block CALayer *layer = [CALayer layer];
        CGRect layerFrame = self.view.bounds;
        layer.frame = layerFrame;
        
        UIGraphicsBeginImageContextWithOptions(layerFrame.size, YES, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [self.view.layer renderInContext:ctx];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        layer.contents = (id)image.CGImage;
        
        [self.view.layer addSublayer:layer];
        [navController pushViewController:viewController animated:NO];
        CGRect frame = _root.view.frame;
        frame.origin.x = frame.size.width;
        _root.view.frame = frame;
        frame.origin.x = 0.0f;
        
        CGAffineTransform currentTransform = self.view.transform;
        
        [UIView animateWithDuration:0.25f animations:^{
            
            if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
                
                  self.view.transform = CGAffineTransformConcat(currentTransform, CGAffineTransformMakeTranslation(0, -[[UIScreen mainScreen] applicationFrame].size.height));
                
            } else {
                
                  self.view.transform = CGAffineTransformConcat(currentTransform, CGAffineTransformMakeTranslation(-[[UIScreen mainScreen] applicationFrame].size.width, 0));
            }
          
            
        } completion:^(BOOL finished) {
            
            [self showRootController:NO];
            self.view.transform = CGAffineTransformConcat(currentTransform, CGAffineTransformMakeTranslation(0.0f, 0.0f));
            [layer removeFromSuperlayer];
            
        }];
        
    } else {
        
        [navController pushViewController:viewController animated:animated];


        //2此分支  更改.m中的2个方法  -----4------------6----


        //2此分支  更改.m中的2个方法------6-----
        //3查看此次更改 在主线中更改------6------
        // 4 在分支中更改此文件
        //5 这是在主分支中 更改的

    }
    
}

- (void)pushCellBack:(UIGestureRecognizer *)gestureRecognizer
{
    NSLog(@"------");
    
    


    //1现在还是在master主线中  更改  -----4----------6----
    
    //2此分支  更改.m中的2个方法  -----4----------6----
    
    //3查看此次更改-----4-----
    
    

    //1现在还是在master主线中  更改  ----5----更改------6-----
    
    //2此分支  更改.m中的2个方法  ----5----更改------6-----
    
    //3查看此次更改 在主线中更改  ----5----更改
    
    
    //4 在分支中更改此文件  ----5----更改
    
//5 这是在主分支中 更改的

}


@end
