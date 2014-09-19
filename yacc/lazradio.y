
/* PAS.Y: ISO Level 0 Pascal grammar, adapted to TP Yacc 2-28-89 AG
   To compile: yacc lazradio.y
               lex lazradiolex.l
*/

%{

uses SysUtils, Classes, LexLib, YaccLib, superobject;

type
  TCreateModule = function (const Name: string; const T: string): Boolean of object;
  TSendMessage = function (const Name: string; const V1, V2, V3: PtrUInt): Boolean of object;

var filename : String;
    yywrap: Boolean = True;
    SymTable: ISuperObject = nil;
    OnCreateModule: TCreateModule = nil;
    OnSendMessage: TSendMessage = nil;

procedure yyerror(msg : string);
  begin
    writeln(filename, ': ', yylineno, ': ',
            msg, ' at or before `', yytext, '''.')
  end(*yyerror*);

function IsDefined(const S: string): Boolean;
begin
  IsDefined := Assigned(SymTable.O[S]);
end;

function DefVars(const S: string; const T: string): Boolean;
var
  L: TStringList;
  V: string;
begin
  L := TStringList.Create;
  L.Delimiter := ' ';
  L.StrictDelimiter := True;
  Result := False;
  for V in L do
  begin
    if IsDefined(V) then Exit;
    SymTable.O[UpperCase(S)] := SO(Format('type: "%s"; disp: "%s"', [T, S]));
  end;
  Result := True;
end;


%}

/* Note the Pascal keyword tokens are stropped with leading underscore
   (e.g. _AND) in the Turbo Pascal Yacc version, because these identifiers
   will be declared as token numbers in the output file generated by Yacc,
   and hence must not collide with Turbo Pascal keywords. */

%token _AND _ARCCOS _ARCSIN ASSIGNMENT _BEGIN
%token COLON COMMA CONNFEATURE CONNFEATUREDATA CONNDATA _CONST _COS
%token _DIV DOT DOTDOT _ELSE _END EQUAL _EXP _FILE
%token GE GT _ID _INTEGER  _LAZRADIO LBRAC LBRACE LE _LOG LPAREN LT MINUS _MOD _NIL _NOT
%token NOTEQUAL _ORD _OR PLUS _PRED _REAL RBRAC RBRACE
%token RPAREN SEND SEMICOLON _SIN SLASH STAR STARSTAR _SUCC _STR _STRING _VAL
%token UPARROW _VAR _WRITELN _XOR

%token ILLEGAL

%token <Real>       REALNUMBER
%token <Integer>    DIGSEQ
%token <String>     CHARACTER_STRING
%token <String>     IDENTIFIER

%type <String>     identifier
%type <String>     identifier_list

%type <String>     type_denoter

%%

file : program {writeln('program');}
    | program error
	{ yyerror(':Text follows logical end of program.'); }
    ;

program : program_heading semicolon block DOT {writeln('dot!');}
    ;

program_heading : _LAZRADIO identifier
    ;

identifier_list : identifier_list comma identifier { $$ := $1 + ' ' + $3}
    | identifier 
    ;

block : constant_definition_part
    variable_declaration_part
    statement_part {writeln('block!');}
    ;

constant_definition_part : _CONST constant_list
    |
    ;

constant_list : constant_list constant_definition
    | constant_definition
    ;

constant_definition : identifier EQUAL cexpression semicolon
    ;

/*constant : cexpression ;        /* good stuff! */

cexpression : csimple_expression
    | csimple_expression relop csimple_expression
    ;

csimple_expression : cterm
    | csimple_expression addop cterm
    ;

cterm : cfactor
    | cterm mulop cfactor
    ;

cfactor : sign cfactor
    | cexponentiation
    ;

cexponentiation : cprimary
    | cprimary STARSTAR cexponentiation
    ;

cprimary : identifier
    | LPAREN cexpression RPAREN
    | unsigned_constant
    | _NOT cprimary
    ;

constant : non_string
    | sign non_string
    | CHARACTER_STRING
    ;

sign : PLUS
    | MINUS
    ;

non_string : DIGSEQ
    | identifier
    | REALNUMBER
    ;

base_type : ordinal_type ;

domain_type : identifier ;

variable_declaration_part : _VAR variable_declaration_list semicolon
    |
    ;

variable_declaration_list :
      variable_declaration_list semicolon variable_declaration
    | variable_declaration
    ;

variable_declaration : identifier_list COLON _INTEGER { DefVars($1, 'int'); }
    | identifier_list COLON _REAL { DefVars($1, 'real'); }
    | identifier_list COLON _STRING { DefVars($1, 'string'); }
    | identifier_list COLON type_denoter { DefVars($1, $3); }
    ;

formal_parameter_list : LPAREN formal_parameter_section_list RPAREN ;

formal_parameter_section_list : formal_parameter_section_list semicolon
 formal_parameter_section
    | formal_parameter_section
    ;

formal_parameter_section : value_parameter_specification
    | variable_parameter_specification
    | procedural_parameter_specification
    | functional_parameter_specification
    ;

value_parameter_specification : identifier_list COLON identifier
    ;

variable_parameter_specification : _VAR identifier_list COLON identifier
    ;

result_type : identifier ;

function_identification : _FUNCTION identifier ;

function_block : block ;

statement_part : compound_statement ;

compound_statement : _BEGIN statement_sequence _END {writeln('compound_statement');};

statement_sequence : statement_sequence semicolon statement
    | statement
    ;

statement : open_statement
    | closed_statement
    ;

open_statement : non_labeled_open_statement
    ;

closed_statement : non_labeled_closed_statement
    ;

non_labeled_closed_statement : assignment_statement
    | compound_statement
    | send_statement
    | connection_statement 
    ;

non_labeled_open_statement :;

connection_statement: connection_feature_statement
    | connection_feature_data_statement
    | connection_data_statement
    ;

connection_feature_statement: identifier CONNFEATURE identifier
    | identifier CONNFEATURE connection_feature_statement
    ;

connection_feature_data_statement: identifier CONNFEATUREDATA identifier
    | identifier CONNFEATUREDATA connection_feature_data_statement
    ;

connection_data_statement: identifier CONNDATA identifier
    | identifier CONNDATA connection_data_statement
    | indexed_variable CONNDATA indexed_variable
    ;

send_statement : identifier SEND LBRACE expression COMMA expression COMMA expression RBRACE 
    | identifier SEND LBRACE expression COMMA expression _RBRACE        
    | identifier SEND LBRACE expression RBRACE     {writeln('send!!!!');}  

assignment_statement : variable_access ASSIGNMENT expression
    ;

variable_access : identifier
    | indexed_variable
    | field_designator
    ;

indexed_variable : variable_access LBRAC index_expression_list RBRAC
    ;

index_expression_list : index_expression_list comma index_expression
    | index_expression
    ;

index_expression : expression ;

procedure_statement : identifier params
    | identifier
    ;

params : LPAREN actual_parameter_list RPAREN ;

actual_parameter_list : actual_parameter_list comma actual_parameter
    | actual_parameter
    ;

type_denoter: identifier /* module types */
    ;

/*
 * this forces you to check all this to be sure that only write and
 * writeln use the 2nd and 3rd forms, you really can't do it easily in
 * the grammar, especially since write and writeln aren't reserved
 */
actual_parameter : expression
    | expression COLON expression
    | expression COLON expression COLON expression
    ;

control_variable : identifier ;

boolean_expression : expression ;

expression : simple_expression
    | simple_expression relop simple_expression
    | error
    ;

simple_expression : term
    | simple_expression addop term
    ;

term : factor
    | term mulop factor
    ;

factor : sign factor
    | exponentiation
    ;

exponentiation : primary
    | primary STARSTAR exponentiation
    ;

primary : variable_access
    | unsigned_constant
    | function_designator
    | set_constructor
    | LPAREN expression RPAREN
    | _NOT primary
    ;

unsigned_constant : unsigned_number
    | CHARACTER_STRING
    | _NIL
    ;

unsigned_number : unsigned_integer | unsigned_real ;

unsigned_integer : DIGSEQ
    ;

unsigned_real : REALNUMBER
    ;

addop: PLUS
    | MINUS
    | _OR
    ;

mulop : STAR
    | SLASH
    | _DIV
    | _MOD
    | _AND
    ;

relop : EQUAL
    | NOTEQUAL
    | LT
    | GT
    | LE
    | GE
    ;

identifier : IDENTIFIER 
    ;

semicolon : SEMICOLON
    ;

comma : COMMA
    ;

%%

{$I lazradiolex.pas}

begin
  if not Assigned(SymTable) then SymTable := SO('{}');

  filename := paramStr(1);
  if filename='' then
    begin
      write('input file: ');
      readln(filename);
    end;
  assign(yyinput, filename);
  reset(yyinput);
  if yyparse=0 then writeln('successful parse!');
end.
