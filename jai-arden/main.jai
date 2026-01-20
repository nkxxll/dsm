#import,file "tokenizer.jai";
#import,file "parser.jai";
#import,file "interpreter.jai";
#import,file "cjson/linux.jai";

// we need c_free to free the c string form the parser generator and cjson
crt :: #library,system "libc";
c_free :: (memory: *void) #foreign crt "free";

INPUT :: #string DONE
write 5;
write "hello";
write [1, 2, 3];
write true;
write null;
write 2026-11-01T10:10:10;
DONE


main :: () {
    tokens := scan_tokens(INPUT, false);
    defer free(tokens.data);


    json := token_list_to_json(tokens);
    print("JSON: %\n", json);
    defer free(json);

    ast := parse_json(json);
    print("AST: %\n", to_string(ast));
    defer c_free(ast);

    cjson := cJSON_Parse(ast);
    defer cJSON_Delete(cjson);

    interpret(cjson);
}

#import "Basic";
