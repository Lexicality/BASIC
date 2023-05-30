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
use chumsky::text::newline;

type VarName = String;
type LineNo = usize;

#[derive(Debug, Clone)]
enum Expr {
    Num(f64),
    VarNum(VarName),
    VarStr(VarName),
    VarArr(VarName, usize),

    Neg(Box<Expr>),
    Add(Box<Expr>, Box<Expr>),
    Sub(Box<Expr>, Box<Expr>),
    Mul(Box<Expr>, Box<Expr>),
    Div(Box<Expr>, Box<Expr>),

    Call(String, Vec<Expr>),
    Let { name: String, expr: Box<Expr> },
}

#[derive(Debug, Clone)]
enum PrintItem {
    Literal(String),
    Expr(Expr),
    Tab(u8),
    Comma,
    Semicolon,
}

#[derive(Debug)]
enum Statement {
    Print(Vec<PrintItem>),
    Comment,
    End,
}

#[derive(Debug)]
enum Block {
    For {
        line_no: LineNo,
        next: Box<Block>,
        inner: Box<Block>,
        var: VarName,
        start: f64,
        end: f64,
        step: f64,
    },
    Line {
        line_no: LineNo,
        next: Box<Block>,
        stmt: Statement,
    },
    End {
        line_no: LineNo,
    },
}

fn parser() -> impl Parser<char, Block, Error = Simple<char>> {
    let space = just(' ').repeated();
    let a_space = space.at_least(1);
    let lineno = just('0')
        .repeated()
        .ignore_then(text::int(10))
        .map(|raw| raw.parse::<LineNo>().unwrap());

    let quoted_string = filter::<_, _, Simple<char>>(|c| *c != '\n' && *c != '"')
        .repeated()
        .collect::<String>()
        .delimited_by(just('"'), just('"'));

    let numeric_expr = recursive(|numeric_expr| {
        let sign = one_of::<_, _, Simple<char>>("+-");
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
                    println!("Ayy lmao {:?} {:?} {:?}", sign, val, exponent);
                    if let Some(sign) = sign {
                        if sign == '-' {
                            val *= -1.0;
                        }
                    }
                    if let Some(exp) = exponent {
                        val *= 10f64.powi(exp)
                    }
                    Expr::Num(val)
                },
            );

        number
    });

    let statement = choice((
        {
            let print_sepr = choice((
                just(',').to(PrintItem::Comma),
                just(';').to(PrintItem::Semicolon),
            ));

            let print_literal = quoted_string.map(PrintItem::Literal);
            let print_expr = numeric_expr.map(PrintItem::Expr);
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
                .map(|printstr| {
                    println!("woo  {printstr:?}");
                    Statement::Print(printstr)
                })
        },
        text::keyword("REM")
            .ignore_then(space)
            .ignore_then(filter(|c| *c != '\n' && *c != '\r').repeated())
            .ignored()
            .map(|()| Statement::Comment),
        // TODO more
    ))
    .then_ignore(space)
    .then_ignore(newline());

    let block = recursive(|block| {
        let lineno = lineno.then_ignore(a_space);
        let end_line = lineno
            .then_ignore(text::keyword("END"))
            .then_ignore(space)
            .then_ignore(text::newline())
            .then_ignore(end())
            .map(|line_no| Block::End { line_no });

        let line = lineno
            .then(statement)
            .then(block)
            .map(|((line_no, stmt), next)| Block::Line {
                line_no,
                stmt,
                next: Box::new(next),
            });

        choice((line, end_line))
    });

    block
}

fn main() {
    let src = std::fs::read_to_string(std::env::args().nth(1).unwrap()).unwrap();

    println!("{:?}", parser().parse(src));
}
