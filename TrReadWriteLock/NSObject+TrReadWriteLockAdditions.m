//
//  NSObject+SUGULibraryAdditions.m
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <objc/runtime.h>
#import <pthread.h>

#import "TrReadWriteLock.h"

#import "NSObject+TrReadWriteLockAdditions.h"

pthread_mutex_t _lockMutex = PTHREAD_MUTEX_INITIALIZER;

const char NSObjectLockKey;

@implementation NSObject (TrReadWriteLockAdditions)

#pragma mark - Public Properties

- (TrReadWriteLock *)lock {
    
    TrReadWriteLock* lock;
    
    pthread_mutex_lock(&_lockMutex);
    if (!(lock = objc_getAssociatedObject(self, &NSObjectLockKey))) {
        lock = [[TrReadWriteLock alloc] init];
        objc_setAssociatedObject(self, &NSObjectLockKey, lock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#       if !__has_feature(objc_arr)
        [lock release];
#       endif
    }
    pthread_mutex_unlock(&_lockMutex);
    
    return lock;
    
}

#pragma mark - Public Methods

- (void)readLocked:(void (^)())block {
    
    [self.lock lockRead];
    block();
    [self.lock unlockRead];
    
}

- (void)writeLocked:(void (^)())block {
    
    [self.lock lockWrite];
    block();
    [self.lock unlockWrite];
    
}

@end
