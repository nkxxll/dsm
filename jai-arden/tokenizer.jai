Token :: struct {
    type:  Token_Type;    // The type/classification of the token
    value: string;        // The actual text representation
    line:  int;           // Line number where token appears
    start: int;           // Starting position in source
}

Lexer :: struct {
    src:            string;         // Source code being tokenized
    tokens:         [..]Token;      // Output token stream
    line:           int = 1;        // Current line number
    start:          int = 0;        // Start position of current token
    current:        int = 0;        // Current position in source
}

Token_Type :: enum u32 {
    THE;
    DAY;
    THAN;
    OF;
    SQRT;
    WITHIN;
    NOT;
    IS;
    OCCUR;
    SAME;
    AMPERSAND;
    ANY;
    ASSIGN;
    AVERAGE;
    BEFORE;
    COMMA;
    COUNT;
    CURRENTTIME;
    DIVIDE;
    DO;
    DOT;
    EARLIEST;
    ELSE;
    ELSEIF;
    ENDDO;
    ENDIF;
    EQ;
    FALSE;
    FIRST;
    FOR;
    GREATER;
    GT;
    GTEQ;
    HOURS;
    IDENTIFIER;
    IF;
    IN;
    INCREASE;
    INTERVAL;
    LAST;
    LATEST;
    LPAR;
    LSPAR;
    LT;
    LTEQ;
    LIST;
    MAXIMUM;
    MINIMUM;
    MINUTES;
    MINUS;
    NEQ;
    NOW;
    NULL;
    NUMTOKEN;
    PLUS;
    POWER;
    RANGE;
    READ;
    RPAR;
    RSPAR;
    SECONDS;
    SEMICOLON;
    STRTOKEN;
    SUM;
    THEN;
    TIME;
    TIMES;
    TIMETOKEN;
    TRACE;
    TRUE;
    UPPERCASE;
    AS;
    WRITE;
    WHERE;
    NUMBER;
    TO;
    YEAR;
    MONTH;
    WEEK;
    UNKNOWN;
}

print_tokens :: (tokens: []Token) {
    print("[\n");
    for token: tokens {
        print("Token: %\n", token);
    }
    print("]\n");
}

scan_tokens :: (src: string, debug_log: bool = true) -> []Token {
    lexer := Lexer.{ src = src };
    scan(*lexer);
    if debug_log print_tokens(lexer.tokens);
    return array_view(lexer.tokens, 0);
}

scan :: (using lexer: *Lexer) {
    while !is_at_end(lexer) {
        start = current;                    // Mark token start
        current_char := consume(lexer);     // Read next character

        // or continue but it does its job 0 is end of file/string
        if current_char == 0 return;

        // Route to appropriate handler based on character type
        if is_space(current_char) {
            if current_char == #char "\n" {
                line += 1;
            }
        }
        else if current_char == #char "\"" {
            string_literal(lexer);          // Handle string literals
        }
        else if is_alpha(current_char) || current_char == "_" {
            current -= 1;                   // Back up to re-read the character
            ident_or_keyword(lexer);        // Handle identifiers/keywords
        }
        else if is_digit(current_char) {
            current -= 1;                   // Back up to re-read the character
            number(lexer);                  // Handle numeric literals
        }
        else {
            scan_operator(lexer, current_char);
        }
    }
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && (is_alnum(lexer.src[lexer.current]) || lexer.src[lexer.current] == #char "_") {
        consume(lexer);
    }
    str := slice(src, start, current - start);
    token_type := ident(str);              // Lookup in keyword table
    token := Token.{ token_type, str, line, start };
    array_add(*tokens, token);
}

is_at_end :: (using lexer: *Lexer) -> bool {
    // just to be save
    assert(current >= start);
    return src.count <= current;
}

// return the next char 0 if the end was reached
peek :: (lexer: *Lexer) -> u8 {
    if (lexer.current + 1 >= lexer.src.count) {
        return 0;
    }

    result := lexer.src[lexer.current + 1];
    return result;
}

consume :: (lexer: *Lexer) -> u8 {
    if is_at_end(lexer) return 0;
    result := lexer.src[lexer.current];
    lexer.current += 1;
    return result;
}

consume_comment :: (using lexer: *Lexer) {
    // Skip everything until end of line
    while !is_at_end(lexer) && lexer.src[lexer.current] != #char "\n" {
        consume(lexer);
    }
}

