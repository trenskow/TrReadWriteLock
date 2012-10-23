//
//  NSObject+SUGULibraryAdditions.m
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <objc/runtime.h>
#import <pthread.h>

#import "TrLock.h"
#import "TrReadWriteLock.h"

#import "NSObject+TrReadWriteLockAdditions.h"

pthread_mutex_t _lockMutex = PTHREAD_MUTEX_INITIALIZER;

const char NSObjectReadWriteLockKey;
const char NSObjectLockKey;

@implementation NSObject (TrReadWriteLockAdditions)

#pragma mark - Public Properties

- (TrLock *)lock {
    
    TrLock* lock;
    
    pthread_mutex_lock(&_lockMutex);
    if (!(lock = objc_getAssociatedObject(self, &NSObjectLockKey))) {
        lock = [[TrLock alloc] init];
        objc_setAssociatedObject(self, &NSObjectLockKey, lock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#       if !__has_feature(objc_arc)
        [lock release];
#       endif
    }
    pthread_mutex_unlock(&_lockMutex);
    
    return lock;
    
}

- (TrReadWriteLock *)rwLock {
    
    TrReadWriteLock* rwLock;
    
    pthread_mutex_lock(&_lockMutex);
    if (!(rwLock = objc_getAssociatedObject(self, &NSObjectReadWriteLockKey))) {
        rwLock = [[TrReadWriteLock alloc] init];
        objc_setAssociatedObject(self, &NSObjectReadWriteLockKey, rwLock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#       if !__has_feature(objc_arc)
        [rwLock release];
#       endif
    }
    pthread_mutex_unlock(&_lockMutex);
    
    return rwLock;
    
}

#pragma mark - Public Methods

- (void)locked:(void (^)())block {
    
    [self.lock lock];
    block();
    [self.lock unlock];
    
}

- (void)readLocked:(void (^)())block {
    
    [self.rwLock lockRead];
    block();
    [self.rwLock unlockRead];
    
}

- (void)writeLocked:(void (^)())block {
    
    [self.rwLock lockWrite];
    block();
    [self.rwLock unlockWrite];
    
}

@end
