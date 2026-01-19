#import,file "tokenizer.jai";
#import,file "parser.jai";
#import,file "interpreter.jai";
#import,file "cjson/linux.jai";

// we need c_free to free the c string form the parser generator and cjson
crt :: #library,system "libc";
c_free :: (memory: *void) #foreign crt "free";

INPUT :: #string DONE
x := ["Hallo Welt", null, 4711, 2020-01-01T12:30:00, false, now];
trace x;
trace x is number;
trace x is list;


trace 1 + 2 * 4 / 5 - -3 + 4 ** 3 ** 2;
trace -2 ** 10;


y := [100,200,150];
trace [maximum y, average y, increase y];
trace uppercase ["Hallo", "Welt", 4711];
trace sqrt y;


x := 1 ... 7;
trace x;
trace x < 5;
trace x is not within (x - 1) to 5;


trace "Hallo" where it is not number;
trace [10,20,50,100,70,40,55] where it / 2 is within 30 to 60;


x := 4711;
time of x := 1999-09-19;
y := x;
time of y := 2022-12-22;
trace time of x;
trace time of y;

trace time of time of y;
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
