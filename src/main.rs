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

#[derive(Debug)]
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

#[derive(Debug)]
enum PrintItem {
    Literal(String),
    Tab(u8),
    Comma,
    Semicolon,
}
#[derive(Debug)]
struct PrintLineItem {
    item: PrintItem,
    next: Option<Box<PrintLineItem>>,
}

#[derive(Debug)]
enum Statement {
    Print(PrintLineItem),
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

    let statement = choice((
        {
            let print_sepr = one_of::<_, _, Simple<char>>(",;").map(|c| match c {
                ';' => PrintItem::Semicolon,
                ',' => PrintItem::Comma,
                _ => panic!("wat"),
            });
            let print_literal = quoted_string.map(PrintItem::Literal);

            let print_item =
                recursive(|print_item| {
                    let expr = choice((print_literal,));

                    choice((
                        expr.then_ignore(space)
                            .then(print_sepr.clone())
                            .then_ignore(space)
                            .then(print_item.clone())
                            .map(|((expr, sepr), next)| PrintLineItem {
                                item: expr,
                                next: Some(Box::new(PrintLineItem {
                                    item: sepr,
                                    next: Some(Box::new(next)),
                                })),
                            }),
                        print_sepr.clone().then_ignore(space).then(print_item).map(
                            |(sepr, next)| PrintLineItem {
                                item: sepr,
                                next: Some(Box::new(next)),
                            },
                        ),
                        expr.map(|expr| PrintLineItem {
                            item: expr,
                            next: None,
                        }),
                        print_sepr.map(|sepr| PrintLineItem {
                            item: sepr,
                            next: None,
                        }),
                    ))
                });

            text::keyword("PRINT")
                .ignore_then(a_space)
                .ignore_then(print_item)
                .map(|printstr| {
                    println!("woo  {printstr:?}");
                    Statement::Print(printstr)
                })
        },
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
