//
//  NSObject+SUGULibraryAdditions.h
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TrLock;
@class TrReadWriteLock;

@interface NSObject (TrReadWriteLockAdditions)

@property (nonatomic,readonly) TrLock* lock;
@property (nonatomic,readonly) TrReadWriteLock* rwLock;

- (void)locked:(void(^)())block;

- (void)readLocked:(void(^)())block;
- (void)writeLocked:(void(^)())block;

@end
