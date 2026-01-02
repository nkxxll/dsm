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
	if (strcmp(token, "NOT") == 0) return NOT;
	if (strcmp(token, "SAME") == 0) return SAME;
	if (strcmp(token, "AMPERSAND") == 0) return AMPERSAND;
	if (strcmp(token, "OF") == 0) return OF;
	if (strcmp(token, "LT") == 0) return LT;
	if (strcmp(token, "ASSIGN") == 0) return ASSIGN;
	if (strcmp(token, "COMMA") == 0) return COMMA;
	if (strcmp(token, "DIVIDE") == 0) return DIVIDE;
	if (strcmp(token, "THAN") == 0) return THAN;
	if (strcmp(token, "DAY") == 0) return DAY;
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
	if (strcmp(token, "WITHIN") == 0) return WITHIN;
	if (strcmp(token, "TO") == 0) return TO;
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
 	if (strcmp(token, "ANY") == 0) return ANY;
 	if (strcmp(token, "BEFORE") == 0) return BEFORE;
 	if (strcmp(token, "FIRST") == 0) return FIRST;
 	if (strcmp(token, "COUNT") == 0) return COUNT;
 	if (strcmp(token, "CURRENTTIME") == 0) return CURRENTTIME;
 	if (strcmp(token, "DO") == 0) return DO;
 	if (strcmp(token, "ELSE") == 0) return ELSE;
 	if (strcmp(token, "ENDDO") == 0) return ENDDO;
 	if (strcmp(token, "ENDIF") == 0) return ENDIF;
 	if (strcmp(token, "FALSE") == 0) return FALSE;
 	if (strcmp(token, "FOR") == 0) return FOR;
 	if (strcmp(token, "GREATER") == 0) return GREATER;
 	if (strcmp(token, "OCCUR") == 0) return OCCUR;
 	if (strcmp(token, "IF") == 0) return IF;
 	if (strcmp(token, "IN") == 0) return IN;
 	if (strcmp(token, "INCREASE") == 0) return INCREASE;
 	if (strcmp(token, "INTERVAL") == 0) return INTERVAL;
 	if (strcmp(token, "READ") == 0) return READ;
 	if (strcmp(token, "MAXIMUM") == 0) return MAXIMUM;
 	if (strcmp(token, "MINIMUM") == 0) return MINIMUM;
 	if (strcmp(token, "NOW") == 0) return NOW;
 	if (strcmp(token, "RANGE") == 0) return RANGE;
 	if (strcmp(token, "THEN") == 0) return THEN;
 	if (strcmp(token, "TRUE") == 0) return TRUE;
 	if (strcmp(token, "UPPERCASE") == 0) return UPPERCASE;
 	if (strcmp(token, "LATEST") == 0) return LATEST;
 	if (strcmp(token, "EARLIEST") == 0) return EARLIEST;
 	if (strcmp(token, "AS") == 0) return AS;
 	if (strcmp(token, "WHERE") == 0) return WHERE;
 	if (strcmp(token, "YEAR") == 0) return YEAR;
 	if (strcmp(token, "MONTH") == 0) return MONTH;
 	if (strcmp(token, "WEEK") == 0) return WEEK;
 	if (strcmp(token, "HOURS") == 0) return HOURS;
 	if (strcmp(token, "MINUTES") == 0) return MINUTES;
 	if (strcmp(token, "SECONDS") == 0) return SECONDS;
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

%left COMMA .
%nonassoc WHERE .
%left AMPERSAND .
%nonassoc LT GREATER .
%nonassoc ISWITHIN ISNOTWITHIN .
%nonassoc ISBEFORE ISNOTBEFORE .
%nonassoc OCCUR .
%nonassoc IN .
%nonassoc ISNUMBER ISNOTNUMBER ISLIST ISNULL IS .
%left RANGE .
%left PLUS MINUS .
%left TIMES DIVIDE .
%right POWER .
%nonassoc NOT .
%right UNMINUS .
%nonassoc BEFORE .
%nonassoc YEAR MONTH WEEK DAY HOURS MINUTES SECONDS .
%right UPPERCASE COUNT AVERAGE MAXIMUM MINIMUM FIRST LATEST EARLIEST INCREASE INTERVAL .
%right TIMEOF .
%right SQRT .
%right READ .
%right ANY .
%right OF .

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
statement(r) ::= TIME optional_of IDENTIFIER(i) ASSIGN ex(e) SEMICOLON .
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

optional_of ::= OF . [OF]
optional_of ::= . [OF]

ex(r) ::= TIME optional_of ex(a) . [TIMEOF]
{ r = unary("TIME", a); }

ex(r) ::= READ ex(a) .
{ r = unary("READ", a); }

ex(r) ::= SQRT ex(a) .
{ r = unary("SQRT", a); }

ex(r) ::= UPPERCASE optional_of ex(a) .
{ r = unary("UPPERCASE", a); }

ex(r) ::= MAXIMUM optional_of ex(a) .
{ r = unary("MAXIMUM", a); }

