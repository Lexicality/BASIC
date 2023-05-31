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
enum NumExpr {
    Num(f64),
    Variable(NumericVariable),

    Neg(Box<NumExpr>),
    Add(Box<NumExpr>, Box<NumExpr>),
    Sub(Box<NumExpr>, Box<NumExpr>),
    Mul(Box<NumExpr>, Box<NumExpr>),
    Div(Box<NumExpr>, Box<NumExpr>),

    Call(String),
    CallArgs(String, Box<NumExpr>),
}

#[derive(Debug, Clone)]
enum PrintItem {
    Literal(String),
    Expr(NumExpr),
    Tab(u8),
    Comma,
    Semicolon,
}

#[derive(Debug, Clone)]
enum LetStatement {
    Numeric(NumericVariable, NumExpr),
}

#[derive(Debug, Clone)]
enum Statement {
    Print(Vec<PrintItem>),
    Let(LetStatement),
    Comment,
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

    let quoted_string = filter(|c| *c != '\n' && *c != '"')
        .repeated()
        .collect::<String>()
        .delimited_by(just('"'), just('"'));

    let numeric_expr = recursive(|numeric_expr| {
        let numeric_variable = filter::<_, _, Simple<char>>(char::is_ascii_uppercase)
            .then(filter(char::is_ascii_digit).or_not())
            .map(|(var, digit)| {
                NumExpr::Variable(NumericVariable::Simple(match digit {
                    Some(digit) => format!("{var}{digit}"),
                    None => var.to_string(),
                }))
            });

        let array_variable = filter::<_, _, Simple<char>>(char::is_ascii_uppercase)
            .then(
                numeric_expr
                    .clone()
                    .padded()
                    .separated_by(just(','))
                    .at_least(1)
                    .at_most(2)
                    .delimited_by(just('('), just(')'))
                    .collect::<Vec<NumExpr>>(),
            )
            .map(|(name, args)| {
                NumExpr::Variable(NumericVariable::Array(
                    dbg!(name).to_string(),
                    Box::new(args[0].clone()),
                    args.get(1).map(|expr| Box::new(expr.clone())),
                ))
            });

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

        let number = sign
            .or_not()
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
                    NumExpr::Num(val)
                },
            );

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
            .then(numeric_expr.delimited_by(just('('), just(')')))
            .map(|(var, arg)| NumExpr::CallArgs(var, Box::new(arg)));

        let narg_fn = rnd_fn.or(user_fn).map(NumExpr::Call);

        choice((
            arg_fn,
            narg_fn,
            array_variable,
            numeric_variable,
            number,
            //
        ))
    });

    let statement = choice((
        {
            let print_sepr = choice((
                just(',').to(PrintItem::Comma),
                just(';').to(PrintItem::Semicolon),
            ));

            let print_literal = quoted_string.map(PrintItem::Literal);
            let print_expr = numeric_expr.clone().map(|aa| {
                PrintItem::Expr(aa)
                //
            });
            let print_item = choice((print_literal, print_expr));

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
        text::keyword("PRINT")
            .ignore_then(space)
            .to(Statement::Print(vec![])),
        text::keyword("REM")
            .ignore_then(space)
            .ignore_then(filter(|c| *c != '\n' && *c != '\r').repeated())
            .ignored()
            .map(|()| Statement::Comment),
        text::keyword("LET")
            .ignore_then(a_space)
            .ignore_then(numeric_expr.clone())
            .map(|a| match a {
                NumExpr::Variable(v) => v,
                _ => panic!("bad"),
            })
            .then_ignore(a_space)
            .then_ignore(just('='))
            .then_ignore(a_space)
            .then(numeric_expr)
            .map(|(var, expr)| Statement::Let(LetStatement::Numeric(var, expr))),
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
        .repeated()
        .at_least(1)
        .map(|a| dbg!(a))
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
