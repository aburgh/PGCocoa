//
//  PGConnection.h
//  PGCocoa
//
//  Created by Aaron Burghardt on 7/14/08.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PGResult;
@class PGPreparedQuery;
struct pg_conn;

// Mapped directly to ConnStatusType
typedef enum {
	/*
	 * Although it is okay to add to this list, values which become unused
	 * should never be removed, nor should constants be redefined - that would
	 * break compatibility with existing code.
	 */
	kPGConnectionOK,
	kPGConnectionBad,
	/* Non-blocking mode only below here */

	/*
	 * The existence of these should never be relied upon - they should only
	 * be used for user feedback or similar purposes.
	 */
	kPGConnectionStarted,			/* Waiting for connection to be made.  */
	kPGConnectionMade,				/* Connection OK; waiting to send.	   */
	kPGConnectionAwaitingResponse,	/* Waiting for a response from the
									 * postmaster.		  */
	kPGConnectionAuthOK,			/* Received authentication; waiting for
									 * backend startup. */
	kPGConnectionSetEnv,			/* Negotiating environment. */
	kPGConnectionSSL,				/* Negotiating SSL. */
	kPGConnectionDisconnected		/* Internal state: connect() needed */
} PGConnStatusType;

// Mapped directly to PGTransactionStatusType
typedef enum {
	kPGTransactionIdle,				/* connection idle */
	kPGTransactionActive,			/* command in progress */
	kPGTransactionInTransaction,	/* idle, within transaction block */
	kPGTransactionInError,			/* idle, within failed transaction */
	kPGTransactionUnknown			/* cannot determine status */
} PGTransactStatusType;

@interface PGConnection : NSObject 
{
	struct pg_conn *_connection;

	NSDictionary *_params;
}

@property (readonly) NSString *errorMessage;
@property (readonly) NSError  *error;
@property (readonly) PGConnStatusType status;
@property (readonly) PGTransactStatusType transactionStatus;

- (id)initWithParameters:(NSDictionary *)params;

- (BOOL)connect;
- (void)disconnect;

- (PGResult *)executeQuery:(NSString *)query;
- (PGResult *)executeQuery:(NSString *)query parameters:(NSArray *)params;
- (PGPreparedQuery *)preparedQueryWithName:(NSString *)name query:(NSString *)sql types:(NSArray *)paramTypes;

- (NSString *)parameterStatus:(NSString *)paramName;

- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

- (struct pg_conn *)_conn;

@end

extern NSString *const PostgreSQLErrorDomain;


// Connection Parameter Keys
extern NSString *const PGConnectionParameterHostKey;
extern NSString *const PGConnectionParameterHostAddressKey;
extern NSString *const PGConnectionParameterPortKey;
extern NSString *const PGConnectionParameterDatabaseNameKey;
extern NSString *const PGConnectionParameterUsernameKey;
extern NSString *const PGConnectionParameterPasswordKey;
extern NSString *const PGConnectionParameterConnectionTimeoutKey;
extern NSString *const PGConnectionParameterOptionsKey;
extern NSString *const PGConnectionParameterSSLModeKey;
extern NSString *const PGConnectionParameterKerberosServiceNameKey;
extern NSString *const PGConnectionParameterServiceNameKey;
