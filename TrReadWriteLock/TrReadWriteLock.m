//
//  TrReadWriteLock.m
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <pthread.h>

#import "TrReadWriteLock.h"

typedef struct {
    
    __unsafe_unretained NSThread* thread;
    NSUInteger readCount;
    NSUInteger writeCount;
    
} TrReadWriteLockThreadInfo;

@interface TrReadWriteLock () {
    
    pthread_mutex_t _mutex;
    
    pthread_cond_t _readCondition;
    pthread_cond_t _writeCondition;
    
    NSUInteger _globalReadCount;
    NSUInteger _globalWriteCount;
    
    NSUInteger _awaitingWriteLocks;
    
    TrReadWriteLockThreadInfo* _threadInfo;
    NSUInteger _threadInfoCount;
    
}

- (TrReadWriteLockThreadInfo *)_infoForThread;
- (void)_deleteInfoForThread;

@end

@implementation TrReadWriteLock

#pragma mark - Public Allocation / Deallocation

- (id)init {
    
    if ((self = [super init])) {
        
        pthread_mutexattr_t attr;
        
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        
        pthread_mutex_init(&_mutex, &attr);
        
        pthread_mutexattr_destroy(&attr);
        
        pthread_cond_init(&_readCondition, NULL);
        pthread_cond_init(&_writeCondition, NULL);
        
    }
    
    return self;
    
}

- (void)dealloc {
    
    pthread_mutex_lock(&_mutex);
    
    NSAssert(!_globalReadCount, @"Lock was deallocated while being read locked");
    NSAssert(!_globalWriteCount, @"Lock was deallocated while being write locked");
    NSAssert(!_awaitingWriteLocks, @"Lock was deallocated while having pending write locks");
    
    free(_threadInfo);
    
    pthread_cond_destroy(&_readCondition);
    pthread_cond_destroy(&_writeCondition);
    
    pthread_mutex_unlock(&_mutex);
    
    pthread_mutex_destroy(&_mutex);
    
#   if !__has_feature(objc_arc)
    [super dealloc];
#   endif
    
}

#pragma mark - Private Methods

- (TrReadWriteLockThreadInfo *)_infoForThread {
    
    pthread_mutex_lock(&_mutex);
    
    NSThread* thread = [NSThread currentThread];
    
    for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
        if (_threadInfo[i].thread == thread)
            return &_threadInfo[i];
    
    _threadInfo = (TrReadWriteLockThreadInfo *)realloc(_threadInfo, sizeof(TrReadWriteLockThreadInfo) * (_threadInfoCount + 1));
    
    TrReadWriteLockThreadInfo* newThreadInfo = &_threadInfo[_threadInfoCount++];
    
    bzero(newThreadInfo, sizeof(TrReadWriteLockThreadInfo));
    newThreadInfo->thread = thread;
    
    pthread_mutex_unlock(&_mutex);
    
    return newThreadInfo;
    
}

- (void)_deleteInfoForThread {
    
    pthread_mutex_lock(&_mutex);
    
    for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
        if (_threadInfo[i].thread == [NSThread currentThread]) {
            
            // Clean up thread, if thread did not clean up for itself.
            if (_threadInfo[i].writeCount > 1) {
                _globalWriteCount -= _threadInfo[i].writeCount - 1;
                [self unlockWrite];
            }
            
            if (_threadInfo[i].readCount > 1) {
                if (_globalReadCount > _threadInfo[i].readCount)
                    _globalReadCount -= _threadInfo[i].readCount;
                else {
                    _globalReadCount -= _threadInfo[i].readCount - 1;
                    [self unlockRead];
                }
            }
            
            for (NSUInteger c = i ; c < _threadInfoCount - 1 ; c++)
                _threadInfo[c] = _threadInfo[c + 1];
            
            _threadInfoCount--;
            
            break;
            
        }
    
    pthread_mutex_unlock(&_mutex);
    
}

#pragma mark - Public Methods

- (void)lockRead {
    
    pthread_mutex_lock(&_mutex);
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForThread];
    
    // Ignore read lock requests if thread already holds the write lock.
    if (!threadInfo->writeCount) {
        
        // If threads are currently writing - or we do not already hold any read locks and a write lock is pending -
        //   wait for the write locks to finish.
        if (_globalWriteCount || (!threadInfo->readCount && _awaitingWriteLocks))
            pthread_cond_wait(&_readCondition, &_mutex);
        
        _globalReadCount++;
        threadInfo->readCount++;
        
    }
    
    pthread_mutex_unlock(&_mutex);
    
}

- (void)unlockRead {
    
    pthread_mutex_lock(&_mutex);
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForThread];
    
    // Ignore read lock release request if thread already holds the write lock.
    if (!threadInfo->writeCount) {
        
        threadInfo->readCount--;
        _globalReadCount--;
        
        // If we were the last read lock, signal any pending write locks.
        if (!_globalReadCount)
            pthread_cond_signal(&_writeCondition);
        
        if (!threadInfo->readCount && !threadInfo->writeCount)
            [self _deleteInfoForThread];
            
    }
    
    pthread_mutex_unlock(&_mutex);
    
}

- (void)lockWrite {
    
    pthread_mutex_lock(&_mutex);
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForThread];
    
    // If thread holds no write locks
    if (!threadInfo->writeCount) {
        
        // Release all read locks held by thread
        _globalReadCount -= threadInfo->readCount;
        
        // If read or write locks are held by other threads then wait.
        if (_globalReadCount || _globalWriteCount) {
            _awaitingWriteLocks++;
            pthread_cond_wait(&_writeCondition, &_mutex);
            _awaitingWriteLocks--;
        }
        
    }
    
    _globalWriteCount = ++threadInfo->writeCount;
    
    pthread_mutex_unlock(&_mutex);
    
}

- (void)unlockWrite {
    
    pthread_mutex_lock(&_mutex);
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForThread];
    
    // If thread holds write lock
    if (threadInfo->writeCount) {
        
        _globalWriteCount = --threadInfo->writeCount;
        
        // If !_globalWriteCount then thread is releasing last write lock
        if (!_globalWriteCount) {
            
            // Give thread back it's read locks held prior to obtaining write lock
            _globalReadCount += threadInfo->readCount;
            
            /*
             Now that we have released the write lock, we need to determine what to do. If current thread now holds read locks, we cannot let another write lock go. Therefore we continue letting the thread read. If there a no awaiting write locks we can also let other waiting read locks continue as well. If however there ARE pending write locks, we do nothing - We want the write locks to take off before any pending read locks.
             */
            
            if (!_globalReadCount) {
                
                if (_awaitingWriteLocks)
                    pthread_cond_signal(&_writeCondition);
                else // Else broadcast pending read locks
                    pthread_cond_broadcast(&_readCondition);
                
            } else if (!_awaitingWriteLocks)
                pthread_cond_broadcast(&_readCondition);
            
        }
        
        if (!threadInfo->readCount && !threadInfo->writeCount)
            [self _deleteInfoForThread];
        
    }
    
    pthread_mutex_unlock(&_mutex);
    
}

@end
