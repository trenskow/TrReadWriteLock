//
//  TrLock.h
//  TrReadWriteLock
//
//  Created by Kristian Trenskow on 9/11/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TrLock : NSObject

- (void)lock;
- (void)unlock;

@end
