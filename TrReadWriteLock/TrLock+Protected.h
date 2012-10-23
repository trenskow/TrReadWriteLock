//
//  TrLock+Protected.h
//  TrReadWriteLock
//
//  Created by Kristian Trenskow on 9/11/12.
//  Copyright (c) 2012 Kristian Trenskow. All rights reserved.
//

struct pthread_mutex_t;

#import "TrLock.h"

@interface TrLock ()

@property (nonatomic,readonly) pthread_mutex_t* mutex;

@end
