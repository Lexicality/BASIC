--[[

        ECMA-55 Minimalistic BASIC Parser
        * HEAVY WIP * (Use at your own risk!)
        Copyright 2012 Lexi Robinson

        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.

--]]

--SHUT_UP = true;
-- INFINITE_LOOP_PROTECTION = true;

-- casual stack based shenanigans
local push = table.insert;
local pop = table.remove;
local head = function(t) return t[#t]; end

-- io nonsense
local stdin = io.input();
local stdout = io.output();

--[[

        Tables

--]]

local lines = {};
local linelookup = {};

local variables = {};
local arrays = {};
local functions = {};
local arr_lower_bound = false;

local expressions = {};
local syntaxes = {};

--[[

        Useful shit

--]]

LINE_NUMBER = 0;
ACTIVE_LINE = nil;

-- Just to allow the system to be debugged with lua -i
function dump_variables()
    for var, value in pairs(variables) do
        if (value) then
            print(var .. ":", value)
        else
            print(var .. ":");
            local mdim = arrays[var].dimy;
            for keyx, valuex in ipairs(arrays[var]) do
                if (mdim) then
                    print('', keyx .. ':');
                    for keyy, valuey in ipairs(valuex) do
                        print('','', keyy .. ':', valuey);
                    end
                else
                    print('', keyx .. ':', valuex);
                end
            end
        end
    end
end

--[[

        Definition patterns

--]]
sign_expr = "[-+]?";
space_expr = "%s+";

expression_expr = "(.+)";
variable_expr = "(%u%d?)";
array_expr = variable_expr .. "%(" .. expression_expr .. "%)";

function noop() end

function validate_is_numeric(var)
    local val = variables[var];
    if (val == false) then
        error("Cannot treat array variable " .. var .. " as a single variable!", 0);
    elseif (val == nil) then
        variables[var] = 0;
    end
end
function validate_is_array(var)
    if (variables[var]) then
        error("Cannot treat single variable " .. var .. " as an array variable!", 0);
    end
    variables[var] = false;
end
function validate_is_number(num)
    if (type(num) ~= "number") then
        error("Expression did not evaluate to a number!", 0);
    end
end

do -- Expressions
    local function donumber(num)
        local nval = tonumber(num);
        if (not nval) then
            error("Cannot evaluate number '" .. num .. "'!", 0);
        end
        return function() return nval; end
    end
    functions = {
        ["ABS"] = math.abs;
        ["ATN"] = math.atan;
        ["COS"] = math.cos;
        ["EXP"] = math.exp;
        ["INT"] = math.floor;
        ["SIN"] = math.sin;
        ["TAN"] = math.tan;
        ["LOG"] = function(x)
            if (x <= 0) then
                error("LOG: X must be greater than 0!", 0);
            end
            return math.log(x);
        end;
        ["SGN"] = function(x)
            if (x < 0) then
                return -1;
            elseif (x == 0) then
                return 0;
            else
                return 1;
            end
        end;
        ["SQR"] = function(x)
            if (x < 0) then
                error("SQR: X must be nonnegative!", 0);
            end
            return math.sqrt(x);
        end;
    }

    local exprs = {
        -- String lit eral
        ["\"(.*)\""] = function(str)
            return function() return str; end;
        end;

        -- Integer literal
        [sign_expr .. "%d+"] = donumber;
        -- Decimal literal
        [sign_expr .. "[%d]*%.[%d]+"] = donumber;

        -- String variable
        ["%u$"] = function(var)
            return function() return variables[var] or ""; end
        end;
        -- Numeric variable
        [variable_expr] = function(var)
            validate_is_numeric(var);
            return function()
                return variables[var];
            end
        end;
        -- Array variable
        [array_expr] = function(var, expr)
            validate_is_array(var);
            local expr1, expr2 = arr_get_subscript_exprs(expr);

            return function()
                local arr, ss1, ss2 = arr_validate_and_get_everything(var, expr1, expr2);
                -- And now get the value
                local value = arr[ss1];
                if (ss2) then
                    value = value[ss2];
                end
                return value;
            end
        end;
        -- Parameterless function
        ["%u%u%u"] = function(func)
            if (string.match(func, "FN%u")) then
                local expr = functions[string.sub(func, 3)];
                if (not expr) then
                    error("Unknown user defined function " .. func .. "!", 0);
                end
                return expr;
            elseif (func == "RND") then
                return math.random;
            else
                error("Unknown function " .. func .. "!", 0);
            end
        end;

        -- Function
        ["(%u%u%u)%(" .. expression_expr .. "%)"] = function(func, expr)
            expr = expression(expr);
            local callback;
            if (string.match(func, "FN%u")) then
                callback = functions[string.sub(func, 3) .. "()"];
                if (not callback) then
                    error("Unknown user defined function " .. func .. "!", 0);
                end
            else
                callback = functions[func];
                if (not callback) then
                    error("Unknown function " .. func .. "!", 0);
                end
            end
            return function()
                local num = expr();
                if (type(num) ~= "number") then
                    error("Attempted to call function with non-number parameter!", 0);
                end
                return callback(num);
            end
        end;

    }
    for pattern, callback in pairs(exprs) do
        expressions["^" .. pattern .. "$"] = callback;
    end
end


do -- Lines
    local relation_opers = {
        ["=" ] = function(a,b) return a == b; end;
        ["<>"] = function(a,b) return a ~= b; end;
        ["<" ] = function(a,b) return a <  b; end;
        [">" ] = function(a,b) return a >  b; end;
        ["<="] = function(a,b) return a <= b; end;
        [">="] = function(a,b) return a >= b; end;
    };
    local callstack = {};
    local forstack = {};
    local nogoto = {};
    local gotolist = {};
    -- Save a random number for reseeding the rng later
    local rnd = math.random();
    local function do_dim(var, dimx, dimy)
    end

    local syns = {
        -- IO
        -- input (duh)
        ["INPUT" .. space_expr .. expression_expr] = function(expr)
            local assigns = {};
            local type_string, type_number = 1,2;
            local  exprs = split_exprs(expr);
            for k, var in pairs(exprs) do
                if (var == ';') then
                    error("Unexpected ';' in variable list", 0);
                elseif (var ~= ',') then
                    if (string.match(var, "^%u$$")) then
                        -- Super simple string variable
                        -- FIXME: String variables are supposed to be limited to 18 characters
                        push(assigns, {type_string, function(value)
                            variables[var] = value;
                        end});
                    elseif (string.match(var, "^" .. variable_expr .. "$")) then
                        -- Normal var. Almost as simple as strings
                        validate_is_numeric(var);
                        push(assigns, {type_number, function(value)
                            -- Declare a new numeric
                            variables[var] = value;
                        end});
                    elseif (string.match(var, "^" .. array_expr .. "$")) then
                        -- Array. Delegate to helper functions like crazy
                        local var, arrexp = string.match(var, "^" .. array_expr .. "$");
                        validate_is_array(var);
                        local expr1, expr2 = arr_get_subscript_exprs(arrexp);
                        push(assigns, {type_number, function(value)
                            local arr, ss1, ss2 = arr_validate_and_get_everything(var, expr1, expr2);
                            if (ss2) then
                                arr[ss1][ss2] = value;
                            else
                                arr[ss1] = value;
                            end
                        end});
                    else
                        error("Malformed variable name '".. var .. "'!", 0);
                    end
                end
            end
            local numassigns = #assigns;
            return function()
                repeat
                    stdout:write("Please enter " .. numassigns .. " inputs:\n> ");
                    local line = stdin:read();
                    if (not line) then
                        error("Cannot read from STDIN!", 0);
                    end
                    local exprs = split_strings(line);
                    if (#exprs == numassigns) then
                        local redo = false;
                        for i, tab in ipairs(assigns) do
                            local expr = exprs[i];
                            if (tab[1] == type_number) then
                                local num = tonumber(expr);
                                if (not num) then
                                    stdout:write("Cannot convert input #" .. i .. " to a number!\n");
                                    redo = true;
                                    break;
                                end
                                tab[2](num);
                            else
                                -- FIXME: Strings are supposed to be limitd to 18 chars
                                tab[2](expr);
                            end
                        end
                        if (not redo) then
                            break;
                        end
                    else
                        if (#exprs > numassigns) then
                            stdout:write("Error: Too many (" .. #exprs .. ") inputs entered! ");
                        else
                            stdout:write("Error: Too few (" .. #exprs .. ") inputs entered! ");
                        end
                    end
                until false;
            end;
        end;
        -- output
        ["PRINT" .. space_expr .. expression_expr] = function(expr)
            local exprs = split_exprs(expr);
            for k, expr in pairs(exprs) do
                if (expr ~= '' and expr ~= ',' and expr ~= ';') then
                    exprs[k] = expression(expr);
                end
            end
            return function()
                local toprint = {};
                -- FIXME: Formatting is supposed to be more complex than this
                -- FIXME: if head(exprs) = ';' or ',' then no \n at the end
                -- TODO: Support TAB()
                for _, expr in ipairs(exprs) do
                    if (expr == ',') then
                        push(toprint, '\t');
                    elseif (expr ~= ';' and expr ~= '') then
                        expr = expr();
                        if (expr ~= '') then
                            push(toprint, expr);
                        end
                    end
                end
                print(table.concat(toprint,''));
            end
        end;
        -- Functions
        ["DEF" .. space_expr .. "FN(%u)%s*%(" .. variable_expr .. "%)" .. space_expr .. "=" .. space_expr .. expression_expr] = function(name, param, expr)
            if (functions[name] ~= nil) then
                error("Attempted to redefine function FN" .. name .. "!", 0);
            end
            -- Get around static type checking
            local val = variables[param];
            variables[param] = 0;
            expr = expression(expr);
            variables[param] = val;
            -- hurf
            functions[name] = false;
            functions[name .. "()"] = function(value)
                local prev = variables[param];
                variables[param] = value;
                local ret = expr();
                variables[param] = prev;
                return ret;
            end
            return function() end
        end;
        ["DEF" .. space_expr .. "FN(%u)" .. space_expr .. "=" .. space_expr .. expression_expr] = function(name, expr)
            expr = expression(expr);
            if (functions[name] ~= nil) then
                error("Attempted to redefine function FN" .. name .. "!", 0);
            end
            functions[name] = function(value)
                return expr();
            end
            return function() end
        end;
        -- Variabellius
        -- Assignment
        ["LET" .. space_expr .. "(%u.-)" .. space_expr .. "=" .. space_expr .. expression_expr] = function(var, expr)
            expr = expression(expr);
            if (string.match(var, "^%u$$")) then
                -- Super simple string variable
                -- FIXME: String variables are supposed to be limited to 18 characters
                return function()
                    variables[var] = expr();
                end
            elseif (string.match(var, "^" .. variable_expr .. "$")) then
                -- Normal var. Almost as simple as strings
                validate_is_numeric(var);
                return function()
                    local val = expr();
                    validate_is_number(val);
                    variables[var] = expr();
                end
            elseif (string.match(var, "^" .. array_expr .. "$")) then
                -- Array. Delegate to helper functions like crazy
                local var, arrexp = string.match(var, "^" .. array_expr .. "$");
                validate_is_array(var);
                local expr1, expr2 = arr_get_subscript_exprs(arrexp);
                return function()
                    local arr, ss1, ss2 = arr_validate_and_get_everything(var, expr1, expr2);
                    if (ss2) then
                        arr[ss1][ss2] = expr();
                    else
                        arr[ss1] = expr();
                    end
                end
            else
                error("Malformed variable name '".. var .. "'!", 0);
            end
        end;
        -- Dimensioning
        ["DIM" .. space_expr .. "(%u.+)"] = function(expr)
            if (not arr_lower_bound) then
                arr_lower_bound = 0;
            end
            local exprs = split_exprs(expr);
            local calls = {};
            for _, expr in ipairs(exprs) do
                if (expr ~= ',') then
                    -- Extract the var name
                    local var, dims = string.match(expr, variable_expr .. "%s*%(" .. expression_expr .. "%)");
                    if (not var) then
                        error("Don't know what to do with '" .. expr .. "'!", 0);
                    end
                    -- Validachion
                    validate_is_array(var);
                    if (arrays[var]) then
                        error("Attempted to set dimensions on existing array variable " .. var .. "!", 0);
                    end
                    -- Extract the dimensions
                    local dimx, dimy = string.match(dims, "(%d+),?(%d*)");
                    if (not dimx) then
                        error("Don't know what to do with " .. dims .. "!", 0);
                    end
                    dimx, dimy = tonumber(dimx), tonumber(dimy);
                    -- Fling em out
                    arr_validate_subscript(dimx, 128);
                    if (dimy) then
                        arr_validate_subscript(dimy, 128);
                    end
                    arr_new(var, dimx, dimy);
                end
            end
            return noop;
        end;
        -- Mucking about
        ["OPTION" .. space_expr .. "BASE" .. space_expr .. "(%d)"] = function(num)
            num = tonumber(num)
            if (num ~= 0 and num ~= 1) then
                error("Invalid base '" .. num .. "'!", 0);
            end
            if (arr_lower_bound) then
                error("Lower bound has already been set to " .. arr_lower_bound .. "!", 0);
            end
            arr_lower_bound = num;
            return noop;
        end;
        -- Control statements
        -- FOR
        ["FOR" .. space_expr .. variable_expr .. space_expr .. "=" .. space_expr .. expression_expr .. space_expr .. "TO" .. space_expr .. expression_expr .. "(.*)"] = function(var, init, limit, step_expr)
            -- Santiy check
            for _, line in pairs(forstack) do
                if (line.loopdata.var == var) then
                    error("Cannot start a FOR block with control variable " .. var .. " inside existing FOR block with control variable " .. var .. "! (Starts on line " .. line.num .. ")", 0);
                end
            end
            -- Sanity check #2
            validate_is_numeric(var);
            -- Parse step
            local step;
            if (step_expr == '') then
                step = '1';
            else
                step = string.match(step_expr, space_expr .. "STEP" .. space_expr .. expression_expr);
                if (not step) then
                    error("Don't know what to do with '" .. step_expr .. "'!", 0);
                end
            end
            --
            init  = expression(init);
            limit = expression(limit);
            step  = expression(step);
            local loopdata = {
                var = var;
                forline = ACTIVE_LINE;
            };
            ACTIVE_LINE.loopdata = loopdata;
            push(forstack, ACTIVE_LINE);
            return function()
                local init = init();
                validate_is_number(init);
                local limit = limit();
                validate_is_number(limit);
                local step = step();
                validate_is_number(step);
                local sign = functions["SGN"](step);
                loopdata.step = step;
                loopdata.compare = function()
                    return (variables[var] - limit) * sign > 0;
                end
                variables[var] = init;
                if (loopdata.compare()) then
                    return loopdata.nextline.next.num;
                end
            end
        end;
        ["NEXT" .. space_expr .. variable_expr] = function(var)
            local forline = pop(forstack);
            if (not forline) then
                error("NEXT statement without an opening FOR statement!", 0);
            elseif (forline.loopdata.var ~= var) then
                error("NEXT " .. var .. " does not match most recent FOR " .. forline.loopdata.var .. " statement!", 0);
            end
            forline.loopdata.nextline = ACTIVE_LINE;
            ACTIVE_LINE.loopdata = forline.loopdata;
            push(nogoto, {forline.num, LINE_NUMBER});
            local loopdata = forline.loopdata;
            return function()
                variables[var] = variables[var] + loopdata.step;
                if (not loopdata.compare()) then
                    return loopdata.forline.next.num;
                end
            end
        end;
        -- GOTO
        ["GO%s*TO" .. space_expr .. "(%d+)"] = function(target)
            target = tonumber(target);
            if (not linelookup[target]) then
                error("Line #" .. target .." does not exist!");
            end
            push(gotolist, {LINE_NUMBER, target});
            return function()
                return target;
            end
        end;
        -- IF THEN
        ["IF" .. space_expr .. expression_expr .. space_expr ..
         "([<>=][>=]?)" .. space_expr .. expression_expr .. space_expr ..
         "THEN" .. space_expr .. "(%d+)"] = function(exp1, rel, exp2, target)
            target = tonumber(target);
            if (not linelookup[target]) then
                error("Line #" .. target .." does not exist!");
            end
            push(gotolist, {LINE_NUMBER, target});
            local relfunc = relation_opers[rel];
            if (not relfunc) then
                error("Unknown relation operator '" .. rel .. "'!", 0);
            end
            exp1,exp2 = expression(exp1), expression(exp2);
            return function()
                local a,b = exp1(), exp2();
                if (type(a) ~= type(b)) then
                    error("Attempted to compare invalid types!", 0);
                end
                if (relfunc(a, b)) then
                    return target;
                end
            end
        end;
        ["ON" .. space_expr .. expression_expr .. space_expr ..
         "GO%s*TO" .. space_expr .. "(.+)"] = function(expr, lines)
            local templines = split_exprs(lines);
            lines = {};
            for i, v in ipairs(templines) do
                if (v ~= ',') then
                    local num = tonumber(v)
                    if (not num) then
                        error("Unexpected '" .. v .. "' in line number list", 0);
                    end
                    push(gotolist, {LINE_NUMBER, num});
                if (not linelookup[num]) then
                    error("Line #" .. num .." does not exist!");
                end
                    table.insert(lines, num);
                end
            end
            expr = expression(expr);
            return function()
                local num = expr();
                validate_is_numeric(num);
                num = math.floor(num);
                local target = lines[num];
                if (not target) then
                    error("Expression evaluated to " .. num .. " which is not in the range 1 <= X <= " .. #lines .. "!", 0);
                end
                return target;
            end
        end;
        ["GO%s*SUB" .. space_expr .. "(%d+)"] = function(target)
            target = tonumber(target);
            if (not linelookup[target]) then
                error("Line #" .. target .." does not exist!");
            end
            push(gotolist, {LINE_NUMBER, target});
            return function()
                push(callstack, ACTIVE_LINE.next.num);
                return target;
            end
        end;
        ["RETURN"] = function()
            return function()
                local target = pop(callstack);
                if (not target) then
                    error("Called RETURN while not in a GOSUB situation!", 0);
                end
                return target;
            end
        end;
        -- Comment
        ["REM.*"] = function() return function() end end;
        -- Randoms
        ["RANDOMIZE"] = function()
            return function()
                math.randomseed(os.time() * os.clock() / rnd);
            end
        end;
        -- Yebugger
        ["DEBUGGER"] = function() return dump_variables; end;
        -- End of main program
        ["END"] = function()
            return function()
                return -1;
            end
        end;
        -- Halt program
        ["STOP"] = function()
            return function()
                return -2;
            end
        end;
    }
    for pattern, callback in pairs(syns) do
        syntaxes["^" .. pattern .. "$"] = callback;
    end
    function goto_santiycheck()
        for _, jumpdata in pairs(gotolist) do
            local lineno = jumpdata[1];
            local target = jumpdata[2];
            for _, range in pairs(nogoto) do
                if (target > range[1] and target <= range[2]) then
                    if (lineno < range[1] or lineno > range[2]) then
                        error("Line " .. jumpdata[1] .. ": Cannot jump inside FOR block!", 0);
                    end
                end
            end
        end
    end
    function for_sanitycheck()
        local unmatched = head(forstack);
        if (unmatched) then
            error("Unfinished for block! (Starts on line " .. unmatched.num .. " using loop variable " .. unmatched.loopdata.var .. ")", 0);
        end
    end
end

-- Numerical operators
--[[

        Ye Array functiones

--]]

function arr_validate_subscript(value, upper_bound)
    if (type(value) ~= "number") then
        error("Array subscript expression evaluted to a non-number value!", 0);
    end
    value = math.floor(value);
    if (value < arr_lower_bound or value > upper_bound) then
        error("Array subscript expression evaluated to " .. value .. " which is not in the range " .. arr_lower_bound .. " <= X <= " .. upper_bound .. "!", 0);
    end
    return value;
end

function arr_new(name, dimx, dimy)
    if (not arr_lower_bound) then
        arr_lower_bound = 0;
    end
    local arr = {
        dimx = dimx;
        dimy = dimy;
    }
    if (dimy) then
        local row;
        for x = arr_lower_bound, dimx do
            row = {};
            for y = arr_lower_bound, dimy do
                row[y] = 0;
            end
            arr[x] = row;
        end
    else
        for x = arr_lower_bound, dimx do
            arr[x] = 0;
        end
    end
    arrays[name] = arr;
    -- Disable any future numerics
    variables[name] = false;
    return arr;
end

function arr_get_subscript_exprs(expr)
    if (expr == '') then
        error("Subscript cannot be blank!", 0);
    end
    local exprarr = split_exprs(expr);
    if (not (#exprarr == 1 or (#exprarr == 3 and exprarr[2] == ','))) then
        error("Malformed array subscript '" .. expr .. "'!", 0);
    end
    return expression(exprarr[1]), exprarr[3] and expression(exprarr[3]);
end

function arr_validate_and_get_everything(var, expr1, expr2)
    -- Check for numerics first. This lets paramters in functions temporarily override arrays
    validate_is_array(var)
    local arr = arrays[var] or arr_new(var, 10, expr2 and 10);
    -- Check for using the wrong dimensionality
    if (expr2 and not arr.dimy) then
        error("Cannot treat single dimensional array " .. var .. " as a multi dimensional array!", 0);
    elseif (arr.dimy and not expr2) then
        error("Cannot treat multi dimensional array " .. var .. " as a single dimensional array!", 0);
    end
    -- Get our actual subscripts
    local ss1 = arr_validate_subscript(expr1(), arr.dimx);
    local ss2;
    if (expr2) then
        ss2 = arr_validate_subscript(expr2(), arr.dimy);
    end
    return arr, ss1, ss2;
end

--[[

        Parsing functions

--]]
do
    local RET_CONTINUE, RET_SPLIT = 0,1;
    local replace = function(a,b) pop(a); push(a,b); end;
    local whitespace = {[' '] = true; ['\t'] = true;};
    do
        local seperators = {[';'] = true; [','] = true;};
        local startup, expression, quoted_string, parens, seperator_only;
        startup = function(char)
            if (whitespace[char]) then
                return RET_CONTINUE;
            elseif (seperators[char]) then
                -- A blank expr
                return RET_SPLIT;
            elseif (char == '"') then
                return RET_CONTINUE, push, quoted_string;
            else
                return RET_CONTINUE, push, expression;
            end
        end
        expression = function(char)
            if (seperators[char]) then
                return RET_SPLIT, pop;
            elseif (char == '(') then
                return RET_CONTINUE, push, parens;
            else
                return RET_CONTINUE;
            end
        end
        quoted_string = function(char)
            if (char == '"') then
                -- The only thing that can come after a " is a ; or ,
                return RET_CONTINUE, replace, seperator_only;
            else
                return RET_CONTINUE;
            end
        end
        parens = function(char)
            if (char == '(') then
                return RET_CONTINUE, push, parens;
            elseif (char == ')') then
                return RET_CONTINUE, pop;
            else
                return RET_CONTINUE;
            end
        end
        seperator_only = function(char)
            if (seperators[char]) then
                return RET_SPLIT, pop;
            elseif (whitespace[char]) then
                return RET_CONTINUE;
            else
                return "Expected seperator after string!";
            end
        end
        function split_exprs(exprlist)
            local stack = {startup};
            local exprs = {};
            local last = 0;
            -- Make sure the last expression is definitely parsed
            exprlist = exprlist .. ","
            local char, ret, func, arg;
            for i = 1, #exprlist do
                char = string.sub(exprlist, i, i);
                ret, func, arg = head(stack)(char);
                if (ret == RET_SPLIT) then
                    local expr = string.sub(exprlist, last + 1, i - 1);
                    -- strip whitespace away
                    expr = string.match(expr, "%s*(.*)%s*");
                    table.insert(exprs, expr);
                    table.insert(exprs, char);
                    last = i;
                elseif (ret ~= RET_CONTINUE) then
                    error("Malformed expression: " .. ret, 0);
                end
                if (func) then
                    func(stack, arg);
                end
            end
            if (#stack > 1) then
                local kind = head(stack);
                error("Malformed expression: Unmatched " .. (kind == quoted_string and '"' or kind == parens and '(' or "something???") .. " in expression!", 0);
            end
            -- Remove that final seperator we added earlier
            table.remove(exprs);
            return exprs;
        end
    end

    do
        local seperators = {[','] = true;};
        local startup, unquoted_string, quoted_string, seperator_only;
        startup = function(char)
            if (whitespace[char]) then
                return RET_CONTINUE;
            elseif (seperators[char]) then
                -- A blank expr
                return RET_SPLIT;
            elseif (char == '"') then
                return RET_CONTINUE, push, quoted_string;
            else
                return RET_CONTINUE, push, unquoted_string;
            end
        end
        unquoted_string = function(char)
            if (not string.match(char, "[+-.%d%a%s]")) then
                return "Unexpected " .. char .. " in unquoted string!";
            elseif (seperators[char]) then
                return RET_SPLIT, pop;
            else
                return RET_CONTINUE;
            end
        end
        quoted_string = function(char)
            if (char == '"') then
                -- The only thing that can come after a " is a ; or ,
                return RET_CONTINUE, replace, seperator_only;
            else
                return RET_CONTINUE;
            end
        end
        seperator_only = function(char)
            if (seperators[char]) then
                return RET_SPLIT, pop;
            elseif (whitespace[char]) then
                return RET_CONTINUE;
            else
                return "Expected seperator after string!";
            end
        end
        function split_strings(exprlist)
            local stack = {startup};
            local exprs = {};
            local last = 0;
            -- Make sure the last expression is definitely parsed
            exprlist = exprlist .. ","
            local char, ret, func, arg;
            for i = 1, #exprlist do
                char = string.sub(exprlist, i, i);
                ret, func, arg = head(stack)(char);
                if (ret == RET_SPLIT) then
                    local expr = string.sub(exprlist, last + 1, i - 1);
                    -- strip whitespace away
                    expr = string.match(expr, "%s*(.*)%s*");
                    table.insert(exprs, expr);
                    table.insert(exprs, char);
                    last = i;
                elseif (ret ~= RET_CONTINUE) then
                    error("Malformed expression: " .. ret, 0);
                end
                if (func) then
                    func(stack, arg);
                end
            end
            if (#stack > 1) then
                local kind = head(stack);
                error("Malformed expression: Unmatched " .. (kind == quoted_string and '"'  or "something???") .. " in expression!", 0);
            end
            -- Remove that final seperator we added earlier
            table.remove(exprs);
            return exprs;
        end
    end
end

do -- Expressions
    local function expr_is_operator(token)
        return string.find(token, "^[-+*/^~]$");
    end

    local function expr_explode(expr)
        local tokens = {}
        for a, b in string.gmatch(expr, "%s*(.-)%s*([-+/*^)(])") do
            if (a ~= '') then
                table.insert(tokens, a)
            end
            table.insert(tokens, b)
        end
        table.insert(tokens, string.match(expr, ".*%" .. tokens[#tokens] .. "%s*(.-)$"));
        return tokens;
    end

    local function expr_compact_funcs(tokens)
        local parens = 0;
        local line = nil;
        local lastwasopr = true;
        for i, o in ipairs(tokens) do
            if (o == '(' and not lastwasopr) then
                if (parens == 0) then
                    line = i - 1;
                end
                parens = parens + 1;
                lastwasopr = false;
            end
            if (parens > 0) then
                if (o == ')') then
                    parens = parens - 1;
                end
                tokens[i] = '';
                tokens[line] = tokens[line] .. o;
            else
                lastwasopr = expr_is_operator(o);
            end
        end

        local exprs = {};
        for i, exp in ipairs(tokens) do
            if (exp ~= "") then
                table.insert(exprs, exp);
            end
        end
        return exprs;
    end

    local function expr_unary_minus(tokens)
        local lastwasopr = true;
        for i, o in ipairs(tokens) do
            if (o == '-' and lastwasopr) then
                tokens[i] = '~';
            else
                lastwasopr = expr_is_operator(o) or string.find(o, "^[)(]$");
            end
        end
    end

    local precedence = {
        ["^"] = 1;
        ["*"] = 2;
        ["/"] = 2;
        ["+"] = 3;
        ["-"] = 3;
        ["~"] = 3;
    }
    -- Note: ^ is left assoc according to ECMA-55. God knows why.
    local function left_assoc(token)
        return token ~= "~";-- and token ~= "^";
    end
    local function expr_shunting_yard(tokens)
        local output = {};
        local stack = {};

        for _, token in ipairs(tokens) do

            -- (s go onto the stack without any kind of fuss
            if (token == "(") then
                push(stack, token);
            -- )s pop the stack down to the next (
            elseif (token == ")") then
                local found = false
                while (head(stack) ~= nil) do
                    local oper = pop(stack);
                    if (oper == "(") then
                        found = true;
                        break;
                    end
                    push(output, oper);
                end
                if (not found) then
                    error("Malformed expression: Unattached ) found!", 0)
                end
            elseif (expr_is_operator(token)) then
                local prec = precedence[token];
                local oper = head(stack);
                while (oper ~= nil and expr_is_operator(oper)) do
                    local oprec = precedence[oper]
                    -- either o1 is left-associative and its precedence is less than or equal
                    -- to that of o2, or o1 has precedence less than that of o2,
                    if (oprec < prec or (left_assoc(token) and oprec == prec)) then
                        push(output, pop(stack));
                    else
                        break;
                    end
                    oper = head(stack);
                end
                push(stack, token);
            else
                push(output, token);
            end
        end
        while (head(stack)) do
            local token = pop(stack);
            if (token == "(") then
                error("Malformed expression: Unattached ( found!", 0);
            end
            push(output, token);
        end
        return output;
    end

    local operators = {
        -- NOTE: operands are BACKWARDS
        ["^"] = function(b,a) return function() return a() ^ b() end end;
        ["*"] = function(b,a) return function() return a() * b() end end;
        ["/"] = function(b,a) return function() return a() / b() end end;
        ["+"] = function(b,a) return function() return a() + b() end end;
        ["-"] = function(b,a) return function() return a() - b() end end;
        ["~"] = function(a)   return function() return     - a() end end;
    }
    local function is_unary(token)
        return token == "~";
    end
    local function expr_rpn_parse(tokens)
        local stack = {};
        for _, token in ipairs(tokens) do
            local callback = operators[token]
            if (callback) then
                if (is_unary(token)) then
                    if (#stack < 1) then
                        error("Malformed expression: Unary operator '" .. token .. "' without an operand!", 0);
                    end
                    push(stack, callback(pop(stack)));
                else
                    if (#stack < 2) then
                        error("Malformed expression: Binary operator '" .. token .. "' without two operands!", 0);
                    end
                    push(stack, callback(pop(stack), pop(stack)));
                end
            else
                push(stack, expression(token));
            end
        end
        if (#stack ~= 1) then
            error("Malformed expression: Unbalanced operators!", 0);
        end
        return stack[1];
    end

    function expression(expr)
        -- Argh, unfortunately .+ is overly greedy and can eat spaces on either side that it shouldn't.
        expr = string.match(expr, "^%s*(.-)%s*$");
        for pattern, callback in pairs(expressions) do
            if (string.find(expr, pattern)) then
                if (not SHUT_UP) then
                    print("Expression matched pattern ", pattern)
                end
                return callback(string.match(expr, pattern));
            end
        end
        -- See if we can parse it into a numerical expr
        if (not string.find(expr, "[-+*/^]")) then
            error("Could not decode expression '" .. expr .. "'!", 0);
        end
        -- Break the string up into operators and operands
        local tokens = expr_explode(expr);
        -- Jam function calls back into strings
        -- This is a bit inefficient as it causes them to be parsed again, but
        --  doing so simplifies the hell out of everything so fuck it.
        tokens = expr_compact_funcs(tokens);

        if (not SHUT_UP) then
            print ("Expression is arithmetic: ", "'" .. table.concat(tokens, "','") .. "'");
        end

        -- Change unary minuses into ~s for comfort and convenience
        expr_unary_minus(tokens);

        -- Shunt the operators into RPN
        tokens = expr_shunting_yard(tokens);

        -- Parse the RPN into a function expression
        return expr_rpn_parse(tokens);
    end
end

local function parseline(linedata)
    ACTIVE_LINE = linedata;
    LINE_NUMBER = linedata.num;
    for pattern, callback in pairs(syntaxes) do
        if (string.find(linedata.text, pattern)) then
            if (not SHUT_UP) then
                print("Line matched pattern ", pattern);
            end
            linedata.func = callback(string.match(linedata.text, pattern));
            break;
        end
    end

    if (not linedata.func) then
        error("Line did not match any known keywords!", 0);
    end
end


local function sanitytest()
    -- Find out if anything's b0rk'd
    goto_santiycheck();
    for_sanitycheck();
end
--[[

        Actual running of the code

--]]


-- Disable noisy errors
debug.traceback = nil;

-- EMCA-55 section 9.6 demands a constant pseudo-random seed at the start of execution
math.randomseed(0x1337C0DE);

do
    local rawlines = {};

    local input;

    local target = arg[1];
    local interactive = false
    if (target == nil or target == '-') then
        interactive = true;
        print "Enter program";
        input = stdin;
    elseif (target == "--") then
        -- stdin but quiet.
        input = stdin;
    else
        input = io.input(target);
    end

    -- get the lines out of stdin
    local num, expr;
    repeat
        -- prompt
        if (interactive) then
            stdout:write("> ");
        end
        local line = input:read();
        -- EOF
        if (line == nil) then
            break;
        end
        -- Make sure lines are well formed
        num, expr = string.match(line, "^(%d+)%s+(.+)%s*$");
        if (num) then
            num = tonumber(num)
            if (rawlines[num]) then
                print("Warning: Line " .. num .. " already exists as '" .. rawlines[num] .. "'.");
                print("Replacing line " .. num .. " with " .. expr .. ".");
            end
            rawlines[num] = expr;
        elseif (not string.find(line, "^%s*$")) then
            print("Warning: Ignored malformed line " .. line);
        end
        -- ECMA-55 states that the end statement is always the last statement
        if (expr == "END") then
            break;
        end
    until line == nil;
    -- ECMA-55 states that all programs must end with an END statement
    if (expr ~= "END") then
        error("No END statement encountered!", 0);
    end


    -- turn the lines into objects
    for num, line in pairs(rawlines) do
        local linedata = {
            num = num;
            text = line;
        };
        linelookup[num] = linedata;
        table.insert(lines, linedata);
    end
end

-- Make sure we actually have a program
if (#lines == 0) then
    error("No program entered!", 0);
end

-- make sure everything's in order
table.sort(lines, function(a, b) return a.num < b.num end);

-- make sure we know where to go next
for i, linedata in ipairs(lines) do
    local nextline = lines[i + 1];
    if (nextline) then
        linedata.next = nextline;
    end
end

local y,e;

-- parse ye lines
print "Parsing...";
for _, linedata in ipairs(lines) do

    if (not SHUT_UP) then
        print(linedata.num, "'" .. linedata.text .. "'");
    end
    y, e = pcall(parseline, linedata);
    if (not y) then
        error("Cannot parse line " .. linedata.num .. ": " .. e, 0);
    end
end

sanitytest();

print "Running:";

activeline = lines[1];

local i = 0;

repeat
    ACTIVE_LINE = activeline;
    LINE_NUMBER = activeline.num;

    -- io.write(LINE_NUMBER .. ',');

    y,e = pcall(activeline.func);
    if (not y) then
        error("Error on line " .. LINE_NUMBER .. ": " .. e, 0);
    elseif (e) then
        if (e == -1) then
            print("Program has reached the END statement.");
            break;
        elseif (e == -2) then
            print("Program has reached a STOP statement.");
            break;
        end
        -- Asking for a redirect
        activeline = linelookup[e];
        if (activeline == nil) then
            error("Line " .. linenumber .. " attempted to redirect to unknown line " .. e .. "!", 0);
        end
    else
        activeline = activeline.next;
        if (not activeline) then
            error("Program has run out of lines!", 0);
        end
    end
    if (INFINITE_LOOP_PROTECTION) then
        i = i + 1;
        if (i == 1000) then
            print("Killed by anti-infinite-loop protection!");
            break;
        end
    end
until activeline == nil;
print("Program ended on line " .. LINE_NUMBER);
