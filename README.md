# TrReadWriteLock

This project contains a simple library providing an easy-to-use readers-writers lock mechanism for Mac and iOS.

## What it is?
**TrReadWriteLock** is a readers-writers lock implementation using pthread semaphores. It is fully recursive (both read and write). Readers-writers lock is for usage in multi-threaded environnments, and allow for multiple threads to read a piece of shared memory at the time, but only one thread to write at the time.

The library has been created for usage in code utilizing *[Grand Central Dispatch](http://en.wikipedia.org/wiki/Grand_Central_Dispatch)*. Although this is not required.

## How to install?

Simply include these four files into your iOS or Mac project:

    TrReadWriteLock.h
    TrReadWriteLock.m
    NSObject+TrReadWriteLockAdditions.h
    NSObject+TrReadWriteLockAdditions.m

If you add this to your \<myproject\>-Prefix.h file, you will make things a lot easier for yourself:

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

**Only rule of thumb**: each *lockRead* call must be match with a succeeding *unlockRead*. The same goes for the write lock methods - **otherwise behavior is undetermined**.

### Using the NSObject Category and Blocks *(Recommended)*

Locking and unlocking objects in the right order can be cumbersome, and failing to do so makes your code unstable and hard to debug - as locks stumble on each other.

Therefore if you want an easier way to go, where locking and unlocking is done automatically - and in the right order - I suggest the usage of the library's NSObject additions.

Either do as mentioned above, and import the file "*NSObject+TrReadWriteLock.h*" to your precompiled header file (\<myproject/>-Prefix.h). Or you can include it manually in each file where you need a readers-writers lock.

When included, things are pretty straigt forward (you don't even need to initate a lock):

    [someObject readLocked:^{
    	// Do some reading
    }];

or when writing:

    [someObject writeLocked:^{
        // Do some writing
    }];
    

If you're used to use the *@synthesized* Objective-C keyword, then this is for you.

**Tip**: Because you cannot return variables from a block, it is recomended to implement property getters like this:

    - (id)someProperty {
        __block id someProperty;
        [self readLocked:^{
            someProperty = _someiVar;
        }];
        return someProperty;
    }

## Recursiveness

These locks are fully recursive, meaning you can lock for read or lock for write any number of consecutive times you need. The library will figure out what to do.

Example:

    [someObject readLocked:^{
    	
    	// Do some reading
    	
    	[someObject writeLocked:^{
    		
    		[someObject doSomething];
    		
	    	[self someMethod:someObject];
	    	
	    	// someMethod: might also read and/or write lock someObject, which is perfectly fine.
	    	// The library will figure what to do.
	    	
    	}];
    	
    }];

## Automatic Reference Counting

The code is compatible with both ARC and non-ARC projects. Only two lines are different from the ARC and non-ARC versions. Macros are used to determine the availability of ARC.

## Starvation

This code uses the constraint "*no writer, once added to the queue, shall be kept waiting longer than absolutely necessary*" (See [Wikipedia: Readers Writers Problem](http://en.wikipedia.org/wiki/Readers-writers_problem)).

In a newer version this might be upgraded to the "*no thread shall be allowed to starve*" constraint. **But until then be considerate in your usage of writer locks or you might end up starving your read locks**.

## Deadlocks

Even though this code seems pretty straight forward, it doesn't eliminate deadlocks because of poorly structured code. Always only wrap critical code sections in locks.

You especially need to be careful in these kinds of situations:

    Thread 1 read locks object 1
    Thread 2 read locks object 2
    Thread 1 goes on to write locking object 2 - will wait because of thread 1's read lock.
    Thread 2 immediately after goes on to write locking object 1 - and will wait because Thread 1's read lock
    
In the above example **a deadlock have occurred**. Neither thread 1 or 2 will ever progress beyond their request for write locks, as they both also holds read locks that makes them both wait.

## Disclaimer and Testing

This code has not been fully tested. I don't know how water tight this code is in all situations. Please test it thoroughly before using in production code.

## Feedback

Please leave me a message if you have any questions, suggestions or bugfixes.

## License

The code is open and free.