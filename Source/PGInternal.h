/*
 *  PGInternal.h
 *  PGCocoa
 *
 *  Created by Aaron Burghardt on 8/30/08.
 *  Copyright 2008 No Company. All rights reserved.
 *
 */

// Private method of PGConnection
@interface PGConnection (PGConnectionPGPreparedQuery)
- (struct pg_conn *)_conn;
@end

@interface PGPreparedQuery (PGPreparedQueryPGConnectionPrivate)
- (id)_initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)sampleParams connection:(PGConnection *)conn;
@end

union PGMaxSizeType {
	long long	ll;
	double		d;
	int			i;
	unsigned int oid;	// Same as Oid
};
struct PGQueryParameter {
	unsigned int		type;		// Same as Oid
	union PGMaxSizeType	value;
	char *				valueRef;
	int *				length;
	int *				format;
};
