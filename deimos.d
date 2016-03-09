import std.stdio : writeln, write;
import std.conv;
import std.variant;
import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;

struct EmptyList {}; // NIL

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

class CompoundProc
{
    Object params;
    Object procBody;
    Environment env;

    this(Object params, Object pbody, Environment env)
    {
        this.params = params;
        this.procBody = pbody;
        this.env = env;
    }
}

// scheme value
// string type is used for symbols
// char[] type is used for strings
alias Object = Algebraic!(long, bool, char, string, char[], EmptyList, ConsCell, void function(This*, This*), CompoundProc);

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
        LAMBDA= Object("lambda");
        NIL   = Object(EmptyList());
        TRUE  = Object(true);
        FALSE = Object(false);
    }

    static Object QUOTE;
    static Object DEFINE;
    static Object SET;
    static Object OK;
    static Object IF;
    static Object LAMBDA;
    static Object NIL;
    static Object TRUE;
    static Object FALSE;
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
        return Symbols.NIL;
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
                return Symbols.TRUE;
            case 'f':
                return Symbols.FALSE;
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
        return Object(new ConsCell(Symbols.QUOTE, Object(new ConsCell(read(stream), Symbols.NIL))));
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
    return expression.peek!(bool) != null || 
           expression.peek!(long) != null ||
           expression.peek!(char) != null || 
           expression.peek!(char[]) != null;
}

bool isTaggedList(Object expression, Object tag)
{
    ConsCell *cell = expression.peek!(ConsCell);
    if (cell !is null)
    {
        auto car = (*cell).car;
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
    if (cadr(expression).peek!(string) !is null)
    {
        return cadr(expression);
    } else 
    {
        return car(cadr(expression));
    }
}

Object definitionValue(Object expression)
{
    if (cadr(expression).peek!(string) !is null)
    {
        return cadr(cdr(expression));
    } else 
    {
        return makeLambda(cdr(cadr(expression)), cdr(cdr(expression)));
    }
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
    if (cdr(cdr(cdr(expression))) == Symbols.NIL)
    {

        return Symbols.FALSE;
    } else 
    {
        return cadr(cdr(cdr(expression)));
    }
}

// lambda
// (lambda (<args>) <body>)
bool isLambda(Object expression)
{
    return isTaggedList(expression, Symbols.LAMBDA);
}

Object lambdaParameters(Object expression)
{
    return cadr(expression);
}

Object lambdaBody(Object expression)
{
    return cdr(cdr(expression));
}

Object makeLambda(Object params, Object lbody)
{
    return Object(new ConsCell(Symbols.LAMBDA, Object(new ConsCell(params, lbody))));
}

bool isLastExpression(Object seq)
{
    return cdr(seq) == Symbols.NIL;
}

Object firstExpression(Object seq)
{
    return car(seq);
}

Object restExpressions(Object seq)
{
    return cdr(seq);
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
    return ops == Symbols.NIL;
}

Object listOfValues(Object expressions, Environment env)
{
    if (isNoOperands(expressions))
    {
        return Symbols.NIL;
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
    } else if (isLambda(expression))
    {
        auto params = lambdaParameters(expression);
        auto lbody  = lambdaBody(expression);
        return Object(new CompoundProc(params, lbody, env));
    } else if (isApplication(expression))
    {
        auto operator = applicationOperator(expression);
        auto procedure= eval(operator, env);
        auto operands = applicationOperands(expression);
        auto arguments= listOfValues(operands, env);

        if (procedure.peek!(void function(Object *, Object *)) !is null)
        {
            Object ret;
            procedure(&arguments, &ret);
            return ret;
        } else if (procedure.peek!(CompoundProc) != null)
        {
            auto cp = *procedure.peek!(CompoundProc);
            env = Environment.Extend(cp.params, arguments, cp.env);
            expression = cp.procBody;
            while (!isLastExpression(expression))
            {
                eval(firstExpression(expression), env);
                expression = restExpressions(expression);
            }

            expression = firstExpression(expression);
            goto tailcall;
        } else 
        {
            fprintf(stderr, "Unknown procedure type\n");
            exit(-1);
        }
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
    if (cdr.peek!(ConsCell) !is null)
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
            (void function(Object*, Object*) prim) => "<#procedure>",
            (CompoundProc cp) => "<#compound-procedure>");
}

void print(Object obj)
{
   write(objToString(obj));
}

// ENVIRONMENT + PROCEDURES
void addProc(Object *args, Object *ret)
{
    long result = 0;
    Object current = *args;
    while (current != Symbols.NIL)
    {
        result += car(current).get!long;
        current = cdr(current);
    }
    *ret = result;
}

void subProc(Object *args, Object *ret)
{
    Object current = *args;
    long result = car(current).get!long;
    
    while ((current = cdr(current)) != Symbols.NIL)
    {
        result -= car(current).get!long;
    }

    *ret = result;
}

void mulProc(Object *args, Object *ret)
{
    long result = 1;
    Object current = *args;
    while (current != Symbols.NIL)
    {
        result *= (car(current)).get!long;
        current = cdr(current);
    }
    *ret = result;
}

void quotientProc(Object *args, Object *ret)
{
    *ret = car(*args).get!long / cadr(*args).get!long;
}

void remainderProc(Object *args, Object *ret)
{
    *ret = car(*args).get!long % cadr(*args).get!long;
}

void areNumEqual(Object *args, Object *ret)
{
    Object current = *args;
    long value = car(current).get!(long);
    while ((current = cdr(current)) != Symbols.NIL)
    {
        if (value != car(current).get!(long))
        {
            *ret = Symbols.FALSE;
            return;
        }
    }
    *ret = Object(true);
}

void isLessThanProc(Object *args, Object *ret)
{
    long previous, next;
    Object current = *args;
    previous = car(current).get!long;
    while ((current = cdr(current)) != Symbols.NIL)
    {
        next = car(current).get!long;
        if (previous < next) 
        {
            previous = next;
        } else 
        {
            *ret = Symbols.FALSE;
            return;
        }
    }
    *ret = Symbols.TRUE;
}

void isGreaterThanProc(Object *args, Object *ret)
{
    long previous, next;
    Object current = *args;
    previous = car(current).get!long;
    while ((current = cdr(current)) != Symbols.NIL)
    {
        next = car(current).get!long;
        if (previous > next) 
        {
            previous = next;
        } else 
        {
            *ret = Symbols.FALSE;
            return;
        }
    }
    *ret = Symbols.TRUE;
}

void exitProc(Object *args, Object *ret)
{
    exit(-1);
}

void isNullProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    if (tmp == Symbols.NIL)
    {
        *ret = Symbols.TRUE;
    } else
    {
        *ret = Symbols.FALSE;
    }
}

void isBooleanProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(bool) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isSymbolProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(string) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isIntegerProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(long) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isCharProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(char) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isStringProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(char[]) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isPairProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(ConsCell) !is null ? Symbols.TRUE : Symbols.FALSE;
}

void isProcedureProc(Object *args, Object *ret)
{
    auto tmp = car(*args);
    *ret = tmp.peek!(void function(Object*, Object*)) !is null ? Symbols.TRUE : Symbols.FALSE;
}   

void charToIntegerProc(Object *args, Object *ret)
{
    *ret = to!long(car(*args).get!char);
}

void integerToCharProc(Object *args, Object *ret)
{
    *ret = to!char(car(*args).get!long);
}

void numberToStringProc(Object *args, Object *ret)
{
    *ret = to!string(car(*args).get!long);
}

void stringToNumberProc(Object *args, Object *ret)
{
    *ret = to!long(car(*args).get!string);
}

void symbolToStringProc(Object *args, Object *ret)
{
    char[] str = car(*args).get!string.dup;
    *ret = Object(str);
}

void stringToSymbolProc(Object *args, Object *ret)
{
    string str = car(*args).get!(char[]).idup;
    *ret = Object(str);
}

void consProc(Object *args, Object *ret)
{
    *ret = Object(new ConsCell(car(*args), cadr(*args)));
}

void carProc(Object *args, Object *ret)
{
    *ret = car(car(*args));
}

void cdrProc(Object *args, Object *ret)
{
    *ret = cdr(car(*args));
}

void listProc(Object *args, Object *ret)
{
    *ret = *args;
}

void eqProc(Object *args, Object *ret)
{
    auto obj1 = car(*args);
    auto obj2 = cadr(*args);
    
    *ret = obj1 == obj2 ? Symbols.TRUE : Symbols.FALSE;
}

class Environment
{
    Environment base;
    Object[string] frame;

    static this()
    {
        Empty = new Environment(null);
        Global= Environment.Setup();

        Global.DefineVariable("null?"   , Object(&isNullProc));
        Global.DefineVariable("boolean?", Object(&isBooleanProc));
        Global.DefineVariable("symbol?" , Object(&isSymbolProc));
        Global.DefineVariable("integer?", Object(&isIntegerProc));
        Global.DefineVariable("char?"   , Object(&isCharProc));
        Global.DefineVariable("string?" , Object(&isStringProc));
        Global.DefineVariable("pair?"   , Object(&isPairProc));
        Global.DefineVariable("procedure?", Object(&isProcedureProc));
        Global.DefineVariable("char->integer" , Object(&charToIntegerProc));
        Global.DefineVariable("integer->char" , Object(&integerToCharProc));
        Global.DefineVariable("number->string", Object(&numberToStringProc));
        Global.DefineVariable("string->number", Object(&stringToNumberProc));
        Global.DefineVariable("symbol->string", Object(&symbolToStringProc));
        Global.DefineVariable("string->symbol", Object(&stringToSymbolProc));
        Global.DefineVariable("+", Object(&addProc));
        Global.DefineVariable("-", Object(&subProc));
        Global.DefineVariable("*", Object(&mulProc));
        Global.DefineVariable("quotient", Object(&quotientProc));
        Global.DefineVariable("remainder", Object(&remainderProc));
        Global.DefineVariable("=", Object(&areNumEqual));
        Global.DefineVariable("<", Object(&isLessThanProc));
        Global.DefineVariable(">", Object(&isGreaterThanProc));
        Global.DefineVariable("cons", Object(&consProc));
        Global.DefineVariable("car" , Object(&carProc));
        Global.DefineVariable("cdr" , Object(&cdrProc));
        Global.DefineVariable("list", Object(&listProc));
        Global.DefineVariable("eq?" , Object(&eqProc));
        Global.DefineVariable("exit", Object(&exitProc));
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

        Object nil = Symbols.NIL;
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
            }
            params = cdr(params);
            args = cdr(args);
        }

        return new_env;
    }

    static Environment Setup()
    {
        return Extend(Symbols.NIL, Symbols.NIL, Empty);
    }

    static Environment Empty;
    static Environment Global;
}//~ Environment

void main()
{

    writeln("Welcome to Deimos Scheme. Use ctrl-c to exit.");
    while (true)
    {
        write("> ");
        print(eval(read(stdin), Environment.Global));
        write("\n");
    }
}

