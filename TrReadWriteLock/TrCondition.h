//
//  TrCondition.h
//  TrReadWriteLock
//
//  Created by Kristian Trenskow on 9/11/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TrLock;

@interface TrCondition : NSObject

- (void)waitWithLock:(TrLock *)lock;
- (BOOL)waitWithLock:(TrLock *)lock andTimeoutInterval:(NSTimeInterval)timeInterval;
- (void)signal;
- (void)broadcast;

@end
