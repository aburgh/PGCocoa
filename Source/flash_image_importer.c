/*
 *  flash_image_importer.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

#include "libpq-fe.h"

void print_usage_and_exit(int code)
{
	printf("usage: flash_image_importer -h host -u user -p password -d database -i infile -s pagesize -t sparesize\n");
	exit(code);
}

void print_error_and_exit(char *s, int err)
{
	perror(s);
	exit(err);
}


PGconn *connectdb(char *host, char *user, char *pass, char *dbname)
{
	char *conninfo;

	asprintf(&conninfo, "%s%s %s%s %s%s %s%s", 
			 host ? "host=" : "",
			 host ? host : "",
			 user ? "user=" : "",
			 user ? user : "",
			 pass ? "password=" : "",
			 pass ? pass : "",
			 dbname ? "dbname=" : "",
			 dbname ? dbname : "");

	return PQconnectdb(conninfo);
}

int main(int argc, char *argv[]) 
{
	char *host = NULL;
	char *user = NULL;
	char *pass = NULL;
	char *dbname = NULL;
	char *infile = NULL;
	int pagesize = 0;
	int sparesize = 0;
	
	int ch;
	int count;
	
	while( (ch = getopt(argc, argv, "h:u:p:d:i:s:t:")) != -1) {
	
		switch(ch) {
			case 'h':
				host = optarg;
				break;
			case 'u':
				user = optarg;
				break;
			case 'p':
				pass = optarg;
				break;
			case 'd':
				dbname = optarg;
				break;
			case 'i':
				infile = optarg;
				break;
			case 's':
				count = sscanf(optarg, "%i", &pagesize);
				break;
			case 't':
				count = sscanf(optarg, "%i", &sparesize);
				break;
			default:
				print_usage_and_exit(-1);
		}
	}
	
//	printf("Args: %s %s %s %s %s  %i %i\n", host, user, pass, dbname, infile, pagesize, sparesize);
	
	if (infile == NULL || pagesize == 0 || sparesize == 0) print_usage_and_exit(-1);

	void *pagebuf = malloc(pagesize);
	void *sparebuf = malloc(sparesize);
	FILE *fp = NULL;
	
	
	// Connect to database
	PGconn *conn = connectdb(host, user, pass, dbname);
	if (PQstatus(conn) != CONNECTION_OK) {
		fprintf(stderr, "Failed to connect: %s\n", PQerrorMessage(conn));
		goto cleanup;
	}
	
	// Prepare insert statement
	PGresult *result = PQprepare(conn, 
								 "Page Insert", 
								 "INSERT INTO block (index, pagedata, sparedata) VALUES ($1::int4, $2::bytea, $3::bytea);", 
								 0,
								 NULL);
	if (PQresultStatus(result) != PGRES_COMMAND_OK)
	{
        fprintf(stderr, "Prepare statement failed: %s", PQerrorMessage(conn));
		goto cleanup;
	}
	PQclear(result); result = NULL;

	// Set up params for prepared statement
	uint32_t intval;
	const char *paramValues[3];
	int paramLengths[3];
	int paramFormats[3];
	paramValues[0] = (char *) &intval;
	paramLengths[0] = sizeof(intval);
	paramFormats[0] = 1;        /* binary */
	paramValues[1] = pagebuf;
	paramLengths[1] = pagesize;
	paramFormats[1] = 1;
	paramValues[2] = sparebuf;
	paramLengths[2] = sparesize;
	paramFormats[2] = 1;
	
	// Open input file
	fp = fopen(infile, "r");
	if (!fp) {
		perror("Failed to open file:");
		goto cleanup;
	}
	
	int index;
	for (index = 0; ; index++) {
		
		int page_size_read = fread(pagebuf, 1, pagesize, fp);
		int spare_size_read = fread(sparebuf, 1, sparesize, fp);

		if (page_size_read != pagesize || spare_size_read != sparesize) break;
		
		intval = htonl(index);
		
		result = PQexecPrepared(conn, "Page Insert", 3, paramValues, paramLengths, paramFormats, 0);
		
		if (PQresultStatus(result) != PGRES_COMMAND_OK) {
			fprintf(stderr, "Insert failed at index: %i: %s\n", index, PQerrorMessage(conn));
			goto cleanup;
		}
		PQclear(result); result = NULL;
	}
	
	printf("Inserted %i pages.\n", index);
	
cleanup:
	if(fp) fclose(fp);
	if (pagebuf) free(pagebuf);
	if (sparebuf) free(sparebuf);
	if (result) PQclear(result);
	if (conn) PQfinish(conn);
	exit(0);
}