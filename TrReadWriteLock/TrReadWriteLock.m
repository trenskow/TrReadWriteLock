//
//  TrReadWriteLock.m
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <pthread.h>

#import "NSObject+TrReadWriteLockAdditions.h"

#import "TrCondition.h"

#import "TrReadWriteLock.h"

typedef struct {
    
    pthread_t thread;
    NSUInteger readCount;
    NSUInteger writeCount;
    BOOL awaitingWrite;
    
} TrReadWriteLockThreadInfo;

@interface TrReadWriteLock () {
    
    TrCondition* _readCondition;
    TrCondition* _writeCondition;
    
    TrReadWriteLockThreadInfo* _threadInfo;
    NSUInteger _threadInfoCount;
    
}

@property (nonatomic,readonly) TrReadWriteLockThreadInfo* _threadInfo;

@property (nonatomic,setter=_setThreadReadCount:) NSUInteger _threadReadCount;
@property (nonatomic,setter=_setThreadWriteCount:) NSUInteger _threadWriteCount;
@property (nonatomic,setter=_setThreadIsAwaitingWriteLock:) NSUInteger _threadIsAwaitingWriteLock;

@property (nonatomic,readonly) NSUInteger _globalReadCount;
@property (nonatomic,readonly) NSUInteger _globalWriteCount;
@property (nonatomic,readonly) NSUInteger _awaitingWriteLocks;

- (void)_deleteThreadInfo;

@end

@implementation TrReadWriteLock

#pragma mark - Public Allocation / Deallocation

- (id)init {
    
    if ((self = [super init])) {
        
        _readCondition = [[TrCondition alloc] init];
        _writeCondition = [[TrCondition alloc] init];
        
    }
    
    return self;
    
}

- (void)dealloc {
    
    [self locked:^{
        
        NSAssert(!self._globalReadCount, @"Lock was deallocated while being read locked");
        NSAssert(!self._globalWriteCount, @"Lock was deallocated while being write locked");
        NSAssert(!self._awaitingWriteLocks, @"Lock was deallocated while having pending write locks");
        
        free(_threadInfo);
        
    }];
    
#   if !__has_feature(objc_arc)
    [super dealloc];
#   endif
    
}

#pragma mark - Protected Properties

- (TrReadWriteLockThreadInfo *)_threadInfo {
    
    __block TrReadWriteLockThreadInfo* threadInfo;
    
    [self locked:^{
        
        for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
            if (pthread_equal(_threadInfo[i].thread, pthread_self())) {
                threadInfo = &_threadInfo[i];
                return;
            }

        _threadInfo = (TrReadWriteLockThreadInfo *)realloc(_threadInfo, sizeof(TrReadWriteLockThreadInfo) * (_threadInfoCount + 1));
        
        threadInfo = &_threadInfo[_threadInfoCount++];
        
        bzero(threadInfo, sizeof(TrReadWriteLockThreadInfo));
        threadInfo->thread = pthread_self();
        
    }];
    
    return threadInfo;
    
}

- (NSUInteger)_threadReadCount {
    
    return [self _threadInfo]->readCount;
    
}

- (void)_setThreadReadCount:(NSUInteger)threadReadCount {
    
    [self locked:^{
        
        [self _threadInfo]->readCount = threadReadCount;
        
    }];
    
}

- (NSUInteger)_threadWriteCount {
    
    return [self _threadInfo]->writeCount;
    
}

- (void)_setThreadWriteCount:(NSUInteger)threadWriteCount {
    
    [self locked:^{
        
        [self _threadInfo]->writeCount = threadWriteCount;
        
    }];
    
}

- (NSUInteger)_threadIsAwaitingWriteLock {
    
    return [self _threadInfo]->awaitingWrite;
    
}

- (void)_setThreadIsAwaitingWriteLock:(NSUInteger)threadIsAwaitingWriteLock {
    
    [self locked:^{
        
        [self _threadInfo]->awaitingWrite = threadIsAwaitingWriteLock;
        
    }];
    
}

