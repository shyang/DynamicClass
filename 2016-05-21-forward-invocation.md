---
layout: post
title: 动态生成一个类，并拦截对其发送的消息
---

Create a class dynamically and forward messages

生成一个默认 iOS 项目，删除 `AppDelegate.h` 与 `AppDelegate.m`，修改 `main.c`：

```c
#import <objc/runtime.h>

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
```

此时运行应该会 crash：'Unable to instantiate the UIApplication delegate instance. No class named AppDelegate is loaded.'

因为 AppDelegate 的 implementation 被删除了，没有这个 class。

动态创建的方法：

```
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
```

注1：必须 add protocol 才能使后面 methodSignatureForSelector: 得到非 nil 的结果。

supercls、clsname、protocol、selector 是动态的参数，后面的代码基本不变。

Log 的输出是：

```console
self: <AppDelegate: 0x78e7c120>
_cmd: forwardInvocation:
invoke: <NSInvocation: 0x78eccfe0>
    return value: {c} 0 ''
    target: {@} 0x78e7c120
    selector: {:} application:didFinishLaunchingWithOptions:
    argument 2: {@} 0x78f69dd0
    argument 3: {@} 0x0
```

可以看到全局函数 `forwardInvocation` 被调用到了，系统对 `-[AppDelegate application:didFinishLaunchingWithOptions:]` 的调用被包装成了一个 `NSInvocation` 对象。

通过这种方式，系统的回调都能被捕捉起来，包装为 `NSInvocation` 后，可以有各种应用，如转发给另一个对象处理、转发给某个脚本解释器处理……等等。




#### PS.1 @protocol(UIApplicationDelegate) 与 objc_getProtocol(@"UIApplicationDelegate")

后者更通用，protocol 可作为参数传入，但项目内若未使用过该 protocol，get 的结果会是 NULL。

workaround: 在某处集中使用一次所有的 protocol。

```objc
@interface AllProtocols : NSObject <
  ProtocolA,
  ProtocolB,
  ...
>
@end

// no need to create empty implementations
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
@implementation AllProtocols // must has a body, otherwise protocols won't load
@end
#pragma clang diagnostic pop

```

#### PS.2 `_objc_msgForward` 与 `_objc_msgForward_stret`

TARGET_CPU_ARM64 下后者不存在，但其他情况要区分一个方法的返回值是非是一个 struct，即 stret。

大于 iOS 7 可使用一个私有函数：

```objc
@interface NSMethodSignature ()
-[NSMethodSignature _isHiddenStructRet]
@end

    // ...
#if !TARGET_CPU_ARM64
    if ([sig _isHiddenStructRet]) { // iOS 7 用 [sig methodReturnLength] > 8 ？
        fp = _objc_msgForward_stret;
    }
#endif
```

#### PS.3
`class_addMethod` 第4个参数不应传 NULL，可使用一个私有函数获取：

```objc
@interface NSMethodSignature ()
- (NSString *)_typeString;
@end

    // ...
    NSMethodSignature *sig = [cls instanceMethodSignatureForSelector:selector];
    const char *types = [sig _typeString].UTF8String;
    class_addMethod(cls, selector, fp, types);
```
