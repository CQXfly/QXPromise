//
//  QXPromise.h
//  jupiter
//
//  Created by 崇庆旭 on 2016/8/3.
//  Copyright © 2016年 dev. All rights reserved.
//

#import <Foundation/Foundation.h>

void blockCleanUp(__strong void(^*block)(void));

#ifndef onExit
#define onExit\
    __strong void(^block)(void) __attribute__((cleanup(blockCleanUp), unused)) = ^
#endif

// promise status
typedef NS_ENUM(NSUInteger,QXPromiseResoverStatus) {
    QXPromiseResoverStatusPending,
    QXPromiseResoverStatusFulfilled,
    QXPromiseResoverStatusRejected,
};

/**事件处理block*/
typedef id(^QXPromiseEventHandler)(id);


@interface QXPromise : NSObject

@property (nonatomic,copy) QXPromise*(^then)(QXPromiseEventHandler,QXPromiseEventHandler);

@property (nonatomic,copy) QXPromise *(^next)(QXPromiseEventHandler);

/**  catch 异常 不能放在链首位()*/
@property (nonatomic,copy) QXPromise *(^catch)(void(^)(id reason));

@property (nonatomic, copy, readonly) void(^done)();

@property (nonatomic, copy) dispatch_block_t run;

@property (nonatomic, weak) QXPromise* resover;

+ (QXPromise *)all:(NSArray<QXPromise *> *)promises;

+ (QXPromise *)promise;

+ (QXPromise *)fulfilled;

+ (QXPromise *)rejected;

- (id)fulfill:(id)data;

- (id)reject:(id)reason;


@end
