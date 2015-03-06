#import "DPLDeepLinkRouter.h"
#import "DPLRouteMatcher.h"
#import "DPLDeepLink.h"
#import "DPLRouteHandler.h"
#import "DPLErrors.h"
#import <objc/runtime.h>

@interface DPLDeepLinkRouter ()

@property (nonatomic, copy) DPLApplicationCanHandleDeepLinksBlock applicationCanHandleDeepLinksBlock;

@property (nonatomic, strong) NSMutableOrderedSet *routes;
@property (nonatomic, strong) NSMutableDictionary *classesByRoute;
@property (nonatomic, strong) NSMutableDictionary *blocksByRoute;

@end


@implementation DPLDeepLinkRouter

- (instancetype)init {
    self = [super init];
    if (self) {
        _routes         = [NSMutableOrderedSet orderedSet];
        _classesByRoute = [NSMutableDictionary dictionary];
        _blocksByRoute  = [NSMutableDictionary dictionary];
    }
    return self;
}


#pragma mark - Configuration

- (BOOL)applicationCanHandleDeepLinks {
    if (self.applicationCanHandleDeepLinksBlock) {
        return self.applicationCanHandleDeepLinksBlock();
    }
    
    return YES;
}


#pragma mark - Registering Routes

- (void)registerHandlerClass:(Class <DPLRouteHandler>)handlerClass forRoute:(NSString *)route {

    if (handlerClass && [route length]) {
        [self.routes addObject:route];
        [self.blocksByRoute removeObjectForKey:route];
        self.classesByRoute[route] = handlerClass;
    }
}


- (void)registerBlock:(DPLRouteHandlerBlock)routeHandlerBlock forRoute:(NSString *)route {

    if (routeHandlerBlock && [route length]) {
        [self.routes addObject:route];
        [self.classesByRoute removeObjectForKey:route];
        self.blocksByRoute[route] = [routeHandlerBlock copy];
    }
}


#pragma mark - Registering Routes via Object Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {

    NSString *route = (NSString *)key;
    id obj = nil;
    
    if ([route isKindOfClass:[NSString class]] && route.length) {
        obj = self.classesByRoute[route];
        if (!obj) {
            obj = self.blocksByRoute[route];
        }
    }
    
    return obj;
}


- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    
    NSString *route = (NSString *)key;
    if (!([route isKindOfClass:[NSString class]] && route.length)) {
        return;
    }
    
    if (!obj) {
        [self.routes removeObject:route];
        [self.classesByRoute removeObjectForKey:route];
        [self.blocksByRoute removeObjectForKey:route];
    }
    else if ([obj isKindOfClass:NSClassFromString(@"NSBlock")]) {
        [self registerBlock:obj forRoute:route];
    }
    else if (class_isMetaClass(object_getClass(obj)) &&
             [obj isSubclassOfClass:[DPLRouteHandler class]]) {
        [self registerHandlerClass:obj forRoute:route];
    }
}


#pragma mark - Routing Deep Links

- (BOOL)handleURL:(NSURL *)url withCompletion:(DPLRouteCompletionBlock)completionHandler {
    
    if (!url) {
        [self completeRouteWithSuccess:completionHandler handled:NO targetViewController:nil error:nil];
        return NO;
    }
    
    if (![self applicationCanHandleDeepLinks]) {
        [self completeRouteWithSuccess:completionHandler handled:NO targetViewController:nil error:nil];
        return NO;
    }

    NSError      *error;
    DPLDeepLink  *deepLink;
    __block BOOL isHandled = NO;
    for (NSString *route in self.routes) {
        DPLRouteMatcher *matcher = [DPLRouteMatcher matcherWithRoute:route];
        deepLink = [matcher deepLinkWithURL:url];
        if (deepLink) {
            isHandled = [self handleRoute:route withDeepLink:deepLink error:&error completionHandler:completionHandler];
            break;
        }
    }
    
    if (!deepLink) {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"The passed URL does not match a registered route.", nil) };
        error = [NSError errorWithDomain:DPLErrorDomain code:DPLRouteNotFoundError userInfo:userInfo];
    }
    
    if (!isHandled) {
        [self completeRouteWithSuccess:completionHandler
                               handled:isHandled
                  targetViewController:nil
                                 error:error];
    }
    return isHandled;
}


