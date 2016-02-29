import std.stdio : writeln, write;
import std.conv;
import std.variant;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;

// scheme value
alias Object = Algebraic!(long, bool, char, string);
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

void eatExpectedString(FILE *stream, string str)
{
    int c = 0;
    foreach (char ch ; str)
    {
        c = getc(stream);
        if (ch != c)
        {
            fprintf(stderr, "Unexpected character '%c'\n", c);
            exit(-1);
        }
    }
}

void peekExpectedDelimiter(FILE *stream)
{
    if (!isDelimiter(peek(stream)))
    {
        fprintf(stderr, "Character not followed by delimiter\n");
        exit(-1);
    }
}

Object readCharacter(FILE *stream)
{
    int c = getc(stream);
    switch (c)
    {
        case EOF:
            fprintf(stderr, "Incomplete character literal\n");
            exit(-1);
        case 's':
            if (peek(stream) == 'p')
            {
                eatExpectedString(stream, "pace");
                peekExpectedDelimiter(stream);
                return Object(' ');
            }
            break;
        case 'n':
            if (peek(stream) == 'e')
            {
                eatExpectedString(stream, "ewline");
                peekExpectedDelimiter(stream);
                return Object('\n');
            }
            break;
        default: break;
    }
    peekExpectedDelimiter(stream);
    return Object(to!char(c));
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
            case '\\':
                return readCharacter(stream);
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
    } else if (c == '"') /* read a string */
    {
        char[] buffer;
        while ((c = getc(stream)) != '"')
        {
            if (c == '\\')
            {
                c = getc(stream);
                if (c == 'n')
                {
                    c = '\n';
                }
            }
            if (c == EOF)
            {
                fprintf(stderr, "Non-terminated string literal\n");
                exit(-1);
            }
            buffer ~= c;
        }
        return Object(buffer.idup);
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
string charToString(char c)
{
    if (c == '\n') return "#\\newline";
    else if (c == ' ') return "#\\space";
    else return "#\\" ~ to!string(c);
}

string strToString(string s)
{
    char[] buffer;

    buffer ~= '"';
    foreach (char c ; s)
    {
        if (c == '\n') buffer ~= "\\n";
        else if (c == '\\') buffer ~= "\\\\";
        else if (c == '"') buffer ~= "\\\"";
        else buffer ~= c;
    }
    buffer ~= '"';
    return buffer.idup;
}

void print(Object obj)
{
    auto str = obj.visit!((bool b)   => b ? "#t" : "#f",
                          (long n)   => to!string(n),
                          (char c)   => charToString(c),
                          (string s) => strToString(s));
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
