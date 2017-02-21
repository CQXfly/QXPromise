//
//  QXPromise.m
//  jupiter
//
//  Created by 崇庆旭 on 2016/8/3.
//  Copyright © 2016年 dev. All rights reserved.
//

#import "QXPromise.h"

void blockCleanUp(__strong void(^*block)(void)) {
    (*block)();
}

typedef QXPromise*(^QXPromiseWorkEventHandler)();
@interface QXPromise ()

@property (nonatomic,copy) void (^done)();

@property (nonatomic,strong) id data;

@property (nonatomic,assign) BOOL called;

@property (nonatomic,assign) QXPromiseResoverStatus status;
@property (nonatomic,strong) NSMutableArray *fulfillQueue;
@property (nonatomic,strong) NSMutableArray *rejectQueue;


@end

@implementation QXPromise

- (void)dealloc{
    
}

- (instancetype)init {
    if (self = [super init]) {
        
        self.status       = QXPromiseResoverStatusPending;
        self.fulfillQueue = [NSMutableArray arrayWithCapacity:0];
        self.rejectQueue  = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

+ (QXPromise *)promise {
    QXPromise * promise = [[QXPromise alloc] init];
    [promise setup];
    return promise;
}

/**
 *  关键链
 *
 *  @param resolver
 *
 *  @return promise对象
 */
- (QXPromise *)chainNodePromiseWithResover:(QXPromise *)resolver {
    QXPromise * promise = [[QXPromise alloc] init];
    promise.resover = resolver ? : self;
    [promise setup];
    return promise;
}

- (void)setup {
    __weak typeof(self) weakSelf = self;
    
    self.then = ^id(QXPromiseEventHandler onFulfilled,QXPromiseEventHandler onRejected){
        __strong typeof(weakSelf) self = weakSelf;
        return [self then:onFulfilled onRejected:onRejected];
        
    };
    
    self.next = (id)^(QXPromiseEventHandler onFulfilled) {
        __strong typeof(weakSelf) self = weakSelf;
        return [self next:onFulfilled];
    };
    
    self.catch = ^QXPromise*(void(^onRejected)(id reason)) {
        __strong typeof(weakSelf) self = weakSelf;
       
        id(^wrapedOnRejected)(id reason) = ^id(id reason){
            QXPromiseWorkEventHandler work = ^id(){
                onRejected(reason);
                return nil;
            };
            return work();
        };
        
        QXPromise * resover = self.resover ? : self;
        [self addListener:QXPromiseResoverStatusRejected callback:wrapedOnRejected];
        [resover addListener:QXPromiseResoverStatusRejected callback:wrapedOnRejected];
        return self;
    };
    
    
}

- (QXPromise *)then:(QXPromiseEventHandler)onFulfilled onRejected:(QXPromiseEventHandler)onRejected {
    
    QXPromise * promise = [self chainNodePromiseWithResover:self.resover];
    
    __weak typeof(self) weakPromise = promise;
    if (onFulfilled) {
        onFulfilled = [QXPromise wrapPromise:promise callback:onFulfilled];
    }else {
        onFulfilled = (id)^(id data){
            __strong typeof(weakPromise) promise = weakPromise;
            return [promise fulfill:data];
        };
    }
    
    [self addListener:QXPromiseResoverStatusFulfilled callback:onFulfilled];
    
    if (onRejected) {
        onRejected = [QXPromise wrapPromise:promise callback:onRejected];
    } else {
        onRejected = (id)^(id reason){
            __strong typeof(weakPromise) promise = weakPromise;
            return [promise reject:reason];
        };
    }
    [self addListener:QXPromiseResoverStatusRejected callback:onRejected];
    
    if (self.run) {
        self.run();
    }
    
    return promise;
}


- (QXPromise *)next:(QXPromiseEventHandler)onFulfilled {
    QXPromise *promise = [self chainNodePromiseWithResover:self.resover];
    __weak typeof(self) weakPromise = promise;
    if (onFulfilled) {
        onFulfilled = [QXPromise wrapPromise:promise callback:onFulfilled];
    } else {
        onFulfilled = (id)^(id data){
            __strong typeof(weakPromise) promise = weakPromise;
            return [promise fulfill:data];
        };
    }
    
    [self addListener:QXPromiseResoverStatusFulfilled callback:onFulfilled];
    
    [self addListener:QXPromiseResoverStatusRejected  callback:^id(id reason){
       
        __strong typeof(weakPromise) promise = weakPromise;
        QXPromise * resolve = promise.resover;
        if (resolve && resolve.status == QXPromiseResoverStatusFulfilled) {
            resolve.status = QXPromiseResoverStatusPending;
        }
        return [resolve reject:reason];
    }];
    
    
    onExit  {
        if(self.run){
            self.run();
        }
    };
    
    return promise;
    
}


- (void)addListener:(QXPromiseResoverStatus)status callback:(QXPromiseEventHandler)callback {
    if (self.status == status) {
        callback(self.data);
    } else if (status == QXPromiseResoverStatusFulfilled) {
        [self.fulfillQueue insertObject:callback atIndex:0];
    } else if (status == QXPromiseResoverStatusRejected) {
        [self.rejectQueue insertObject:callback atIndex:0];
    }
}

- (id)reject:(id)reason {
    if (self.status != QXPromiseResoverStatusRejected) {
        return nil;
    }
    self.data = reason;
    self.status = QXPromiseResoverStatusRejected;
    return [self emit];
}

- (id)fulfill:(id)data {
    if (self.status != QXPromiseResoverStatusPending) {
        return nil;
    }
    self.data = data;
    self.status = QXPromiseResoverStatusFulfilled;
    return [self emit];
}

/**
 *  emit all callbacks but only return the first object
 *
 *  @return promise object
 */
- (id)emit{
    NSMutableArray * items = self.status == QXPromiseResoverStatusFulfilled ? self.fulfillQueue : self.rejectQueue;
    if (!items.count) {
        return nil;
    }
    
    QXPromiseEventHandler callback = items.lastObject;
    for(int i = 0 ; i < items.count - 1; i ++){
        QXPromiseEventHandler callback = items[i];
        callback(self.data);
    }
    
    onExit {
        [items removeAllObjects];
    };
    
    return callback(self.data);
    
}

+ (QXPromiseEventHandler)wrapPromise:(QXPromise *)promise callback:(QXPromiseEventHandler)callback {
    
    
    QXPromiseEventHandler hander = ^id(id data) {
        QXPromiseWorkEventHandler  work = ^id(){
            id res = callback(data);
            if (res == promise) {
                return [QXPromise rejected];
            }
            return [QXPromise resolve:promise value:res];
        };
        
        return work;
        
    };
    
    return hander;
    
}

/**
 *  proise
 *
 *  @param promise
 *  @param value   promise或者是数据
 *
 *  @return 下一promise or data
 */
+ (id)resolve:(QXPromise *)promise value:(QXPromise *)value {
    __weak typeof(promise) weakPromise = promise;
    __weak typeof(value)   weakValue   = value;
    
    QXPromiseEventHandler onFulfilled = ^id (id data){
        if (weakPromise && !weakPromise.called) {
            weakPromise.called = YES;
            return [QXPromise resolve:weakPromise value:data];
        }
        return [QXPromise fulfilled];
    };
    
    QXPromiseEventHandler onRejected = ^id(id reason){
        if (weakPromise && !weakPromise.called ){
            weakPromise.called = YES;
            return [weakPromise reject:reason];
        }
        return [QXPromise rejected];
    };
    
    QXPromiseWorkEventHandler work = ^id(){
        __strong typeof(weakPromise) promise = weakPromise;
        __strong typeof(weakValue)   value   = weakValue;
        
        if ([value isKindOfClass:QXPromise.class] && [value respondsToSelector:@selector(then)]) {
            return value.then(onFulfilled,onRejected);
        } else {
            return [promise fulfill:value];
        }
    };
    
    return work();
}

+ (QXPromise*)all:(NSArray<QXPromise *> *)promises {
    QXPromise * resolver = [QXPromise promise];
    
    __block NSInteger resolvedCount = 0;
    NSMutableArray * res = [NSMutableArray arrayWithCapacity:promises.count];
    
    QXPromiseEventHandler(^createResolvedHander)(NSInteger) = ^QXPromiseEventHandler(NSInteger index){
        return ^id(id data){
            [res addObject:data];
            if (++resolvedCount >= promises.count) {
                return [resolver fulfill:res];
            }
            return nil;
        };
    };
    
    QXPromiseEventHandler rejectedHander = ^id(id reason){
        return [resolver reject:reason];
    };
    
    [promises enumerateObjectsUsingBlock:^(QXPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSAssert([obj isKindOfClass:QXPromise.class], @"require isntance of qxpromise");
        obj.then(createResolvedHander(idx),rejectedHander);
    }];
    
    return resolver;
}

+ (QXPromise *)fulfilled {
    QXPromise * promise = [QXPromise promise];
    promise.status = QXPromiseResoverStatusFulfilled;
    return promise;
}

+ (QXPromise *)rejected {
    QXPromise * promise = [QXPromise promise];
    promise.status = QXPromiseResoverStatusRejected;
    return promise;
}

#pragma mark - getter
-(void(^)())done{
    if (!_done) {
        __weak typeof(self) weakSelf = self;
        _done = [^(){
            __strong typeof(weakSelf) self = weakSelf;
            self.status = QXPromiseResoverStatusFulfilled;
        } copy];
    }
    return _done;
}

@end
