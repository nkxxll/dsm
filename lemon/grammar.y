%include {

#include "grammar.h"
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "cjson.h"

#define DEBUG
#ifdef DEBUG
#define DEBUG_PRINT(fmt, ...) \
    fprintf(stderr, "[DEBUG] %s:%d:%s(): " fmt "\n", \
            __FILE__, __LINE__, __func__, ##__VA_ARGS__)
#else
#define DEBUG_PRINT(fmt, ...) \
    do { } while (0)
#endif

typedef struct { cJSON *cjson_ptr; } State;

int get_token_id (char*);
const char *getValue (cJSON *token);
const char *getLine (cJSON *token);
cJSON *unary (char *fname, cJSON *a);
cJSON *binary (char *fname, cJSON *a, cJSON *b);
cJSON *ternary (char *fname, cJSON *a, cJSON *b, cJSON *c);
char *linenumber;
char *curtoken;
char *curtype;
char *res;
}

%code {

typedef struct {char *value; int line;} token;

token* create_token (char *value, int line) {
	token *t = (token*) malloc (sizeof (token));
	t->value = strdup (value);
	t->line = line;
	return t;
}

const char * getValue (cJSON* token) {
	return cJSON_GetObjectItem (token, "value")->valuestring;
}


const char * getLine (cJSON* token) {
	return cJSON_GetObjectItem (token, "line")->valuestring;
}


int main(int argc, char* argv[]) {
    DEBUG_PRINT("Starting main function");
    size_t capacity = 1024;
    size_t size = 0;
    char *buffer = malloc(capacity);
    if (!buffer) {
        perror("Could not allocate buffer with capacity");
        exit(EXIT_FAILURE);
    }
    DEBUG_PRINT("Initial buffer allocated");

    int c;
    while ((c = fgetc(stdin)) != EOF) {
        if (size + 1 >= capacity) {
            capacity *= 2;
            char *newbuf = realloc(buffer, capacity);
            if (!newbuf) {
                free(buffer);
                perror("Could not reallocate buffer with capacity");
                exit(EXIT_FAILURE);
            }
            buffer = newbuf;
        }
        buffer[size++] = (char)c;
    }

    buffer[size] = '\0'; // null-terminate
    DEBUG_PRINT("Stdin read. Content: %s", buffer);

	cJSON *root = cJSON_Parse(buffer);

	if (!root) {
		perror("JSON invalid\n");
		exit(EXIT_FAILURE);
	}
    DEBUG_PRINT("JSON input parsed");

    State state;
	void* pParser = ParseAlloc (malloc);
	int num = cJSON_GetArraySize (root);

	for (int i = 0; i < num; i++ ) {

		// Knoten im Token-Stream auslesen
		cJSON *node = cJSON_GetArrayItem(root,i);

		char *line = cJSON_GetArrayItem(node,0)->valuestring;
		char *type = cJSON_GetArrayItem(node,1)->valuestring;
		char *value = cJSON_GetArrayItem(node,2)->valuestring;

		cJSON *tok = cJSON_CreateObject();
		cJSON_AddStringToObject(tok, "value", value);
		cJSON_AddStringToObject(tok, "line", line);

		linenumber = line;
		curtoken = value;
		curtype = type;
		// THE und Kommentare werden ueberlesen
		if (strcmp(type, "THE") == 0) continue;
		if (strcmp(type, "COMMENT") == 0) continue;
		if (strcmp(type, "MCOMMENT") == 0) continue;

		int tokenid = get_token_id (type);
		Parse (pParser, tokenid, tok, &state);

	}
	Parse (pParser, 0, 0, &state);
    ParseFree(pParser, free );
    // print the cjson structure
    printf("RESULT:\n%s\n", cJSON_Print(state.cjson_ptr));
    return EXIT_SUCCESS;
}

char *parse_to_string(char *input) {
	cJSON *root = cJSON_Parse(input);
    State state;

	if (!root) {
		printf("JSON invalid\n");
		exit(0);
	}

	void* pParser = ParseAlloc (malloc);
	int num = cJSON_GetArraySize (root);

	for (int i = 0; i < num; i++ ) {

		// Knoten im Token-Stream auslesen
		cJSON *node = cJSON_GetArrayItem(root,i);

		char *line = cJSON_GetArrayItem(node,0)->valuestring;
		char *type = cJSON_GetArrayItem(node,1)->valuestring;
		char *value = cJSON_GetArrayItem(node,2)->valuestring;

		cJSON *tok = cJSON_CreateObject();
		cJSON_AddStringToObject(tok, "value", value);
		cJSON_AddStringToObject(tok, "line", line);

		linenumber = line;
		curtoken = value;
		curtype = type;
		// THE und Kommentare werden ueberlesen
		if (strcmp(type, "THE") == 0) continue;
		if (strcmp(type, "COMMENT") == 0) continue;
		if (strcmp(type, "MCOMMENT") == 0) continue;

		int tokenid = get_token_id (type);
		Parse (pParser, tokenid, tok, &state);

	}
	Parse (pParser, 0, 0, &state);
    ParseFree(pParser, free );
    return cJSON_Print(state.cjson_ptr);
}




///////////////////////
///////////////////////
// TOKENS
///////////////////////
///////////////////////

int get_token_id (char *token) {
	if (strcmp(token, "DIVIDE") == 0) return DIVIDE;
	if (strcmp(token, "IDENTIFIER") == 0) return IDENTIFIER;
	if (strcmp(token, "LPAR") == 0) return LPAR;
	if (strcmp(token, "RPAR") == 0) return RPAR;
	if (strcmp(token, "MINUS") == 0) return MINUS;
	if (strcmp(token, "NUMTOKEN") == 0) return NUMTOKEN;
	if (strcmp(token, "PLUS") == 0) return PLUS;
	if (strcmp(token, "POWER") == 0) return POWER;
	if (strcmp(token, "SEMICOLON") == 0) return SEMICOLON;
	if (strcmp(token, "STRTOKEN") == 0) return STRTOKEN;
	if (strcmp(token, "WRITE") == 0) return WRITE;

	printf ("{\"error\" : true, \"message\": \"UNKNOWN TOKEN TYPE %s\"}\n", token);
	exit(0);
}



cJSON* unary (char* fname, cJSON* a)
{
	cJSON *res = cJSON_CreateObject();
	cJSON *arg = cJSON_CreateArray();
	cJSON_AddItemToArray(arg, a);
	cJSON_AddStringToObject(res, "type", fname);
	cJSON_AddItemToObject(res, "arg", arg);
	return res;
}



cJSON* binary (char *fname, cJSON *a, cJSON *b)
{
	cJSON *res = cJSON_CreateObject();
	cJSON *arg = cJSON_CreateArray();
	cJSON_AddItemToArray(arg, a);
	cJSON_AddItemToArray(arg, b);
	cJSON_AddStringToObject(res, "type", fname);
	cJSON_AddItemToObject(res, "arg", arg);
	return res;
}

cJSON* ternary (char *fname, cJSON *a, cJSON *b, cJSON *c)
{
	cJSON *res = cJSON_CreateObject();
	cJSON *arg = cJSON_CreateArray();
	cJSON_AddItemToArray(arg, a);
	cJSON_AddItemToArray(arg, b);
	cJSON_AddItemToArray(arg, c);
	cJSON_AddStringToObject(res, "type", fname);
	cJSON_AddItemToObject(res, "arg", arg);
	return res;
}

}

%syntax_error {
  printf ("{\"error\" : true, \"message\": \"Syntax Error: Compiler reports unexpected token \\\"%s\\\" of type \\\"%s\\\" in line %s\"}\n", curtoken, curtype, linenumber);
  exit(0);
}

%extra_argument { State *state }
%token_type {cJSON *}
%default_type {cJSON *}

///////////////////////
///////////////////////
// PRECEDENCE
///////////////////////
///////////////////////

%left 	   PLUS MINUS .
%left 	   TIMES DIVIDE .
%right     POWER .

///////////////////////
// CODE
///////////////////////

code ::= statementblock(sb) .
{
    state->cjson_ptr = sb;
}

///////////////////////
// STATEMENTBLOCK
///////////////////////

statementblock(sb) ::= .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "STATEMENTBLOCK");
	cJSON *arg = cJSON_CreateArray();
	cJSON_AddItemToObject(res, "statements", arg);
	sb = res;
}

