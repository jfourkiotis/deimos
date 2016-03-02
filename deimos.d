import std.stdio : writeln, write;
import std.conv;
import std.variant;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;

class Environment
{
    Environment base;
    Object[string] frame;

    static this()
    {
        Empty = new Environment(null);
        Global= Environment.Setup();
    }

    this(Environment base)
    {
        this.base = base;
    }

    Environment EnclosingEnvironment()
    {
        return base;
    }

    Object Lookup(string name)
    {
        if (name in frame)
        {
            return frame[name];
        } else if (base)
        {
            return base.Lookup(name);
        } else 
        {
            fprintf(stderr, "Unbound variable '%s'", name.ptr);
            exit(-1);
        }
        assert(0);
    }

    void SetVariable(string name, Object value)
    {
        if (this == Empty)
        {
            fprintf(stderr, "Unbound variable '%s'", name.ptr);
            exit(-1);
        } else if (name in frame)
        {
            frame[name] = value;
        } else if (base)
        {
            base.SetVariable(name, value);
        } else 
        {
            fprintf(stderr, "Fatal error");
            exit(-1);
        }
    }

    void DefineVariable(string name, Object value)
    {
        frame[name] = value;
    }

    static Environment Extend(Object params, Object args, Environment env)
    {
        auto new_env = new Environment(env);

        Object nil = Object(EmptyList());
        while (params != nil)
        {
            string *symbol = car(params).peek!(string);
            if (symbol)
            {
                new_env.DefineVariable(*symbol, car(args));
            } else 
            {
                fprintf(stderr, "Invalid param");
                exit(-1);
                params = cdr(params);
                args = cdr(args);
            }
        }

        return new_env;
    }

    static Environment Setup()
    {
        return Extend(Object(EmptyList()), Object(EmptyList()), Empty);
    }

    static Environment Empty;
    static Environment Global;
}

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

Object car(Object object)
{
    return (*object.peek!(ConsCell)).car;
}

Object cdr(Object object)
{
    return (*object.peek!(ConsCell)).cdr;
}

Object cadr(Object object)
{
    return car(cdr(object));
}

// scheme value
// string type is used for symbols
// char[] type is used for strings
alias Object = Algebraic!(long, bool, char, string, char[], EmptyList, ConsCell, void function(This*, This*));

bool isSymbol(Object object)
{
    return object.peek!(string) !is null;
}

bool isVariable(Object object)
{
    return isSymbol(object);
}

struct Symbols
{
    static this()
    {
        QUOTE = Object("quote");
        DEFINE= Object("define");
        SET   = Object("set!");
        OK    = Object("ok");
        IF    = Object("if");
    }

    static Object QUOTE;
    static Object DEFINE;
    static Object SET;
    static Object OK;
    static Object IF;
}

// READ
bool isDelimiter(int c)
{
    return isspace(c) || c == EOF ||
           c == '('   || c == ')' ||
           c == '"'   || c == ';';
}

bool isInitial(int c)
{
    return isalpha(c) || c == '*' || c == '/' || c == '>' ||
             c == '<' || c == '=' || c == '?' || c == '!';
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
    } else if (isInitial(c) || ((c == '+' || c == '-') && isDelimiter(peek(stream)))) /* read a symbol */
    {
        char[] buffer;
        while (isInitial(c) || isdigit(c) || c == '+' || c == '-')
        {
            buffer ~= c;
            c = getc(stream);
        }
        if (isDelimiter(c))
        {
            ungetc(c, stream);
            return Object(buffer.idup);
        } else 
        {
            fprintf(stderr, "Symbol not followed by delimiter. Found '%c'\n", c);
            exit(-1);
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
        return Object(buffer);
    } else if (c == '(') /* read the empty list or pair */
    {
        return readPair(stream);
    } else if (c == '\'') /* read quoted expression */
    {
        return Object(new ConsCell(Symbols.QUOTE, Object(new ConsCell(read(stream), Object(EmptyList())))));
    } else 
    {
        fprintf(stderr, "Bad input. Unexpected '%c'\n", c);
        exit(-1);
    }
    assert(0);
}

// EVAL
bool isSelfEvaluating(Object expression)
{
    return expression.peek!(bool) || expression.peek!(long) || expression.peek!(char) || expression.peek!(char[]);
}

bool isTaggedList(Object expression, Object tag)
{
    if (expression.peek!(ConsCell))
    {
        auto car = (*expression.peek!(ConsCell)).car;
        return car == tag;
    }
    return false;
}

bool isQuoted(Object expression)
{
    return isTaggedList(expression, Symbols.QUOTE);
}

Object textOfQuotation(Object expression)
{
    return cadr(expression);
}

bool isAssignment(Object expression)
{
    return isTaggedList(expression, Symbols.SET);
}

