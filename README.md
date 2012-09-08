# TrReadWriteLock

This project contains a simple library with the intent of providing a easy-to-use read-write lock mechanism for Objective-C.

## What it is?
**TrReadWriteLock** is a read/write lock implemented using pthread semaphores. It is fully recursive (both read and write). It allows multiple threads to read the same data at once, but only one thread at the time to write.

The library has been created for easy read/write locks when using Grand Central Dispatch.

## How to install?

Simply include these four files into your iOS or Mac OS X project:

    TrReadWriteLock.h
    TrReadWriteLock.m
    NSObject+TrReadWriteLockAdditions.h
    NSObject+TrReadWriteLockAdditions.m

If you add this to your \<myproject\>-Prefix.h file, things will be a lot easier:

    #include "NSObject+TrReadWriteLockAdditions.h"

## How to use?

### Manually

Direct usage of locks are pretty straight forward. Locks are initiated using:

    TrReadWriteLock* myLock = [[TrReadWriteLock alloc] init]

and are locked and unlocked using these methods:

    [myLock lockRead];
    [myLock unlockRead];
    [myLock lockWrite];
    [myLock unlockWrite];

Only rule of thumb: each *lockRead* call must be match with a succeeding *unlockRead*. The same goes for the write lock methods. Otherwise behavior is undetermined.

### Automatically

If you need an easier way to go, I suggest the automatic method of usage. This is done using the NSObject category implemented in *NSObject+TrReadWriteLockAdditions.h/m".

Either do as mentioned above, and add the header to your precompiled header file (\<myproject/>-Prefix.h). Or you can include it manually in each file you need a read-write lock.

The automatic way is implemented using blocks, as this example shows:

    [someObject readLocked:^{
    	// Do some reading
    }];

or when writing:

    [someObject writeLocked:^{
        // Do some writing
    }];

## Recursiveness

The locks are fully recursive, meaning you can lock for read or lock for write any number of consecutive times you need. The library will figure out what to do.

Example:

    [someObject readLocked:^{
    	
    	// Do some reading
    	
    	[someObject writeLocked:^{
    		
	    	[self someMethod:someObject];
	    	
	    	// someMethod: might also read and/or write lock someObject, which is perfectly fine.
	    	// The library will figure what to do.
	    	
    	}];
    	
    }];

## Automatic Reference Counting

The code is compatible with both ARC and non-ARC projects.

## Disclaimer and testing

This code has not been fully tested, and it's scalability is unknown. It does - though - clean everything up for itself.

The same goes with reader starvation. When write locks are released, it prioritizes waiting write locks over read locks. On large scales excessive write locks might starve out the read locks. See [http://en.wikipedia.org/wiki/Readers-writers_problem](http://en.wikipedia.org/wiki/Readers-writers_problem)

## Feedback

Please leave me a message if you have any questions or suggestions.

## License

The code is open and free.