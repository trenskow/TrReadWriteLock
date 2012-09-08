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

- (TrReadWriteLockThreadInfo *)_infoForCurrentThread;
- (void)_threadWillExitNotification:(NSNotification *)notification;

@end

@implementation TrReadWriteLock

#pragma mark - Public Allocation / Deallocation

- (id)init {
    
    if ((self = [super init])) {
        
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_readCondition, NULL);
        pthread_cond_init(&_writeCondition, NULL);
        
    }
    
    return self;
    
}

- (void)dealloc {
    
    pthread_mutex_lock(&_mutex);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    free(_threadInfo);
    
    pthread_cond_destroy(&_readCondition);
    pthread_cond_destroy(&_writeCondition);
    
    pthread_mutex_unlock(&_mutex);
    
#   if !__has_feature(objc_arr)
    [super dealloc];
#   endif
    
}

#pragma mark - Private Methods

- (TrReadWriteLockThreadInfo *)_infoForCurrentThread {
    
    NSThread* thread = [NSThread currentThread];
    
    for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
        if (_threadInfo[i].thread == thread)
            return &_threadInfo[i];
    
    _threadInfo = (TrReadWriteLockThreadInfo *)realloc(_threadInfo, sizeof(TrReadWriteLockThreadInfo) * (_threadInfoCount + 1));
    
    TrReadWriteLockThreadInfo* newThreadInfo = &_threadInfo[_threadInfoCount++];
    
    bzero(newThreadInfo, sizeof(TrReadWriteLockThreadInfo));
    newThreadInfo->thread = thread;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_threadWillExitNotification:)
                                                 name:NSThreadWillExitNotification
                                               object:nil];
    
    return newThreadInfo;
    
}

- (void)_threadWillExitNotification:(NSNotification *)notification {
    
    pthread_mutex_lock(&_mutex);
    
    for (NSUInteger i = 0 ; i < _threadInfoCount ; i++)
        if (_threadInfo[i].thread == notification.object) {
            
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
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForCurrentThread];
    
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
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForCurrentThread];
    
    // Ignore read lock release request if thread already holds the write lock.
    if (!threadInfo->writeCount) {
        
        threadInfo->readCount--;
        _globalReadCount--;
        
        // If we were the last read lock, signal any pending write locks.
        if (!_globalReadCount)
            pthread_cond_signal(&_writeCondition);
        
    }
    
    pthread_mutex_unlock(&_mutex);
    
}

- (void)lockWrite {
    
    pthread_mutex_lock(&_mutex);
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForCurrentThread];
    
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
    
    TrReadWriteLockThreadInfo* threadInfo = [self _infoForCurrentThread];
    
    // If thread holds write lock
    if (threadInfo->writeCount) {
        
        _globalWriteCount = --threadInfo->writeCount;
        
        // If !_globalWriteCount then thread is releasing last write lock
        if (!_globalWriteCount) {
            
            // Give thread back it's read locks held prior to obtaining write lock
            _globalReadCount += threadInfo->readCount;
            
            // First signal pending write locks, if any
            if (_awaitingWriteLocks)
                pthread_cond_signal(&_writeCondition);
            else // Else broadcast pending read locks
                pthread_cond_broadcast(&_readCondition);
            
        }
                
    }
    
    pthread_mutex_unlock(&_mutex);
    
}

@end
