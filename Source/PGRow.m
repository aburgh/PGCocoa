//
//  PGRow.m
//  PGCocoa
//
//  Created by Aaron Burghardt on 9/16/09.
//  Copyright 2009. All rights reserved.
//

#import "PGRow.h"
#import "PGResult.h"

@implementation PGRow

@synthesize result;
@synthesize rowNumber;

- (id)_initWithResult:(PGResult *)parent rowNumber:(NSInteger)index
{
	if (self = [super init]) {
		_result = [parent retain];
		_rowNumber = index;
	}
	return self;
}

- (void)dealloc
{
	[_result release];
	[super dealloc];
}

- (id)valueAtFieldIndex:(NSInteger)index
{
	return [_result valueAtRowIndex:_rowNumber fieldIndex:index];
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
	return [_result valueAtRowIndex:_rowNumber fieldIndex:index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	NSUInteger i, maxLen, index;

	index = state->state;
	maxLen = _result.numberOfFields;

	for (i = 0; i < len && index < maxLen; i++, index++) {
		stackbuf[i] = [_result valueAtRowIndex:_rowNumber fieldIndex:index];
	}
	state->state = index;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;  // Not sufficient if the instance is not read-only

	return i;
}

- (id)valueForKey:(NSString *)key
{
	NSInteger index = [_result indexForFieldName:key];
	
	if (index == -1)
		return [super valueForKey:key];
	
	return [_result valueAtRowIndex:_rowNumber fieldIndex:index];
}

@end