Object assignmentVariable(Object expression)
{
    return cadr(expression);
}

Object assignmentValue(Object expression)
{
    return cadr(cdr(expression));
}

Object evalAssignment(Object expression, Environment env)
{
    Object variable = assignmentVariable(expression);
    string *name = variable.peek!(string);
    //TODO: error handling
    env.SetVariable(*name, eval(assignmentValue(expression), env));
    return Symbols.OK;
}

Object evalDefinition(Object expression, Environment env)
{
    Object variable = definitionVariable(expression);
    string *name = variable.peek!(string);
    //TODO: error handling
    env.DefineVariable(*name, eval(definitionValue(expression), env));
    return Symbols.OK;
}

bool isDefinition(Object expression)
{
    return isTaggedList(expression, Symbols.DEFINE);
}  

Object definitionVariable(Object expression)
{
    return cadr(expression);
}

Object definitionValue(Object expression)
{
    return cadr(cdr(expression));
}

// if
bool isIfExpression(Object expression)
{
    return isTaggedList(expression, Symbols.IF);
}

Object ifExpressionPredicate(Object expression)
{
    return cadr(expression);
}

Object ifExpressionConsequent(Object expression)
{
    return cadr(cdr(expression));
}

Object ifExpressionAlternative(Object expression)
{
    if (cdr(cdr(cdr(expression))) == Object(EmptyList()))
    {

        return Object(false);
    } else 
    {
        return cadr(cdr(cdr(expression)));
    }
}

// application
bool isApplication(Object expression)
{
    return expression.peek!(ConsCell) !is null;
}   

Object applicationOperator(Object expression)
{
    return car(expression);
}

Object applicationOperands(Object expression)
{
    return cdr(expression);
}

Object firstOperand(Object ops)
{
    return car(ops);
}

Object restOperands(Object ops)
{
    return cdr(ops);
}

bool isNoOperands(Object ops)
{
    return ops == Object(EmptyList());
}

Object listOfValues(Object expressions, Environment env)
{
    if (isNoOperands(expressions))
    {
        return Object(EmptyList());
    }
    auto first = eval(firstOperand(expressions), env);
    auto rest  = listOfValues(restOperands(expressions), env);
    return Object(new ConsCell(first, rest));
}

Object eval(Object expression, Environment env)
{
tailcall:
    if (isSelfEvaluating(expression))
    {
        return expression;
    } else if (isVariable(expression))
    {
        string *name = expression.peek!(string);
        return env.Lookup(*name);
    } else if (isQuoted(expression))
    {
        return textOfQuotation(expression);
    } else if (isAssignment(expression))
    {
        return evalAssignment(expression, env);
    } else if (isDefinition(expression))
    {
        return evalDefinition(expression, env);
    } else if (isIfExpression(expression))
    {
        auto pred = ifExpressionPredicate(expression);
        auto pred_value = eval(pred, env);
        if (pred_value != false)
        {
            expression = ifExpressionConsequent(expression);
        } else 
        {
            expression = ifExpressionAlternative(expression);
        }
        goto tailcall;
    } else if (isApplication(expression))
    {
        auto operator = applicationOperator(expression);
        auto procedure= eval(operator, env);
        auto operands = applicationOperands(expression);
        auto arguments= listOfValues(operands, env);

        Object ret;
        procedure(&arguments, &ret);
        return ret;
    } else 
    {
        fprintf(stderr, "Cannot eval unknown expression type\n");
        writeln(expression);
        exit(-1);
    }
    assert(0);
}

// PRINT
string charToString(char c)
{
    if (c == '\n') return "#\\newline";
    else if (c == ' ') return "#\\space";
    else return "#\\" ~ to!string(c);
}

string strToString(immutable char[] s)
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
    return obj.visit!(
            (bool b)   => b ? "#t" : "#f",
            (long n)   => to!string(n)   ,
            (char c)   => charToString(c),
            (string s) => s              ,
            (char[] s) => strToString(s.idup) ,
            (EmptyList empty) => "()"    ,
            (ConsCell cell)   => "(" ~ cellToString(cell) ~ ")",
            (void function(Object*, Object*) prim) => "<#procedure>");
}

void print(Object obj)
{
   write(objToString(obj));
}

void addProc(Object *args, Object *ret)
{
    long result = 0;
    Object current = *args;
    while (current != Object(EmptyList()))
    {
        result += car(current).get!long;
        current = cdr(current);
    }
    *ret = result;
}

void main()
{
    Environment.Global.DefineVariable("+", Object(&addProc));

    writeln("Welcome to Deimos Scheme. Use ctrl-c to exit.");
    while (true)
    {
        write("> ");
        print(eval(read(stdin), Environment.Global));
        write("\n");
    }
}
