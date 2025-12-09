%include {

#include "cjson.h"
#include "grammar.h"
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <setjmp.h>

/** start: what should be the header file */
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
typedef struct {char *value; int line;} token;

int get_token_id (char*);
const char *getValue (cJSON *token);
const char *getLine (cJSON *token);
cJSON *unary (char *fname, cJSON *a);
cJSON *binary (char *fname, cJSON *a, cJSON *b);
cJSON *ternary (char *fname, cJSON *a, cJSON *b, cJSON *c);
/** end: what should be the header file */

char *linenumber;
char *curtoken;
char *curtype;
static jmp_buf s_jumpBuffer;
}

%code {

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


const char *parse_to_string(const char *input) {
	int jmp_val = setjmp(s_jumpBuffer);
	if (jmp_val != 0) {
        size_t buf_size = 256;
        char buf[buf_size];
        int n;
        if (jmp_val == 1) {
            n = snprintf(
            buf,
            buf_size,
            "{\"error\" : true, \"message\": \"Syntax Error: Compiler reports unexpected token \\\"%s\\\" of type \\\"%s\\\" in line %s\"}\n",
            curtoken, curtype, linenumber
        );
        } else if (jmp_val == 2) {
        	n = snprintf (buf, buf_size, "{\"error\" : true, \"message\": \"UNKNOWN TOKEN TYPE %s\"}\n", curtoken);
        } else {
        	n = snprintf (buf, buf_size, "{\"error\" : true, \"message\": \"Jumped here dont know why...!\"}\n");
        }

        // allocate n+1 chars (for the null terminator)
        char *res = malloc(n + 1);
        if (res == NULL) exit(1);

        // copy exactly n chars + '\0'
        memcpy(res, buf, n + 1);

        return res;
	} else {
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
}




///////////////////////
///////////////////////
// TOKENS
///////////////////////
///////////////////////

int get_token_id (char *token) {
	if (strcmp(token, "IS") == 0) return IS;
	if (strcmp(token, "SQRT") == 0) return SQRT;
	// if (strcmp(token, "NOT") == 0) return NOT;
	if (strcmp(token, "AMPERSAND") == 0) return AMPERSAND;
	if (strcmp(token, "ASSIGN") == 0) return ASSIGN;
	if (strcmp(token, "COMMA") == 0) return COMMA;
	if (strcmp(token, "DIVIDE") == 0) return DIVIDE;
	if (strcmp(token, "IDENTIFIER") == 0) return IDENTIFIER;
	if (strcmp(token, "LIST") == 0) return LIST;
	if (strcmp(token, "LPAR") == 0) return LPAR;
	if (strcmp(token, "LSPAR") == 0) return LSPAR;
	if (strcmp(token, "MINUS") == 0) return MINUS;
	if (strcmp(token, "NULL") == 0) return NULLTOK;
	if (strcmp(token, "NUMTOKEN") == 0) return NUMTOKEN;
	if (strcmp(token, "NUMBER") == 0) return NUMBER;
	if (strcmp(token, "PLUS") == 0) return PLUS;
	if (strcmp(token, "POWER") == 0) return POWER;
	if (strcmp(token, "RPAR") == 0) return RPAR;
	if (strcmp(token, "RSPAR") == 0) return RSPAR;
	if (strcmp(token, "SEMICOLON") == 0) return SEMICOLON;
	if (strcmp(token, "STRTOKEN") == 0) return STRTOKEN;
	if (strcmp(token, "TIME") == 0) return TIME;
	if (strcmp(token, "TIMES") == 0) return TIMES;
	if (strcmp(token, "TIMETOKEN") == 0) return TIMETOKEN;
	if (strcmp(token, "TRACE") == 0) return TRACE;
	if (strcmp(token, "WRITE") == 0) return WRITE;
 	if (strcmp(token, "AVERAGE") == 0) return AVERAGE;
 	if (strcmp(token, "CURRENTTIME") == 0) return CURRENTTIME;
 	if (strcmp(token, "DO") == 0) return DO;
 	if (strcmp(token, "ELSE") == 0) return ELSE;
 	if (strcmp(token, "ENDDO") == 0) return ENDDO;
 	if (strcmp(token, "ENDIF") == 0) return ENDIF;
 	if (strcmp(token, "FALSE") == 0) return FALSE;
 	if (strcmp(token, "FOR") == 0) return FOR;
 	if (strcmp(token, "IF") == 0) return IF;
 	if (strcmp(token, "IN") == 0) return IN;
 	if (strcmp(token, "INCREASE") == 0) return INCREASE;
 	if (strcmp(token, "MAXIMUM") == 0) return MAXIMUM;
 	if (strcmp(token, "NOW") == 0) return NOW;
 	if (strcmp(token, "RANGE") == 0) return RANGE;
 	if (strcmp(token, "THEN") == 0) return THEN;
 	if (strcmp(token, "TRUE") == 0) return TRUE;
 	if (strcmp(token, "UPPERCASE") == 0) return UPPERCASE;
    curtoken = token;
    longjmp(s_jumpBuffer, 2);
}



cJSON* unary (char* fname, cJSON* a)
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", fname);
	cJSON_AddItemToObject(res, "arg", a);
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
    longjmp(s_jumpBuffer, 1);
}

%extra_argument { State *state }
%token_type {cJSON *}
%default_type {cJSON *}

///////////////////////
///////////////////////
// PRECEDENCE
///////////////////////
///////////////////////

%right     TIME UPPERCASE AVERAGE INCREASE MAXIMUM .
%right     IS .
%left      AMPERSAND .
%left 	   PLUS MINUS .
%left 	   TIMES DIVIDE .
%right     SQRT .
%right     UNMINUS .
%right     POWER .
%left      RANGE .

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

statement(r) ::= TRACE(t) ex(e) SEMICOLON .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "TRACE");
    cJSON_AddStringToObject(res, "line", getLine(t));
    cJSON_AddItemToObject(res, "arg", e);
    r = res;
}

