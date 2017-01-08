//
//  OrderedDictionary.m
//  OrderedDictionary
//
//  Created by Matt Gallagher on 19/12/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

//TODO: fixed!?
#import "OrderedDictionary.h"

@implementation OrderedDictionary

-(id)init
{
    self = [super init];
    if (self != nil)
    {
        dictionary = [NSMutableDictionary dictionary];
        array = [NSMutableArray array];
    }
    return self;
    
}

//copy
-(id)copy
{
    return [self mutableCopy];
}

//description
-(NSString*)description
{
    return [dictionary description];
}

//remove
-(void)removeObjectForKey:(id)aKey
{
	[dictionary removeObjectForKey:aKey];
	[array removeObject:aKey];
}

//count
-(NSUInteger)count
{
	return [dictionary count];
}

//object for key
-(id)objectForKey:(id)aKey
{
	return [dictionary objectForKey:aKey];
}

//reverse key enumerator
-(NSEnumerator *)reverseKeyEnumerator
{
    return [array reverseObjectEnumerator];
}

//key at index
-(id)keyAtIndex:(NSUInteger)anIndex
{
	return [array objectAtIndex:anIndex];
}

//add an object
// ->either (but only) start or end
-(void)addObject:(id)anObject forKey:(id)aKey atStart:(BOOL)atStart
{
    //if object already exists
    // ->remove from both dictionary *and* array
    if(nil != [dictionary objectForKey:aKey])
    {
        //remove
        [self removeObjectForKey:aKey];
    }
    
    //at start?
    // ->insert into beginning of array
    if(YES == atStart)
    {
        //insert
        [array insertObject:aKey atIndex:0];
    }
    //otherwise at end
    // ->just add into array
    else
    {
        //add
        [array addObject:aKey];
    }
    
    //add to dictionary
    [dictionary setObject:anObject forKey:aKey];
    
    return;
}

@end
