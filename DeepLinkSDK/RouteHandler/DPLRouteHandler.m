#import "DPLRouteHandler.h"
#import "DPLRouteHandlerProtocol.h"
#import "UINavigationController+DPL.h"

@interface DPLRouteHandler () <DPLRouteHandlerProtocol>

@end

@implementation DPLRouteHandler

- (BOOL)shouldHandleDeepLink:(DPLDeepLink *)deepLink {
    return YES;
}


- (BOOL)preferModalPresentation {
    return NO;
}


- (UIViewController <DPLTargetViewController> *)targetViewController {
    return nil;
}


- (UIViewController *)viewControllerForPresentingDeepLink:(DPLDeepLink *)deepLink {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}


- (void)presentTargetViewController:(UIViewController <DPLTargetViewController> *)targetViewController
                   inViewController:(UIViewController *)presentingViewController {
    
    if ([self preferModalPresentation] ||
        ![presentingViewController isKindOfClass:[UINavigationController class]]) {
        
        [presentingViewController presentViewController:targetViewController animated:NO completion:NULL];
    }
    else if ([presentingViewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController * navigationViewController = (UINavigationController*)presentingViewController;
        [navigationViewController placeTargetViewController:targetViewController];
    }
}

#pragma mark - DPLRouteHandlerProtocol

- (UIViewController <DPLTargetViewController> *)targetViewController:(DPLDeepLink *)deepLink {
    return [self targetViewController];
}

- (BOOL)preferModalPresentationWithDeepLink:(DPLDeepLink *)deepLink {
    return [self preferModalPresentation];
}

- (void)presentTargetViewController:(UIViewController *)targetViewController
                   inViewController:(UIViewController *)presentingViewController
                           deepLink:(DPLDeepLink *)deepLink
                  completionHandler:(DPLTargetViewControllerCompletionHandler)completionHandler
{
    [self presentTargetViewController:targetViewController
                            inViewController:presentingViewController];
    
    if (completionHandler) {
        completionHandler(targetViewController);
    }
}

@end
