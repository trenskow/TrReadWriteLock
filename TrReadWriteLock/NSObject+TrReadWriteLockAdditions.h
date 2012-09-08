//
//  NSObject+SUGULibraryAdditions.h
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TrReadWriteLock;

@interface NSObject (TrReadWriteLockAdditions)

@property (nonatomic,readonly) TrReadWriteLock* lock;

- (void)readLocked:(void(^)())block;
- (void)writeLocked:(void(^)())block;

@end