number :: (using lexer: *Lexer) {
    // Read initial digits
    while !is_at_end(lexer) && is_digit(lexer.src[lexer.current]) {
        consume(lexer);
    }

    // Check for decimal point (float)
    has_decimal := false;
    if !is_at_end(lexer) && (lexer.src[lexer.current] == #char ".") && (lexer.current + 1 < lexer.src.count) && is_digit(lexer.src[lexer.current + 1]) {
        has_decimal = true;
        consume(lexer);  // consume '.'
        while !is_at_end(lexer) && is_digit(lexer.src[lexer.current]) {
            consume(lexer);
        }
    }

    // Check for ISO time format (contains '-' or ':')
    has_time_chars := false;
    temp_current := current;
    while temp_current < src.count && (src[temp_current] == #char "-" || src[temp_current] == #char ":" || is_digit(src[temp_current]) || src[temp_current] == #char "T") {
        if src[temp_current] == #char "-" || src[temp_current] == #char ":" {
            has_time_chars = true;
        }
        temp_current += 1;
    }

    literal := slice(src, start, temp_current);

    // If we detected time characters, parse as TIMETOKEN, otherwise as number
    token_type: Token_Type;
    if has_time_chars {
        // Try to parse ISO time format
        if is_valid_iso_time(literal) {
            token_type = .TIMETOKEN;
            current = temp_current;
        } else {
            // Fall back to number if time parsing fails
            token_type = .NUMTOKEN;
        }
    } else {
        token_type = .NUMTOKEN;
    }

    literal = slice(src, start, current - start);
    token := Token.{ token_type, literal, line, start };
    array_add(*tokens, token);
}

is_valid_iso_time :: (literal: string) -> bool {
    // Basic validation for ISO time formats:
    // YYYY-MM-DD, YYYY-MM-DDTHH:MM, YYYY-MM-DDTHH:MM:SS, etc.
    parts := split(literal, "-");
    if parts.count < 3 return false;

    // First part should be 4 digits (year)
    if parts[0].count != 4 return false;
    for char: parts[0] {
        if !is_digit(char) return false;
    }

    // Month should be 2 digits
    if parts[1].count < 2 return false;
    if !is_digit(parts[1][0]) || !is_digit(parts[1][1]) return false;

    return true;
}

ident :: (str: string) -> Token_Type {
    lower := to_lower_copy(str);
    defer free(lower);

    if lower == {
        case "the";
            return .THE;
        case "day";
            return .DAY;
        case "days";
            return .DAY;
        case "than";
            return .THAN;
        case "of";
            return .OF;
        case "sqrt";
            return .SQRT;
        case "within";
            return .WITHIN;
        case "not";
            return .NOT;
        case "is";
            return .IS;
        case "occur";
            return .OCCUR;
        case "occurs";
            return .OCCUR;
        case "occurred";
            return .OCCUR;
        case "same";
            return .SAME;
        case "ampersand";
            return .AMPERSAND;
        case "any";
            return .ANY;
        case "assign";
            return .ASSIGN;
        case "average";
            return .AVERAGE;
        case "before";
            return .BEFORE;
        case "comma";
            return .COMMA;
        case "count";
            return .COUNT;
        case "currenttime";
            return .CURRENTTIME;
        case "divide";
            return .DIVIDE;
        case "do";
            return .DO;
        case "dot";
            return .DOT;
        case "earliest";
            return .EARLIEST;
        case "else";
            return .ELSE;
        case "elseif";
            return .ELSEIF;
        case "enddo";
            return .ENDDO;
        case "endif";
            return .ENDIF;
        case "eq";
            return .EQ;
        case "false";
            return .FALSE;
        case "first";
            return .FIRST;
        case "for";
            return .FOR;
        case "greater";
            return .GREATER;
        case "gt";
            return .GT;
        case "gteq";
            return .GTEQ;
        case "hours";
            return .HOURS;
        case "hour";
            return .HOURS;
        case "if";
            return .IF;
        case "in";
            return .IN;
        case "increase";
            return .INCREASE;
        case "interval";
            return .INTERVAL;
        case "last";
            return .LAST;
        case "latest";
            return .LATEST;
        case "lpar";
            return .LPAR;
        case "lspar";
            return .LSPAR;
        case "lt";
            return .LT;
        case "lteq";
            return .LTEQ;
        case "list";
            return .LIST;
        case "maximum";
            return .MAXIMUM;
        case "minimum";
            return .MINIMUM;
        case "minutes";
            return .MINUTES;
        case "minute";
            return .MINUTES;
        case "minus";
            return .MINUS;
        case "neq";
            return .NEQ;
        case "now";
            return .NOW;
        case "null";
            return .NULL;
        case "numtoken";
            return .NUMTOKEN;
        case "plus";
            return .PLUS;
        case "power";
            return .POWER;
        case "range";
            return .RANGE;
        case "read";
            return .READ;
        case "rpar";
            return .RPAR;
        case "rspar";
            return .RSPAR;
        case "seconds";
            return .SECONDS;
        case "second";
            return .SECONDS;
        case "semicolon";
            return .SEMICOLON;
        case "strtoken";
            return .STRTOKEN;
        case "sum";
            return .SUM;
        case "then";
            return .THEN;
        case "time";
            return .TIME;
        case "times";
            return .TIMES;
        case "timetoken";
            return .TIMETOKEN;
        case "trace";
            return .TRACE;
        case "true";
            return .TRUE;
        case "uppercase";
        return .UPPERCASE;
        case "as";
            return .AS;
        case "write";
            return .WRITE;
        case "where";
            return .WHERE;
        case "number";
            return .NUMBER;
        case "to";
            return .TO;
        case "year";
            return .YEAR;
        case "years";
            return .YEAR;
        case "month";
            return .MONTH;
        case "months";
            return .MONTH;
        case "week";
            return .WEEK;
        case "weeks";
            return .WEEK;
        case;
            return .IDENTIFIER;
    }
}

