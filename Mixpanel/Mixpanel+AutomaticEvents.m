//
//  Mixpanel+AutomaticEvents.m
//  HelloMixpanel
//
//  Created by Sam Green on 2/23/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

#import "Mixpanel+AutomaticEvents.h"
#import "Mixpanel+AutomaticEventsSerialization.h"
#import "UIApplication+AutomaticEvents.h"
#import "UIViewController+AutomaticEvents.h"
#import "NSNotificationCenter+AutomaticEvents.h"
#import "AutomaticEventsConstants.h"
#import "MPSwizzle.h"
#import "MPLogger.h"

@implementation Mixpanel (AutomaticEvents)

static Mixpanel *gSharedAutomatedInstance = nil;
+ (instancetype)sharedAutomatedInstance {
    return gSharedAutomatedInstance;
}

+ (void)setSharedAutomatedInstance:(Mixpanel *)instance {
    gSharedAutomatedInstance = instance;
}

+ (void)addSwizzles {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Mixpanel *internalMixpanel = [[Mixpanel alloc] initWithToken:@"05b7195383129757cbf5172dbc5f67e1" andFlushInterval:60];
        
        NSError *error = NULL;
        
        [UIViewController mp_swizzleMethod:@selector(viewDidAppear:)
                                withMethod:@selector(mp_viewDidAppear:)
                                     error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle viewDidAppear: on UIViewController. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }

        [UIApplication mp_swizzleMethod:@selector(sendEvent:)
                             withMethod:@selector(mp_sendEvent:)
                                  error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle sendEvent: on UIAppplication. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }
        
        [UIApplication mp_swizzleMethod:@selector(sendAction:to:from:forEvent:)
                             withMethod:@selector(mp_sendAction:to:from:forEvent:)
                                  error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle sendAction:to:from:forEvent: on UIAppplication. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }
        
        [NSNotificationCenter mp_swizzleMethod:@selector(postNotification:)
                                    withMethod:@selector(mp_postNotification:)
                                         error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle postNotification: on NSNotificationCenter. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }
        [NSNotificationCenter mp_swizzleMethod:@selector(postNotificationName:object:)
                                    withMethod:@selector(mp_postNotificationName:object:)
                                         error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle postNotificationName:object: on NSNotificationCenter. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }
        [NSNotificationCenter mp_swizzleMethod:@selector(postNotificationName:object:userInfo:)
                                    withMethod:@selector(mp_postNotificationName:object:userInfo:)
                                         error:&error];
        if (error) {
            MixpanelError(@"Failed to swizzle postNotificationName:object:userInfo: on NSNotificationCenter. Details: %@", error);
            [internalMixpanel track:@"Error" properties:@{ @"Details": error.localizedDescription, @"Code": @(error.code) }];
            error = NULL;
        }
    });
}

#pragma mark - UIApplication
- (void)trackSendEvent:(UIEvent *)event {
    // Only track UIEvents for touches
    if (event.type != UIEventTypeTouches) return;
    
    NSDictionary *eventProperties = @{ kTypeKey: kTypeTouch };
    
    // Only track touches that are in the phase `Began`
    NSPredicate *touchBeganPredicate = [NSPredicate predicateWithBlock:^BOOL(UITouch * _Nonnull evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings) {
        return evaluatedObject.phase == UITouchPhaseBegan;
    }];
    NSSet<UITouch *> *beganTouches = [event.allTouches filteredSetUsingPredicate:touchBeganPredicate];
    for (UITouch *touch in beganTouches) {
        NSMutableDictionary *touchProperties = [[Mixpanel propertiesForDestination:touch.view] mutableCopy];
        [touchProperties addEntriesFromDictionary:eventProperties];
        [self track:kCollectEverythingEventName properties:touchProperties];
    }
}

- (void)trackSendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    MixpanelDebug(@"[CE] <%@> - %@ - %@ - %@ - %@", NSStringFromSelector(_cmd), NSStringFromSelector(action), to, from, event);
    
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    [eventProperties addEntriesFromDictionary:@{ kTypeKey: kTypeAction, kActionKey: NSStringFromSelector(action) }];
    [eventProperties addEntriesFromDictionary:[Mixpanel propertiesForDestination:to]];
    [eventProperties addEntriesFromDictionary:[Mixpanel propertiesForSource:from]];
    [self track:kCollectEverythingEventName properties:eventProperties];
}

#pragma mark - UIViewController
- (void)trackViewControllerAppeared:(UIViewController *)viewController {
    MixpanelDebug(@"[CE] <%@> - %@", NSStringFromSelector(_cmd), NSStringFromClass(viewController.class));
    
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    [eventProperties addEntriesFromDictionary:@{ kTypeKey: kTypeNavigation }];
    [eventProperties addEntriesFromDictionary:[Mixpanel propertiesForSourceViewController:viewController]];
    [self track:kCollectEverythingEventName properties:eventProperties];
}

#pragma mark - NSNotification
- (void)trackNotification:(NSNotification *)notification {
    [self trackNotificationName:notification.name object:nil userInfo:notification.userInfo];
}

- (void)trackNotificationName:(NSString *)name object:(id)object {
    [self trackNotificationName:name object:object userInfo:nil];
}

- (void)trackNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)info {
    MixpanelDebug(@"[CE] <%@> - %@ - %@ - %@", NSStringFromSelector(_cmd), name, object, info);
    
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    [eventProperties addEntriesFromDictionary:@{ kTypeKey: kTypeNotification, kNotificationNameKey: name }];
    [eventProperties addEntriesFromDictionary:[Mixpanel propertiesForSource:object]];
    if (info) {
        [eventProperties addEntriesFromDictionary:@{ kSourceInfoKey: info }];
    }
    [self track:kCollectEverythingEventName properties:eventProperties];
}

@end