- (NSUInteger)_globalReadCount {
    
    __block NSUInteger globalReadCount = 0;
    
    [self locked:^{
        
        for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
            globalReadCount += (!_threadInfo[i].writeCount && !_threadInfo[i].awaitingWrite ? _threadInfo[i].readCount : 0);
        
    }];
    
    return globalReadCount;    
    
}

- (NSUInteger)_globalWriteCount {
    
    __block NSUInteger globalWriteCount = 0;
    
    [self locked:^{
        
        for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
            globalWriteCount += _threadInfo[i].writeCount;
        
    }];
    
    return globalWriteCount;
    
}

- (NSUInteger)_awaitingWriteLocks {
    
    __block NSUInteger awaitingWriteLocks = 0;
    
    [self locked:^{
        
        for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
            awaitingWriteLocks += (_threadInfo[i].awaitingWrite ? 1 : 0);
        
    }];
    
    return awaitingWriteLocks;
    
}

#pragma mark - Private Methods

- (void)_deleteThreadInfo {
    
    [self locked:^{
        
        for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
            if (pthread_equal(_threadInfo[i].thread, pthread_self())) {
                
                for (NSUInteger c = i ; c < _threadInfoCount - 1 ; c++)
                    _threadInfo[c] = _threadInfo[c + 1];
                
                _threadInfoCount--;
                
                break;
                
            }
        
    }];
    
}

#pragma mark - Public Methods

- (void)lockRead {
    
    [self locked:^{
        
        // Ignore read lock requests if thread already holds the write lock.
        if (!self._threadWriteCount) {
            
            // If threads are currently writing - or we do not already hold any read locks and a write lock is pending -
            //   wait for the write locks to finish.
            if (self._globalWriteCount || (!self._threadReadCount && self._awaitingWriteLocks))
                [_readCondition waitWithLock:self.lock];
            
            self._threadReadCount++;
            
        }
                
    }];
        
}

- (void)unlockRead {
    
    [self locked:^{
        
        // Ignore read lock release request if thread already holds the write lock.
        if (!self._threadWriteCount) {
            
            self._threadReadCount--;
            
            // If we were the last read lock, signal any pending write locks.
            if (!self._globalReadCount)
                [_writeCondition signal];
            
            if (!self._threadReadCount && !self._threadWriteCount)
                [self _deleteThreadInfo];
            
        }
        
    }];
    
}

- (void)lockWrite {
    
    [self locked:^{
        
        // If thread holds no write locks
        if (!self._threadWriteCount) {
            
            self._threadIsAwaitingWriteLock = YES;
                        
            // If read or write locks are held by other threads then wait.
            if (self._globalReadCount || self._globalWriteCount)
                [_writeCondition waitWithLock:self.lock];
            
            self._threadIsAwaitingWriteLock = NO;
            
        }
        
        self._threadWriteCount++;
        
    }];
    
}

- (void)unlockWrite {
    
    [self locked:^{
        
        // If thread holds write lock
        if (self._threadWriteCount) {
            
            self._threadWriteCount--;
            
            // If !_globalWriteCount then thread is releasing last write lock
            if (!self._globalWriteCount) {
                
                /*
                 Now that we have released the write lock, we need to determine what to do. If current thread now holds read locks, we cannot let another write lock go. Therefore we continue letting the thread read. If there a no awaiting write locks we can also let other waiting read locks continue as well. If however there ARE pending write locks, we do nothing - We want the write locks to take off before any pending read locks.
                 */
                
                if (!self._globalReadCount) {
                    
                    if (self._awaitingWriteLocks)
                        [_writeCondition signal];
                    else
                        [_readCondition broadcast];
                    
                } else if (!self._awaitingWriteLocks)
                    [_readCondition broadcast];
                
            }
            
            if (!self._threadReadCount && !self._threadWriteCount)
                [self _deleteThreadInfo];
            
        }
        
    }];
    
}

@end
