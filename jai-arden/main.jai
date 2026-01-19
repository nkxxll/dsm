#import,file "tokenizer.jai";
#import,file "parser.jai";
#import,file "interpreter.jai";
#import,file "cjson/linux.jai";

// we need c_free to free the c string form the parser generator and cjson
crt :: #library,system "libc";
c_free :: (memory: *void) #foreign crt "free";

INPUT :: #string DONE
write "hello";
DONE


main :: () {
    tokens := scan_tokens(INPUT, false);
    defer free(tokens.data);
    json := token_list_to_json(tokens);
    defer free(json);

    ast := parse_json(json);
    defer c_free(ast);

    cjson := cJSON_Parse(ast);

    interpret(cjson);

    print("%\n", ast);
}

#import "Basic";