string_literal :: (using lexer: *Lexer) {
    // start points to the opening quote
    // consume the closing quote
    while !is_at_end(lexer) && lexer.src[lexer.current] != #char "\"" {
        if lexer.src[lexer.current] == #char "\n" {
            line += 1;
        }
        consume(lexer);
    }
    if !is_at_end(lexer) {
        consume(lexer);  // consume closing quote
    }
    str := slice(src, start, current - start);
    token := Token.{ .STRTOKEN, str, line, start };
    array_add(*tokens, token);
}

scan_operator :: (using lexer: *Lexer, ch: u8) {
    token_type: Token_Type;

    if ch == {
        case #char "+";
            token_type = .PLUS;
        case #char "-";
            token_type = .MINUS;
        case #char "*";
            // Check for ** (power)
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "*" {
                consume(lexer);
                token_type = .POWER;
            } else {
                token_type = .TIMES;
            }
        case #char "/";
            // Check for // (comment)
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "/" {
                consume_comment(lexer);
                return;
            }
            token_type = .DIVIDE;
        case #char "(";
            token_type = .LPAR;
        case #char ")";
            token_type = .RPAR;
        case #char "[";
            token_type = .LSPAR;
        case #char "]";
            token_type = .RSPAR;
        case #char ",";
            token_type = .COMMA;
        case #char "&";
            token_type = .AMPERSAND;
        case #char ";";
            token_type = .SEMICOLON;
        case #char "=";
            token_type = .EQ;
        case #char ":";
            // Check for := (assign)
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "=" {
                consume(lexer);
                token_type = .ASSIGN;
            } else {
                token_type = .UNKNOWN;
            }
        case #char "<";
            // Check for <=, <>
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "=" {
                consume(lexer);
                token_type = .LTEQ;
            } else if !is_at_end(lexer) && lexer.src[lexer.current] == #char ">" {
                consume(lexer);
                token_type = .NEQ;
            } else {
                token_type = .LT;
            }
        case #char ">";
            // Check for >=
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "=" {
                consume(lexer);
                token_type = .GTEQ;
            } else {
                token_type = .GT;
            }
        case #char ".";
            // Check for ... (range)
            if !is_at_end(lexer) && lexer.src[lexer.current] == #char "." &&
               lexer.current + 1 < lexer.src.count && lexer.src[lexer.current + 1] == #char "." {
                consume(lexer);
                consume(lexer);
                token_type = .RANGE;
            } else {
                token_type = .DOT;
            }
        case;
            token_type = .UNKNOWN;
    }

    str := slice(src, start, current - start);
    token := Token.{ token_type, str, line, start };
    array_add(*tokens, token);
}

token_list_to_json :: (token_list: []Token) -> string {
    builder : String_Builder;
    init_string_builder(*builder);
    token_list_view : []Token = token_list;
    token_list_view.count -= 1;
    print_to_builder(*builder, "[");
    for *token: token_list_view {
        if token.type == .STRTOKEN {
            // jump the start "
            token.value.data += 1;
            // jump the end "
            token.value.count -= 2;
            print_to_builder(*builder, "[\"%\", \"%\", \"%\"],", token.line, token.type, token.value);
        } else {
            print_to_builder(*builder, "[\"%\", \"%\", \"%\"],", token.line, token.type, token.value);
        }
    }
    last := token_list[token_list.count - 1];
    if last.type == .STRTOKEN {
        // jump the start "
        last.value.data += 1;
        // jump the end "
        last.value.count -= 2;
        print_to_builder(*builder, "[\"%\", \"%\", \"%\"]", last.line, last.type, last.value);
    } else {
        print_to_builder(*builder, "[\"%\", \"%\", \"%\"]", last.line, last.type, last.value);
    }
    print_to_builder(*builder, "]");
    return builder_to_string(*builder);
}

#import "Basic";
#import "String";
