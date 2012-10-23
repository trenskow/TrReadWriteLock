//
//  TrCondition.m
//  TrReadWriteLock
//
//  Created by Kristian Trenskow on 9/11/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <sys/time.h>
#import <errno.h>
#import <pthread.h>

#import "TrLock+Protected.h"

#import "TrCondition.h"

@interface TrCondition () {
    
    pthread_cond_t _cond;
    
}

@end

@implementation TrCondition

#pragma mark - Public Allocation / Dealloction

- (id)init {
    
    if ((self = [super init]))
        pthread_cond_init(&_cond, NULL);
    
    return self;
    
}

- (void)dealloc {
    
    pthread_cond_destroy(&_cond);
    
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
    
}

#pragma mark - Public Methods

- (void)waitWithLock:(TrLock *)lock {
    
    pthread_cond_wait(&_cond, lock.mutex);
    
}

- (BOOL)waitWithLock:(TrLock *)lock andTimeoutInterval:(NSTimeInterval)timeInterval {
    
    struct timeval tv;
    
    gettimeofday(&tv, NULL);
    
    int micro = timeInterval * 1000;
    while (micro >= 1000000) {
        tv.tv_sec++;
        micro -= 1000000;
    }
    
    struct timespec req = {tv.tv_sec, (tv.tv_usec + micro) * 1000};
    
    return (pthread_cond_timedwait(&_cond, lock.mutex, &req) == ETIMEDOUT);
    
}

- (void)signal {
    
    pthread_cond_signal(&_cond);
    
}

- (void)broadcast {
    
    pthread_cond_broadcast(&_cond);
    
}

@end
