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
		result = [parent retain];
		rowNumber = index;
	}
	return self;
}

- (void)dealloc
{
	[result release];
	[super dealloc];
}

- (id)valueAtFieldIndex:(NSInteger)index
{
	return [result valueAtRowIndex:rowNumber fieldIndex:index];
}

- (id)valueForKey:(NSString *)key
{
	NSInteger index = [result indexForFieldName:key];
	
	if (index == -1) [super valueForKey:key];
	
	return [result valueAtRowIndex:rowNumber fieldIndex:index];
}
			
			
@end
