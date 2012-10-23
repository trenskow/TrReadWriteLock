//
//  TrLock.m
//  TrReadWriteLock
//
//  Created by Kristian Trenskow on 9/11/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <pthread.h>

#import "TrLock+Protected.h"

@interface TrLock () {
    
    pthread_mutex_t _mutex;
    
}

@end

@implementation TrLock

#pragma mark - Public Allocation / Deallocation

- (id)init {
    
    if ((self = [super init])) {
        
        pthread_mutexattr_t attr;
        
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        
        pthread_mutex_init(&_mutex, &attr);
        
        pthread_mutexattr_destroy(&attr);
        
    }
    
    return self;
    
}

- (void)dealloc {
    
    pthread_mutex_destroy(&_mutex);
    
#   if !__has_feature(objc_arc)
    [super dealloc];
#   endif
    
}

#pragma mark - Protected Properties

- (pthread_mutex_t *)mutex {
    
    return &_mutex;
    
}

#pragma mark - Public Methods

- (void)lock {
    
    pthread_mutex_lock(&_mutex);
    
}

- (void)unlock {
    
    pthread_mutex_unlock(&_mutex);
    
}

@end
