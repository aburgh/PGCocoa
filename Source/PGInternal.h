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
- (PGconn *)_conn;
@end

@interface PGPreparedQuery (PGPreparedQueryPGConnectionPrivate)
- (id)_initWithName:(NSString *)name query:(NSString *)query types:(NSArray *)sampleParams connection:(PGConnection *)conn;
@end

union PGMaxSizeType {
	long long	ll;
	double		d;
	int			i;
	Oid			oid;
};
struct PGQueryParameter {
	Oid					type;
	union PGMaxSizeType	value;
	char *				valueRef;
	int *				length;
	int *				format;
};
