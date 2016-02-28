import std.stdio : writeln, write;
import std.conv;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;
import std.variant;

// scheme value
alias Object = Algebraic!(long, bool);
/*
class ConsCell
{
    Object car;
    Object cdr;
}
*/

// READ
bool isDelimiter(int c)
{
    return isspace(c) || c == EOF ||
           c == '('   || c == ')' ||
           c == '"'   || c == ';';
}

int peek(FILE *stream)
{
    int c = getc(stream);
    ungetc(c, stream);
    return c;
}

void eatWhitespace(FILE *stream)
{
    int c;
    while ((c = getc(stream)) != EOF)
    {
        if (isspace(c)) continue;
        else if (c == ';') /* comments are whitespace also */
        {
            while ((c = getc(stream)) != EOF && c != '\n') {}
            continue;
        }
        ungetc(c, stream);
        break;
    }
}

Object read(FILE *stream)
{
    eatWhitespace(stream);
    int c = getc(stream);
    int sign = 1;
    long num = 0;
    if (c == '#') /* read a boolean */
    {
        c = getc(stream);
        switch (c)
        {
            case 't':
                return Object(true);
            case 'f':
                return Object(false);
            default:
                fprintf(stderr, "Unknown boolean literal\n");
                exit(-1);
        }
    } else if (isdigit(c) || (c == '-' && isdigit(peek(stream))))
    {
        if (c == '-') sign = -1;
        else 
            ungetc(c, stream);
        while (isdigit(c = getc(stream))) 
        {
            num = num * 10 + c - '0';
        }
        num *= sign;
        if (isDelimiter(c))
        {
            ungetc(c, stream);
            return Object(num);
        }
    } else 
    {
        fprintf(stderr, "Bad input. Unexpected '%c'\n", c);
        exit(-1);
    }
    assert(0);
}

// EVAL
Object eval(Object exp)
{
    return exp;
}

// PRINT
void print(Object obj)
{
    auto str = obj.visit!((bool b) => b ? "#t" : "#f",
                          (long n) => to!string(n));
    write(str);
}

void main()
{
    writeln("Welcome to Deimos Scheme. Use ctrl-c to exit.");
    while (true)
    {
        write("> ");
        print(eval(read(stdin)));
        write("\n");
    }
}