///////////////////////////
// ASSIGNMENT
///////////////////////////

statement(r) ::= IDENTIFIER(i) ASSIGN ex(e) SEMICOLON .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "ASSIGN");
	cJSON_AddStringToObject(res, "ident", getValue(i));
	cJSON_AddItemToObject(res, "arg", e);
	r = res;
}

// if statement
statement(r) ::= IF if_then_else(a) .
{r = a;}

if_then_else(r) ::= ex(a) THEN statementblock(b) elseif(c) .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "IF");
    cJSON_AddItemToObject(res, "condition", a);
    cJSON_AddItemToObject(res, "thenbranch", (b));
    cJSON_AddItemToObject(res, "elsebranch", (c));
    r = res;
}

// else if
elseif(r) ::= ENDIF SEMICOLON .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "STATEMENTBLOCK");
    cJSON *arg = cJSON_CreateArray();
    cJSON_AddItemToObject(res, "statements", arg);
    r = res;
}

elseif(r) ::= ELSE statementblock(a) ENDIF SEMICOLON .
{r = a;}

elseif(r) ::= ELSEIF if_then_else(a) .
{r = a;}

// for statement
statement(r) ::= FOR IDENTIFIER(i) IN ex(e) DO statementblock(sb) ENDDO SEMICOLON .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "FOR");
    cJSON_AddStringToObject(res, "varname", getValue(i));
    cJSON_AddItemToObject(res, "expression", e);
    cJSON_AddItemToObject(res, "statements", sb);
    r = res;
}

// TIME ASSIGNMENT
statement(r) ::= TIME IDENTIFIER(i) ASSIGN ex(e) SEMICOLON .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "TIMEASSIGN");
	cJSON_AddStringToObject(res, "ident", getValue(i));
	cJSON_AddItemToObject(res, "arg", e);
	r = res;
}

ex(r) ::= NOW .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "NOW");
	r = res;
}

ex(r) ::= CURRENTTIME .
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "CURRENTTIME");
	r = res;
}

ex(r) ::= LPAR ex(a) RPAR .
{
	r = a;
}


ex(r) ::= NUMTOKEN (a).
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "NUMTOKEN");
	cJSON_AddStringToObject(res, "value", getValue(a));
	r = res;
}

ex(r) ::= TIMETOKEN (a).
{
	cJSON *res = cJSON_CreateObject();
	cJSON_AddStringToObject(res, "type", "TIMETOKEN");
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

ex(r) ::= TIME ex(a) .
{ r = unary("TIME", a); }

ex(r) ::= SQRT ex(a) .
{ r = unary("SQRT", a); }

ex(r) ::= UPPERCASE ex(a) .
{ r = unary("UPPERCASE", a); }

ex(r) ::= MAXIMUM ex(a) .
{ r = unary("MAXIMUM", a); }

ex(r) ::= AVERAGE ex(a) .
{ r = unary("AVERAGE", a); }

ex(r) ::= INCREASE ex(a) .
{ r = unary("INCREASE", a); }

ex(r) ::= MINUS ex(a) . [UNMINUS]
{ r = unary("UNMINUS", a); }

ex(r) ::= ex(a) IS NUMBER .
{ r = unary("ISNUMBER", a); }

ex(r) ::= ex(a) IS LIST .
{ r = unary("ISLIST", a); }

ex(r) ::= ex(a) IS NULLTOK .
{ r = unary("ISNULL", a); }

ex(r) ::= ex(a) AMPERSAND ex(b) .
{r = binary ("AMPERSAND", a, b); }

ex(r) ::= ex(a) RANGE ex(b) .
{r = binary ("RANGE", a, b); }

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

ex(r) ::= NULLTOK .
{
cJSON *res = cJSON_CreateObject();
cJSON_AddStringToObject(res, "type", "NULL");
r = res;
}

ex(r) ::= TRUE .
{
 	cJSON *res = cJSON_CreateObject();
 	cJSON_AddStringToObject(res, "type", "TRUE");
 	r = res;
}

ex(r) ::= FALSE .
{
 	cJSON *res = cJSON_CreateObject();
 	cJSON_AddStringToObject(res, "type", "FALSE");
 	r = res;
}

ex(r) ::= LSPAR RSPAR .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "EMPTYLIST");
    r = res;
}


ex(r) ::= LSPAR exlist(a) RSPAR .
{
    cJSON *res = cJSON_CreateObject();
    cJSON_AddStringToObject(res, "type", "LIST");
    cJSON_AddItemToObject(res, "items", a);
    r = res;
}

exlist(r) ::= ex(a) .
{
    cJSON *arg = cJSON_CreateArray();
    cJSON_AddItemToArray(arg, a);
    r = arg;
}

exlist(r) ::= exlist(a) COMMA ex(b) .
{
    cJSON_AddItemToArray(a,b);
    r = a;
}