- (BOOL)handleRoute:(NSString *)route
       withDeepLink:(DPLDeepLink *)deepLink
              error:(NSError *__autoreleasing *)error
  completionHandler:(DPLRouteCompletionBlock)completionHandler {
    
    id handler = self[route];
    
    if ([handler isKindOfClass:NSClassFromString(@"NSBlock")]) {
        DPLRouteHandlerBlock routeHandlerBlock = handler;
        routeHandlerBlock(deepLink);
    }
    else if (class_isMetaClass(object_getClass(handler)) &&
             [handler isSubclassOfClass:[DPLRouteHandler class]]) {
        DPLRouteHandler *routeHandler = [[handler alloc] init];

        if (![routeHandler shouldHandleDeepLink:deepLink]) {
            return NO;
        }
        
        UIViewController *presentingViewController = nil;
        NSURL * presentingLink = [routeHandler URLForPresentingDeepLink:deepLink];
        if (presentingLink != nil) {
            
            // async
            [self handleURL:presentingLink withCompletion:^(BOOL handled, NSError *handleURLError, UIViewController<DPLTargetViewController> *targetViewController) {
                
                if (handleURLError) {
                    
                    [self completeRouteWithSuccess:completionHandler
                                           handled:NO
                              targetViewController:targetViewController
                                             error:handleURLError];
                } else {
                    
                    NSError *presentError;
                    BOOL handled = [self presentRoute:routeHandler
                             presentingViewController:targetViewController
                                             deepLink:deepLink
                                                error:&presentError
                                    completionHandler:completionHandler];
                    
                    if (!handled) {
                        [self completeRouteWithSuccess:completionHandler
                                               handled:NO
                                  targetViewController:targetViewController
                                                 error:presentError];
                    }
                }
            }];
            
            return  YES;
        }
        
        return [self presentRoute:routeHandler
             presentingViewController:presentingViewController
                             deepLink:deepLink
                                error:error
                completionHandler:completionHandler];
    }

    return YES;
}



- (BOOL)presentRoute:(DPLRouteHandler*)routeHandler
presentingViewController:(UIViewController*)presentingViewController
            deepLink:(DPLDeepLink*)deepLink
               error:(NSError *__autoreleasing *)error
   completionHandler:(DPLRouteCompletionBlock)completionHandler {
    
    if (presentingViewController == nil) {
        presentingViewController = [routeHandler viewControllerForPresentingDeepLink:deepLink];
    }
    
    [routeHandler targetViewController:deepLink completionHandler:^(UIViewController<DPLTargetViewController> *targetViewController) {
        
        if (targetViewController) {
            [routeHandler presentTargetViewController:targetViewController
                                     inViewController:presentingViewController
                                             deepLink:deepLink
                                    completionHandler:^(UIViewController<DPLTargetViewController> *targetViewController) {
                                        [self completeRouteWithSuccess:completionHandler handled:YES targetViewController:targetViewController error:nil];
                                    }];
        }
        else
        {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"The matched route handler does not specify a target view controller.", nil)};
            
            NSError * err = [NSError errorWithDomain:DPLErrorDomain code:DPLRouteHandlerTargetNotSpecifiedError userInfo:userInfo];
            if (error) {
                *error = err;
            }
            
            [self completeRouteWithSuccess:completionHandler handled:NO targetViewController:nil error:err];
        }
    }];
    
    return YES;
}

- (void)completeRouteWithSuccess:(DPLRouteCompletionBlock)handler
                         handled:(BOOL)handled
            targetViewController:(UIViewController<DPLTargetViewController>*)targetViewController
                           error:(NSError *)error {
    
    if (!handler) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(handled, error, targetViewController);
    });
}

@end


