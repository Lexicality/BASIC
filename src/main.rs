/*
 * Copyright 2023 Lexi Robinson
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#![allow(dead_code)]

use chumsky::prelude::*;
use chumsky::text;

type VarName = String;
type LineNo = usize;

#[derive(Debug, Clone)]
struct StringVariable(VarName);

#[derive(Debug, Clone)]
enum NumericVariable {
    Simple(VarName),
    Array(VarName, Box<NumExpr>, Option<Box<NumExpr>>),
}
#[derive(Debug, Clone)]
enum Variable {
    String(StringVariable),
    Numeric(NumericVariable),
}

#[derive(Debug, Clone)]
enum NumExpr {
    Num(f64),
    Variable(NumericVariable),

    Neg(Box<NumExpr>),
    Add(Box<NumExpr>, Box<NumExpr>),
    Sub(Box<NumExpr>, Box<NumExpr>),
    Mul(Box<NumExpr>, Box<NumExpr>),
    Div(Box<NumExpr>, Box<NumExpr>),
    Pow(Box<NumExpr>, Box<NumExpr>),

    Call(String),
    CallArgs(String, Box<NumExpr>),
}

type BinaryNumExpr = fn(Box<NumExpr>, Box<NumExpr>) -> NumExpr;

#[derive(Debug, Clone)]
enum StringExpr {
    Literal(String),
    Variable(StringVariable),
}

#[derive(Debug, Clone)]
enum Datum {
    Number(f64),
    String(String),
}

#[derive(Debug, Clone)]
enum PrintItem {
    String(StringExpr),
    Num(NumExpr),
    Tab(NumExpr),
    Comma,
    Semicolon,
}

#[derive(Debug, Clone)]
enum LetStatement {
    String(StringVariable, StringExpr),
    Numeric(NumericVariable, NumExpr),
}

#[derive(Debug, Clone)]
enum Statement {
    Print(Vec<PrintItem>),
    Let(LetStatement),
    Dim(Vec<(VarName, usize, Option<usize>)>),
    Read(Vec<Variable>),
    Data(Vec<Datum>),
    Input(Vec<Variable>),
    Comment,
    Randomize,
    Restore,
    Return,
    Stop,
    End,
}

#[derive(Debug, Clone)]
enum Block {
    For {
        var: VarName,
        start: f64,
        end: f64,
        step: f64,
        inner: Box<Block>,
    },
    Line(Statement),
    NoOp,
    End,
}

type ProgramEntry = (LineNo, Block);

fn parser() -> impl Parser<char, Vec<ProgramEntry>, Error = Simple<char>> {
    let space = just(' ').repeated();
    let a_space = space.at_least(1);
    let lineno = just('0').repeated().ignore_then(text::int(10)).map(|raw| {
        let ret = raw.parse::<LineNo>().unwrap();
        assert!(ret > 0, "Line numbers must be positive");
        ret
    });

    let unquoted_string = filter::<char, _, Simple<char>>(|c| {
        c.is_ascii_alphanumeric() || *c == '+' || *c == '-' || *c == '.' || *c == ' '
    })
    .repeated()
    .collect::<String>()
    .map(|s| s.trim().to_owned());

    let quoted_string = filter(|c| *c != '\n' && *c != '"')
        .repeated()
        .collect::<String>()
        .delimited_by(just('"'), just('"'));

    let string_variable = filter::<_, _, Simple<char>>(char::is_ascii_uppercase)
        .then_ignore(just('$'))
        .map(|letter| StringVariable(letter.to_string()));

    let string_expr = choice((
        quoted_string.map(StringExpr::Literal),
        string_variable.map(StringExpr::Variable),
    ));

    let numeric_constant = {
        let sign = one_of("+-");
        let int = text::int(10);

        let fraction = just('.').ignore_then(int);
        let exponent = just('E')
            .ignore_then(sign.clone().or_not())
            .then(int)
            .map(|(sign, int)| {
                format!("{}{int}", sign.unwrap_or('+'))
                    .parse::<i32>()
                    .unwrap()
            });

        sign.or_not()
            .then(choice((
                int.then(fraction)
                    .map(|(int, frac)| format!("{int}.{frac}").parse::<f64>().unwrap()),
                int.then_ignore(just('.'))
                    .map(|int| int.parse::<f64>().unwrap()),
                int.map(|int| int.parse::<f64>().unwrap()),
                fraction.map(|frac| format!("0.{frac}").parse::<f64>().unwrap()),
            )))
            .then(exponent.or_not())
            .map(
                |((sign, mut val), exponent): ((Option<char>, f64), Option<i32>)| {
                    if let Some(sign) = sign {
                        if sign == '-' {
                            val *= -1.0;
                        }
                    }
                    if let Some(exp) = exponent {
                        val *= 10f64.powi(exp)
                    }
                    val
                },
            )
    };

    fn numeric_variable<E, P>(
        numeric_expr: P,
    ) -> impl Parser<char, NumericVariable, Error = E> + Clone
    where
        E: chumsky::Error<char>,
        P: Parser<char, NumExpr, Error = E> + Clone,
    {
        let letter = filter::<char, _, E>(|c| c.is_ascii_uppercase());

        let simple = letter
            .then(filter(char::is_ascii_digit).or_not())
            .map(|(var, digit)| {
                NumericVariable::Simple(match digit {
                    Some(digit) => format!("{var}{digit}"),
                    None => var.to_string(),
                })
            });

        let array = letter
            .then(
                numeric_expr
                    .padded()
                    .separated_by(just(','))
                    .at_least(1)
                    .at_most(2)
                    .delimited_by(just('('), just(')'))
                    .collect::<Vec<NumExpr>>(),
            )
            .map(|(name, args)| {
                NumericVariable::Array(
                    name.to_string(),
                    Box::new(args[0].clone()),
                    args.get(1).map(|expr| Box::new(expr.clone())),
                )
            });

        array.or(simple)
    }

    let numeric_expr = recursive(|numeric_expr| {
        let numeric_variable = numeric_variable(numeric_expr.clone()).map(NumExpr::Variable);

        let group = numeric_expr.padded().delimited_by(just('('), just(')'));

        let arg_fns = choice((
            just("ABS"),
            just("ATN"),
            just("COS"),
            just("EXP"),
            just("INT"),
            just("LOG"),
            just("SGN"),
            just("SIN"),
            just("SQR"),
            just("TAN"),
        ))
        .map(str::to_owned);

        let rnd_fn = just("RND").map(str::to_owned);

        let user_fn = just("FN")
            .then(filter(char::is_ascii_uppercase))
            .map(|(a, b)| format!("{a}{b}"));

        let arg_fn = arg_fns
            .or(user_fn)
            // Cheeky, a function call is basically just a grouped expression
            .then(group.clone())
            .map(|(var, arg)| NumExpr::CallArgs(var, Box::new(arg)));

        let narg_fn = rnd_fn.or(user_fn).map(NumExpr::Call);

        let primary = choice((
            arg_fn,
            narg_fn,
            numeric_variable,
            numeric_constant.clone().map(NumExpr::Num),
            group,
            //
        ));

        let op = |c, v: BinaryNumExpr| space.ignore_then(just(c)).then_ignore(space).to(v);

        fn bin<I, E, InP, OutP>(
            input: InP,
            opers: OutP,
        ) -> impl Parser<I, NumExpr, Error = E> + Clone
        where
            I: Clone,
            E: chumsky::Error<I>,
            InP: Parser<I, NumExpr, Error = E> + Clone,
            OutP: Parser<I, BinaryNumExpr, Error = E> + Clone,
        {
            input
                .clone()
                .then(opers.then(input).repeated())
                .foldl(|lhs, (op, rhs)| op(Box::new(lhs), Box::new(rhs)))
        }

        // I've used names from the spec even though they're silly
        let factor = bin(primary, op('^', NumExpr::Pow));
        let term = bin(
            factor,
            choice((op('*', NumExpr::Mul), op('/', NumExpr::Div))),
        );

        // this is a trainwreck of a parse statement

        let unary = choice((just('+'), just('-'), empty().to('#')))
            .then(term.clone())
            .map(|(op, term)| match op {
                '-' => NumExpr::Neg(Box::new(term)),
                _ => term,
            });
        let opers = choice((op('+', NumExpr::Add), op('-', NumExpr::Sub)));
        unary
            .clone()
            .then(opers.then(term).repeated())
            .foldl(|lhs, (op, rhs)| op(Box::new(lhs), Box::new(rhs)))
    });

    let numeric_variable = numeric_variable(numeric_expr.clone());

    let variable = choice((
        string_variable.map(Variable::String),
        numeric_variable.clone().map(Variable::Numeric),
    ));

    let statement = choice((
        {
            let print_sepr = choice((
                just(',').to(PrintItem::Comma),
                just(';').to(PrintItem::Semicolon),
            ));

            let string = string_expr.map(PrintItem::String);
            let number = numeric_expr.clone().map(PrintItem::Num);
            let tab_call = just("TAB")
                .ignore_then(
                    numeric_expr
                        .clone()
                        .padded()
                        .delimited_by(just('('), just(')')),
                )
                .map(PrintItem::Tab);
            let print_item = choice((tab_call, string, number));

            let print_list = empty()
                .ignore_then(
                    print_item
                        .clone()
                        .or_not()
                        .then_ignore(space)
                        .then(print_sepr)
                        .then_ignore(space)
                        .map(|(a, b)| vec![a, Some(b)]),
                )
                .repeated()
                .flatten()
                .chain::<Option<PrintItem>, _, _>(print_item.or_not())
                .flatten();

            text::keyword("PRINT")
                .ignore_then(a_space)
                .ignore_then(print_list)
                .map(Statement::Print)
        },
        text::keyword("PRINT").to(Statement::Print(vec![])),
        text::keyword("RANDOMIZE").to(Statement::Randomize),
        text::keyword("RESTORE").to(Statement::Restore),
        text::keyword("RETURN").to(Statement::Return),
        text::keyword("STOP").to(Statement::Stop),
        text::keyword("REM")
            .ignore_then(space)
            .ignore_then(filter(|c| *c != '\n' && *c != '\r').repeated())
            .ignored()
            .map(|()| Statement::Comment),
        text::keyword("LET")
            .ignore_then(a_space)
            .ignore_then(string_variable)
            .then_ignore(a_space)
            .then_ignore(just('='))
            .then_ignore(a_space)
            .then(string_expr)
            .map(|(var, expr)| Statement::Let(LetStatement::String(var, expr))),
        text::keyword("LET")
            .ignore_then(a_space)
            .ignore_then(numeric_variable)
            .then_ignore(a_space)
            .then_ignore(just('='))
            .then_ignore(a_space)
            .then(numeric_expr)
            .map(|(var, expr)| Statement::Let(LetStatement::Numeric(var, expr))),
        text::keyword("DIM")
            .ignore_then(a_space)
            .ignore_then(
                filter::<char, _, Simple<char>>(|c| c.is_ascii_uppercase())
                    .then_ignore(space)
                    .then(
                        text::int::<char, Simple<char>>(10)
                            .padded()
                            .map(|a| a.parse().unwrap())
                            .separated_by(just(','))
                            .at_least(1)
                            .at_most(2)
                            .delimited_by(just('('), just(')'))
                            .collect::<Vec<usize>>(),
                    )
                    .map(|(name, args)| (name.to_string(), args[0], args.get(1).copied()))
                    .repeated()
                    .at_least(1),
            )
            .map(Statement::Dim),
        {
            // READ and INTPUT
            text::keyword("READ")
                .to(Statement::Read as fn(_) -> _)
                .or(text::keyword("INPUT").to(Statement::Input as fn(_) -> _))
                .then_ignore(a_space)
                .then(
                    space
                        .ignore_then(variable)
                        .then_ignore(space)
                        .separated_by(just(','))
                        .at_least(1),
                )
                .map(|(statement, vars)| statement(vars))
        },
        text::keyword("DATA")
            .ignore_then(a_space)
            .ignore_then(
                space
                    .ignore_then(choice((
                        numeric_constant.map(Datum::Number),
                        quoted_string.map(Datum::String),
                        unquoted_string.map(Datum::String),
                    )))
                    .then_ignore(space)
                    .separated_by(just(",")),
            )
            .map(Statement::Data),
        // TODO more
    ))
    .then_ignore(space)
    .then_ignore(text::newline());

    let block = {
        let line = statement.map(Block::Line);
        // TODO: for loop goes here
        choice((
            lineno.then_ignore(a_space).then(choice((line,))),
            lineno
                .or_not()
                .then_ignore(space)
                .then_ignore(text::newline())
                .map(|line_no| (line_no.unwrap_or(0), Block::NoOp)),
        ))
    };

    block
        .map(|block| dbg!(block))
        .repeated()
        .at_least(1)
        .chain(
            lineno
                .then_ignore(a_space)
                .then_ignore(text::keyword("END"))
                .then_ignore(space)
                .then_ignore(text::newline())
                .map(|line_no| (line_no, Block::End)),
        )
        .then_ignore(end())
}

fn main() {
    let src = std::fs::read_to_string(std::env::args().nth(1).unwrap()).unwrap();

    println!("{:?}", parser().parse(src));
}
