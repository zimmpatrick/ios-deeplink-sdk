#import "DPLRouteHandler.h"

@implementation DPLRouteHandler

- (BOOL)shouldHandleDeepLink:(DPLDeepLink *)deepLink {
    return YES;
}


- (BOOL)preferModalPresentation:(DPLDeepLink *)deepLink {
    return NO;
}

- (void)targetViewController:(DPLDeepLink *)deepLink
           completionHandler:(DPLTargetViewControllerCompletionHandler)completionHandler {

    if (completionHandler) {
        completionHandler(nil);
    }
}

- (UIViewController *)viewControllerForPresentingDeepLink:(DPLDeepLink *)deepLink {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

- (void)presentTargetViewController:(UIViewController <DPLTargetViewController> *)targetViewController
                   inViewController:(UIViewController *)presentingViewController
                           deepLink:(DPLDeepLink *)deepLink
                  completionHandler:(DPLTargetViewControllerCompletionHandler)completionHandler {
    
    if ([self preferModalPresentation:deepLink] ||
        ![presentingViewController isKindOfClass:[UINavigationController class]]) {
        
        [presentingViewController presentViewController:targetViewController animated:NO completion:^{
            if (completionHandler) {
                completionHandler(targetViewController);
            }
        }];
        
        return;
    }
    else if ([presentingViewController isKindOfClass:[UINavigationController class]]) {
        
        [self placeTargetViewController:targetViewController
                 inNavigationController:(UINavigationController *)presentingViewController];
    }
    
    if (completionHandler) {
        completionHandler(targetViewController);
    }
}


#pragma mark - Private

- (void)placeTargetViewController:(UIViewController *)targetViewController
           inNavigationController:(UINavigationController *)navigationController {
    
    if ([navigationController.viewControllers containsObject:targetViewController]) {
        [navigationController popToViewController:targetViewController animated:NO];
    }
    else {
        
        for (UIViewController *controller in navigationController.viewControllers) {
            if ([controller isMemberOfClass:[targetViewController class]]) {
                
                [navigationController popToViewController:controller animated:NO];
                [navigationController popViewControllerAnimated:NO];
                
                if ([controller isEqual:navigationController.topViewController]) {
                    [navigationController setViewControllers:@[targetViewController] animated:NO];
                }
                
                break;
            }
        }
        
        if (![navigationController.topViewController isEqual:targetViewController]) {
            [navigationController pushViewController:targetViewController animated:NO];
        }
    }
}

@end
