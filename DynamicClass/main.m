//
//  main.m
//  DynamicClass
//
//  Created by shaohua on 12/13/18.
//  Copyright © 2018 United Nations. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <objc/runtime.h>
#import <objc/message.h>

static void forwardInvocation(id self, SEL _cmd, NSInvocation *invoke) {
    NSLog(@"self: %@\n_cmd: %@\ninvoke: %@", self, NSStringFromSelector(_cmd), [invoke debugDescription]);
}

int main(int argc, char * argv[]) {
    // arguments begin
    Class supercls = [NSObject class];
    char *clsname = "AppDelegate";
    Protocol *p = @protocol(UIApplicationDelegate); // 注1 PS.1
    SEL selector = @selector(application:didFinishLaunchingWithOptions:);
    // arguments end

    Class cls = objc_allocateClassPair(supercls, clsname, 0);
    objc_registerClassPair(cls);
    class_addProtocol(cls, p);
    class_addMethod(cls, @selector(forwardInvocation:), (IMP)forwardInvocation, "v@:@");
    IMP fp = _objc_msgForward; // PS.2
    class_addMethod(cls, selector, fp, NULL); // PS.3

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