ex(r) ::= MINIMUM optional_of ex(a) .
{ r = unary("MINIMUM", a); }

ex(r) ::= AVERAGE optional_of ex(a) .
{ r = unary("AVERAGE", a); }

ex(r) ::= ANY optional_of ex(a) .
{ r = unary("ANY", a); }

ex(r) ::= FIRST optional_of ex(a) .
{ r = unary("FIRST", a); }

ex(r) ::= LATEST optional_of ex(a) .
{ r = unary("LATEST", a); }

ex(r) ::= EARLIEST optional_of ex(a) .
{ r = unary("EARLIEST", a); }

ex(r) ::= COUNT optional_of ex(a) .
{ r = unary("COUNT", a); }

ex(r) ::= INCREASE optional_of ex(a) .
{ r = unary("INCREASE", a); }

ex(r) ::= INTERVAL optional_of ex(a) .
{ r = unary("INTERVAL", a); }

// Duration operators
ex(r) ::= ex(a) YEAR .
{ r = unary("YEAR", a); }

ex(r) ::= ex(a) MONTH .
{ r = unary("MONTH", a); }

ex(r) ::= ex(a) WEEK .
{ r = unary("WEEK", a); }

ex(r) ::= ex(a) DAY .
{ r = unary("DAY", a); }

ex(r) ::= ex(a) HOURS .
{ r = unary("HOURS", a); }

ex(r) ::= ex(a) MINUTES .
{ r = unary("MINUTES", a); }

ex(r) ::= ex(a) SECONDS .
{ r = unary("SECONDS", a); }

ex(r) ::= MINUS ex(a) . [UNMINUS]
{ r = unary("UNMINUS", a); }

ex(r) ::= ex(a) IS NUMBER . [ISNUMBER]
{ r = unary("ISNUMBER", a); }

ex(r) ::= ex(a) IS NOT NUMBER . [ISNOTNUMBER]
{ r = unary("ISNOTNUMBER", a); }

ex(r) ::= ex(a) IS LIST . [ISLIST]
{ r = unary("ISLIST", a); }

ex(r) ::= ex(a) IS NULLTOK . [ISNULL]
{ r = unary("ISNULL", a); }

ex(r) ::= ex(a) IS GREATER THAN ex(b) . [GREATER]
{ r = binary("ISGREATERT", a, b); }

ex(r) ::= ex(a) OCCUR EQUAL ex(b) . [OCCUR]
{ r = binary("OCCUREQUAL", a, b); }

ex(r) ::= ex(a) OCCUR AT ex(b) . [OCCUR]
{ r = binary("OCCUREQUAL", a, b); }

ex(r) ::= ex(a) OCCUR BEFORE ex(b) . [OCCUR]
{ r = binary("OCCURBEFORE", a, b); }

ex(r) ::= ex(a) OCCUR AFTER ex(b) . [OCCUR]
{ r = binary("OCCURAFTER", a, b); }

ex(r) ::= ex(a) OCCUR WITHIN ex(b) TO ex(c) . [OCCUR]
{ r = ternary("OCCURWITHIN", a, b, c); }

ex(r) ::= ex(a) OCCUR WITHIN SAME DAY AS ex(b) . [OCCUR]
{ r = binary("OCCURSAMEDAYAS", a, b); }

ex(r) ::= ex(a) AMPERSAND ex(b) .
{r = binary ("AMPERSAND", a, b); }

ex(r) ::= ex(a) LT ex(b) .
{r = binary ("LT", a, b); }

ex(r) ::= ex(a) WHERE ex(b) .
{r = binary ("WHERE", a, b); }

ex(r) ::= ex(a) RANGE ex(b) .
{r = binary ("RANGE", a, b); }

ex(r) ::= ex(a) PLUS ex(b) .
{r = binary ("PLUS", a, b); }

ex(r) ::= ex(a) MINUS ex(b) .
{r = binary ("MINUS", a, b); }

ex(r) ::= ex(a) BEFORE ex(b) .
{r = binary ("BEFORE", a, b); }

ex(r) ::= ex(a) TIMES ex(b) .
{r = binary ("TIMES", a, b); }

ex(r) ::= ex(a) DIVIDE ex(b) .
{r = binary ("DIVIDE", a, b); }

ex(r) ::= ex(a) POWER ex(b) .
{r = binary ("POWER", a, b); }

ex(r) ::= ex(a) IS NOT WITHIN ex(b) TO ex(c) . [ISNOTWITHIN]
{r = ternary ("ISNOTWITHIN", a, b, c); }

ex(r) ::= ex(a) IS WITHIN ex(b) TO ex(c) . [ISWITHIN]
{r = ternary ("ISWITHIN", a, b, c); }

ex(r) ::= ex(a) IS BEFORE ex(b) . [ISBEFORE]
{r = binary ("ISBEFORE", a, b); }

ex(r) ::= ex(a) IS NOT BEFORE ex(b) . [ISNOTBEFORE]
{r = binary ("ISNOTBEFORE", a, b); }

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
