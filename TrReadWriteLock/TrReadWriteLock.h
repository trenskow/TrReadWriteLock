//
//  TrReadWriteLock.h
//  sugulib
//
//  Created by Kristian Trenskow on 9/7/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TrReadWriteLock : NSObject

- (void)lockRead;
- (void)unlockRead;
- (void)lockWrite;
- (void)unlockWrite;

@end