statementblock(sb) ::= statementblock(a) statement(b) .
{
	cJSON_AddItemToArray(cJSON_GetObjectItem ( a, "statements"), b);
	sb = a;
}

///////////////////////////
// WRITE
///////////////////////////

statement(r) ::= WRITE ex(e) SEMICOLON .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "WRITE");
	cJSON_AddItemToObject(res, "arg", e);
	r = res;
}

ex(r) ::= LPAR ex(a) RPAR .
{
	r = a;
}


ex(r) ::= NUMTOKEN (a).
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "NUMBER");
	cJSON_AddStringToObject(res, "value", getValue(a));
	r = res;
}


ex(r) ::= STRTOKEN (a).
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "STRTOKEN");
	cJSON_AddStringToObject(res, "value", getValue(a));
	r = res;
}


ex(r) ::= IDENTIFIER(a) .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "VARIABLE");
	cJSON_AddStringToObject(res, "name", getValue(a));
	cJSON_AddStringToObject(res, "line", getLine(a));
	r = res;
}




ex(r) ::= ex(a) PLUS ex(b) .
{r = binary ("PLUS", a, b); }

ex(r) ::= ex(a) MINUS ex(b) .
{r = binary ("MINUS", a, b); }

ex(r) ::= ex(a) TIMES ex(b) .
{r = binary ("TIMES", a, b); }

ex(r) ::= ex(a) DIVIDE ex(b) .
{r = binary ("DIVIDE", a, b); }

ex(r) ::= ex(a) POWER ex(b) .
{r = binary ("POWER", a, b); }

