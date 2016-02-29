import std.stdio : writeln, write;
import std.conv;
import std.variant;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;

struct EmptyList {};

class ConsCell
{
    Object car;
    Object cdr;

    this(Object car, Object cdr)
    {
        this.car = car;
        this.cdr = cdr;
    }
}

// scheme value
alias Object = Algebraic!(long, bool, char, string, EmptyList, ConsCell);

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

Object readPair(FILE *stream)
{
    eatWhitespace(stream);

    int c = getc(stream);
    if (c == ')') 
    {
        return Object(EmptyList());
    }
    ungetc(c, stream);

    Object car = read(stream);

    eatWhitespace(stream);

    c = getc(stream);
    if (c == '.') /* read improper list */
    {
        c = peek(stream);
        if (!isDelimiter(c))
        {
            fprintf(stderr, "Dot not followed by delimiter\n");
            exit(-1);
        }
        Object cdr = read(stream);
        eatWhitespace(stream);
        c = getc(stream);
        if (c != ')')
        {
            fprintf(stderr, "Where was that trailing right paren?\n");
            exit(-1);
        }
        return Object(new ConsCell(car, cdr));
    } else /* read list */
    {
        ungetc(c, stream);
        Object cdr = readPair(stream);
        return Object(new ConsCell(car, cdr));
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
    } else if (c == '(') /* read the empty list or pair */
    {
        return readPair(stream);
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

string cellToString(ConsCell cell)
{
    Object car = cell.car;
    Object cdr = cell.cdr;
 
    string s1 = objToString(car);
    if (cdr.peek!(ConsCell))
    {
        return s1 ~ " " ~ cellToString(*cdr.peek!(ConsCell));
    } else if (cdr.peek!(EmptyList))
    {
        return s1;
    } else 
    {
        return s1 ~ " . " ~ objToString(cdr);
    }
}

string objToString(Object obj)
{
    return obj.visit!((bool b)   => b ? "#t" : "#f",
            (long n)   => to!string(n)   ,
            (char c)   => charToString(c),
            (string s) => strToString(s) ,
            (EmptyList empty) => "()"    ,
            (ConsCell cell)   => "(" ~ cellToString(cell) ~ ")");
}

void print(Object obj)
{
   write(objToString(obj));
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
