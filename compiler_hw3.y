/* Definition section */
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    typedef struct sssss {
        int index;
        char name[32];
        char kind[16];
        char type[8];
        int scope;
        char attribute[32];
        int func_forward_def;
        struct sssss *next;
    } symbol_t;

    typedef struct {
        symbol_t *head;
    } table_t;

    extern int yylineno;
    extern int yylex();
    extern char *yytext;                // Get current token from lex
    extern char code_line[256];         // Get current code line from lex
    extern int rcb_flag;

    FILE *file;                         // To generate .j file for Jasmin

    void yyerror(char *s);

    /* Symbol table functions */
    void create_symbol();
    void insert_symbol(symbol_t x);
    int lookup_symbol(char *str, int up_to_scope);
    void dump_symbol();

    void dump_parameter();
    void push_type(char *str);
    void pop_type();
    void parse_newline();

    /* code generation functions, just an example! */
    void gencode_function();
    symbol_t find_last(int find_scope);
    symbol_t find_symbol(char *str, int up_to_scope);
    void parse_func_attr(char *s, char r[]);

    /* global variables */
    table_t *t[32];                     // symbol table
    symbol_t reading, rfunc;
    int scope = 0;                      // record what scope it is now
    int create_table_flag[32] = {0};    // decide whether need to create table
    int table_item_index[32] = {0};
    char error_msg[32];                 // the name of the ID that causes error 
    int error_type_flag = 0;
    int syntax_error_flag = 0;
    char type_stack[10][8];             // a stack to record types
    int stack_index = 0;
    char func_redecl[32];

    /* gencode flags */
    int gflag = -1;
    int glo_var_assi_flag = 0;
    char glo_var_value[64];
    int loc_var_assi_flag = 0;
    char loc_var_value[128];
    int print_id_index;
    char print_id_type[8];
    int print_const_flag = 0;
    char print_const_value[64];
    char print_const_type[32];
    int return_void_flag = 0;
    int expr_flag[23] = {0};
    char expr_queue[32][32];
    int expr_queue_index = 0;
    char expr_const[32];
    char expr_buf[128];
    int expr_fmode = 0;
    int assi_flag = 0;      //used in expr
    int selection_flag = 0;
    int if_else_flag = 0;
    int if_end_with_else_flag = 0;
    int if_end_flag = 0;
    int else_begin_flag = 0;
    int else_end_flag = 0;
    int if_flag = 0;
    int label_index = 0, current_label_index;
%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    double f_val;
    char* string;
}

/* Token without return */  /* terminals */
%token PRINT 
%token IF ELSE FOR WHILE
%token RETURN
%token SEMICOLON
%token ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token OR AND NOT
%token ADD "+" 
%token SUB "-" 
%token MUL "*" 
%token DIV "/" 
%token MOD "%"
%token INC DEC
%token LT "<"
%token MT ">"
%token LTE MTE EQ NE

%token ASGN "="
%token LB "("
%token RB ")"
%token COMMA ","
%token LCB "{"
%token RCB "}"
%token TRUE FALSE

/* Token with return, which need to sepcify type */
%token <string> I_CONST
%token <string> F_CONST
%token <string> STR_CONST
%token <string> ID 
%token <string> INT FLOAT BOOL STRING VOID  /* the name of the types */

/* Nonterminal with return, which need to sepcify type */

// %type <string> const
%type <string> direct_declarator declarator
%type <string> type 



/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program:
      external program
    | external
    ;

external:
      declaration           { gflag = 0; }
    | func_def              {  }
    ;

declaration:
      type 
      ID                    { strcpy(reading.name, $2);
                              if (lookup_symbol($2, scope)) { 
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Redeclared variable ");
                                  strcat(error_msg, $2);
                              }
                            } 
      "="                   { glo_var_assi_flag = 1; loc_var_assi_flag = 1; }
      initializer           
      SEMICOLON             { strcpy(reading.kind, "variable");
                              pop_type(); 
                              reading.scope = scope;
                              reading.index = table_item_index[scope]; 
                              if (!error_type_flag) {
                                  table_item_index[scope]++;
                                  insert_symbol(reading);
                              } 
                            }
    | type              
      ID                    { strcpy(reading.name, $2);
                              if (lookup_symbol($2, scope)) { 
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Redeclared variable ");
                                  strcat(error_msg, $2);
                              }
                            } 
      SEMICOLON             { strcpy(reading.kind, "variable");
                              pop_type(); 
                              reading.scope = scope;
                              reading.index = table_item_index[scope]; 
                              if (!error_type_flag) {
                                  table_item_index[scope]++;
                                  insert_symbol(reading); 
                              }
                              
                            }
    | type                  
      declarator            { scope++;
                              dump_parameter();         // because haven't enter the scope yet
                              strcpy(rfunc.name, $2); 
                              if (lookup_symbol($2, scope)) { 
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Redeclared function ");
                                  strcat(error_msg, $2);
                              }

                              strcpy(rfunc.kind, "function");
                              rfunc.func_forward_def = 1; 
                              pop_type();
                              rfunc.scope = scope;
                              rfunc.index = table_item_index[scope]; 
                              if (!error_type_flag) {
                                  table_item_index[scope]++;
                                  insert_symbol(rfunc);
                              }
                              strcpy(rfunc.attribute, ""); 
                            }
      SEMICOLON
    ;

/* actions can be taken when meet the token or rule */
type:
      INT                   { strcpy(reading.type, $1); strcpy(rfunc.type, $1); push_type($1); }
    | FLOAT                 { strcpy(reading.type, $1); strcpy(rfunc.type, $1); push_type($1); }
    | BOOL                  { strcpy(reading.type, $1); strcpy(rfunc.type, $1); push_type($1); }
    | STRING                { strcpy(reading.type, $1); strcpy(rfunc.type, $1); push_type($1); }
    | VOID                  { strcpy(reading.type, $1); strcpy(rfunc.type, $1); push_type($1); }
    ;

initializer:
      assign_expr
    ;

const: 
      I_CONST               { strcpy(glo_var_value, $1); strcpy(loc_var_value, $1); strcpy(print_const_value, $1);
                              strcpy(print_const_type, "I"); 
                              strcpy(expr_const, "I"); strcat(expr_const, $1); }
    | F_CONST               { strcpy(glo_var_value, $1); strcpy(loc_var_value, $1); strcpy(print_const_value, $1);
                              strcpy(print_const_type, "F"); 
                              strcpy(expr_const, "F"); strcat(expr_const, $1); expr_fmode = 1; }
    | STR_CONST             { strcpy(glo_var_value, $1); strcpy(loc_var_value, $1); strcpy(print_const_value, $1); 
                              strcpy(print_const_type, "Ljava/lang/String;"); }
    | TRUE                  { strcpy(glo_var_value, "1"); strcpy(loc_var_value, "1"); strcpy(print_const_value, "1"); }
    | FALSE                 { strcpy(glo_var_value, "0"); strcpy(loc_var_value, "0"); strcpy(print_const_value, "0"); }
    ;

func_def:
      type 
      declarator            { strcpy(rfunc.name, $2);
                              int result = lookup_symbol($2, scope);
                              if (result == 1) { 
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Redeclared function ");
                                  strcat(error_msg, $2);
                              }
                              pop_type();
                              // the function wasn't declared before
                              // so it needs to be inserted
                              if (result != 2) {
                                  strcpy(rfunc.kind, "function"); 
                                  rfunc.scope = scope;
                                  rfunc.index = table_item_index[scope]; 
                                  table_item_index[scope]++; 
                                  insert_symbol(rfunc); 
                              }
                              strcpy(rfunc.attribute, "");
                              gflag = 1;
                            }
      compound_stat         
    ;

declarator:
      direct_declarator
    ;

direct_declarator:
      ID 
      "(" 
      ")"                   
    | ID 
      "("                   
      parameters 
      ")"                   
    ;

parameters:
      type 
      ID                    { strcat(rfunc.attribute, reading.type);
                              strcpy(reading.name, $2); 
                              strcpy(reading.kind, "parameter");
                              strcpy(reading.attribute, "");
                              scope++; 
                              reading.scope = scope; 
                              reading.index = table_item_index[scope];
                              table_item_index[scope]++;
                              insert_symbol(reading);
                              scope--; 
                              pop_type();
                            }
    | type 
      ID                    { strcat(rfunc.attribute, reading.type);
                              strcpy(reading.name, $2); 
                              strcpy(reading.kind, "parameter");
                              strcpy(reading.attribute, "");
                              scope++; 
                              reading.scope = scope; 
                              reading.index = table_item_index[scope];
                              table_item_index[scope]++;
                              insert_symbol(reading);
                              scope--;
                              pop_type(); 
                            }
      ","                   { strcat(rfunc.attribute, ", "); }
      parameters
    ;


compound_stat:
      "{"                   
      "}"                   { gflag = 5; }
    | "{"                   { scope++; }
      block_item_list 
      "}"                   { gflag = 5; }
    ;

block_item_list:
      block_item 
    | block_item_list block_item
    ;

block_item:
      stat
    | declaration           { gflag = 2; }
    ;

stat:
      compound_stat         
    | expression_stat       
    | print_func            
    | selection_stat        
    | loop_stat             
    | jump_stat             
    ;

expression_stat:
      SEMICOLON             
    | expr SEMICOLON        
    ;

expr:
      assign_expr           { gflag = 6; puts("expr"); }
    | expr "," assign_expr
    ;

assign_expr:
      conditional_expr
    | unary_expression assign_op assign_expr
    ;

assign_op:
      "="                   { expr_flag[17] = 1; strcat(expr_buf, "= "); assi_flag = 1; }
    | MULASGN               { expr_flag[18] = 1; strcat(expr_buf, "*= "); assi_flag = 4; }
    | DIVASGN               { expr_flag[19] = 1; strcat(expr_buf, "/= "); assi_flag = 5; }
    | MODASGN               { expr_flag[20] = 1; strcat(expr_buf, "%= "); assi_flag = 6; }
    | ADDASGN               { expr_flag[21] = 1; strcat(expr_buf, "+= "); assi_flag = 2; }
    | SUBASGN               { expr_flag[22] = 1; strcat(expr_buf, "-= "); assi_flag = 3; }
    ;

conditional_expr:
      logical_or_expr
    ;

logical_or_expr:
      logical_and_expr
    | logical_or_expr OR logical_and_expr               { expr_flag[16] = 1; }
    ;

logical_and_expr:
      equality_expression
    | logical_and_expr AND equality_expression          { expr_flag[15] = 1; }
    ;

equality_expression:
      relational_expression
    | equality_expression EQ relational_expression      { strcat(expr_buf, "== "); }
    | equality_expression NE relational_expression      { strcat(expr_buf, "!= "); }
    ;

relational_expression:
      additive_expression
    | relational_expression "<" additive_expression     { strcat(expr_buf, "< "); }
    | relational_expression ">" additive_expression     { strcat(expr_buf, "> "); }
    | relational_expression LTE additive_expression     { strcat(expr_buf, "<= "); }
    | relational_expression MTE additive_expression     { strcat(expr_buf, ">= "); }
    ;

additive_expression:
      multiplicative_expression
    | additive_expression "+" multiplicative_expression { expr_flag[7] = 1; strcat(expr_buf, "+ "); }
    | additive_expression "-" multiplicative_expression { expr_flag[8] = 1; strcat(expr_buf, "- "); }
    ;


multiplicative_expression:
      cast_expression
    | multiplicative_expression "*" cast_expression     { expr_flag[4] = 1; strcat(expr_buf, "* "); }
    | multiplicative_expression "/" cast_expression     { expr_flag[5] = 1; strcat(expr_buf, "/ "); }
    | multiplicative_expression "%" cast_expression     { expr_flag[6] = 1; strcat(expr_buf, "% "); }
    ;

cast_expression:
      unary_expression
    | "(" type ")" cast_expression
    ;

unary_expression:
      postfix_expression
    | INC unary_expression  { expr_flag[2] = 1; }
    | DEC unary_expression  { expr_flag[3] = 1; }
    | unary_operator cast_expression
    ;

unary_operator:
      "+"                   { expr_flag[0] = 1; }
    | "-"                   { expr_flag[1] = 1; }
    | "!"
    ;

postfix_expression:
      primary_expr
    | postfix_expression INC    { strcat(expr_buf, "++ "); }
    | postfix_expression DEC    { strcat(expr_buf, "-- "); }
    | postfix_expression 
      "(" ")"               { strcpy(error_msg, ""); 
                              strcat(error_msg, "Undeclared function "); 
                              strcat(error_msg, func_redecl); }
    | postfix_expression 
      "(" argument_list_expr 
      ")"                   { strcpy(error_msg, ""); 
                              strcat(error_msg, "Undeclared function "); 
                              strcat(error_msg, func_redecl); }
    ;

argument_list_expr:
      assign_expr
    | argument_list_expr "," assign_expr
    ;

primary_expr:
      ID                    { if (!lookup_symbol($1, 0)) {
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Undeclared variable ");
                                  strcat(error_msg, $1);
                                  strcpy(func_redecl, $1);
                              }
                              else {
                                  //gflag = 6;
                                  strcpy(expr_queue[expr_queue_index], $1);
                                  expr_queue_index++;
                                  strcat(expr_buf, "V");
                                  strcat(expr_buf, $1);
                                  strcat(expr_buf, " ");
                                  symbol_t node = find_symbol($1, 0);
                                  if (strcmp(node.type, "float") == 0)
                                      expr_fmode = 1;
                              } 
                            }
    | const                 { //gflag = 6; 
                              strcpy(expr_queue[expr_queue_index], expr_const);
                              expr_queue_index++;
                              strcat(expr_buf, expr_const);
                              strcat(expr_buf, " ");
                            }
    | "("                   { strcat(expr_buf, "( "); }
      expr 
      ")"                   { strcat(expr_buf, ") "); }
    ;

print_func:
      PRINT                 
      "(" 
      const                 { gflag = 3; print_const_flag = 1; }
      ")" 
      SEMICOLON
    | PRINT                 
      "(" 
      ID ")" SEMICOLON      { if (!lookup_symbol($3, 0)) { 
                                  error_type_flag = 1; 
                                  strcat(error_msg, "Undeclared variable ");
                                  strcat(error_msg, $3);
                              }
                              else {
                                  gflag = 3;
                                  symbol_t node = find_symbol($3, 0);
                                  print_id_index = node.index;
                                  strcpy(print_id_type, node.type);
                              }
                            }    
    ;

selection_stat:
      if_else_stat          { selection_flag = 1; else_end_flag = 1; puts("else scope end"); }
    | if_stat 
    ;

if_else_stat:
      IF "(" expr ")"       { if_else_flag = 1; /* puts("if _else"); */ }
      compound_stat         { selection_flag = 1; if_end_with_else_flag = 1; }
      ELSE                  { selection_flag = 1; else_begin_flag = 1; puts("else begin"); }
      stat                  { /* selection_flag = 1; else_end_flag = 1;  puts("else scope end"); */ }
    ;

if_stat:
      IF "(" expr ")"       { if_flag = 1; }
      compound_stat         { selection_flag = 1; if_end_flag = 1; }
    ;

loop_stat:
      WHILE                 
      "("                   
      expr
      ")"                   
      stat
    ;

jump_stat:
      RETURN SEMICOLON      { gflag = 4; return_void_flag = 1; }
    | RETURN expr SEMICOLON { gflag = 4; }
    ;

%%

/* C code section */
int main(int argc, char** argv)
{
    for (int i = 0; i < 32; i++)
        t[i] = NULL;

    yylineno = 0;

    file = fopen("compiler_hw3.j", "w");

    fprintf(file, ".class public compiler_hw3\n"
                  ".super java/lang/Object\n");
    //              ".method public static main([Ljava/lang/String;)V\n");

    yyparse();

    if (!syntax_error_flag) {
        dump_symbol();                          // dump table[0]
        printf("\nTotal lines: %d \n", yylineno);
    }

    //fprintf(file, ".end method\n");

    fclose(file);

    return 0;
}

void yyerror(char *s)
{
    /*
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, code_line);
    printf("| %s", s);
    printf("\n| Unmatched token: %s", yytext);
    printf("\n|-----------------------------------------------|\n");
    exit(-1);
    */

    if (strcmp(s, "syntax error") == 0) {
        syntax_error_flag = 1;
        yylineno++;
        parse_newline();
        return;
    }
    
    if (error_type_flag) {
        printf("\n|-----------------------------------------------|\n");
        printf("| Error found in line %d: %s\n", yylineno, code_line);
        printf("| %s", s);
        printf("\n| Unmatched token: %s", yytext);
        printf("\n|-----------------------------------------------|\n\n");
    }

    if (syntax_error_flag) {
        printf("\n|-----------------------------------------------|\n");
        printf("| Error found in line %d: %s\n", yylineno, code_line);
        printf("| syntax error");
        printf("\n| Unmatched token: %s", yytext);
        printf("\n|-----------------------------------------------|\n\n");
    }
}

/* symbol table functions */
void create_symbol() 
{
    //puts("!!!!!!!!!!!!!!!!!!!!create_symbol");
    t[scope] = malloc(sizeof(table_t));
    if (t[scope] == NULL)
        return;
    t[scope]->head = NULL;
    create_table_flag[scope] = 1;
}

/* add a new node at tail */
void insert_symbol(symbol_t x) 
{
    //puts("!!!!!!!!!!!!!!!!!insert_symbol");
    //printf("~~~~~~~~~~~~~~~~~scope=%d\n", scope);
    symbol_t *nw, *p; 
    if (!create_table_flag[scope])
        create_symbol();

    if ( t[scope] == NULL )
        return;
    nw = malloc(sizeof(symbol_t));
    if ( nw == NULL )
        return;
    *nw = x;

    
    if ( t[scope]->head == NULL ) {
        nw->next = NULL;
        t[scope]->head = nw;
        return;
    }
    
    /* move to the tail of the list */
    for ( p = t[scope]->head; p->next != NULL; p = p->next ) 
        ;
    nw->next = NULL;
    p->next = nw;
}

/* check whether `str` is in the table or not
 * from the scope currently at down to `up_to_scope`
 * if it isn't, return 0
 * if it is, return 1
 * if it is a function forward defined before, return 2
 */
int lookup_symbol(char *str, int up_to_scope) 
{
    //printf("look for %s up to %d scope\n", str, up_to_scope);
    int i;
    symbol_t *p;
    for ( i = scope; i >= up_to_scope ; i-- ) {
        if (t[i] == NULL) {
            continue;
        }
        for ( p = t[i]->head; p != NULL; p = p->next ) {
            //printf("%s and %s\n", str, p->name);
            if (strcmp(str, p->name) == 0) {
                if (p->func_forward_def)
                    return 2;
                return 1;
            }
        }
    }
    return 0;
}

/* return the symbol `str` in the table
 * if it is not found, return empty
 */
symbol_t find_symbol(char *str, int up_to_scope) 
{
    int i;
    symbol_t *p, empty;
    for ( i = scope; i >= up_to_scope ; i-- ) {
        if (t[i] == NULL) {
            continue;
        }
        for ( p = t[i]->head; p != NULL; p = p->next ) {
            //printf("%s and %s\n", str, p->name);
            if (strcmp(str, p->name) == 0) {
                //if (p->func_forward_def)
                //    return 100;
                return *p;
            }
        }
    }
    return empty;
}

void dump_symbol() 
{
    //puts("!!!!!!!!!!!!!!!!!dump_symbol");
    //printf("~~~~~~~~~~~~scope=%d\n", scope);
    symbol_t *p, *prev;
    if (syntax_error_flag)
        return;

    if ( t[scope] == NULL ) {
        //puts("!!!!!!!!!!!!!!!!!but actually dump nothing");
        scope--;
        return;
    }
    if ( t[scope]->head == NULL ) {
        free(t[scope]);
        return;
    }
    printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
    for ( p = t[scope]->head; p != NULL; ) {
        if ( strcmp(p->attribute, "") == 0 ) {
            printf("%-10d%-10s%-12s%-10s%-10d\n",
                    p->index, p->name, p->kind, p->type, p->scope);
        }
        else {
            printf("%-10d%-10s%-12s%-10s%-10d%s\n",
                    p->index, p->name, p->kind, p->type, p->scope, p->attribute);
        }
        prev = p;
        p = p->next;
        free(prev);
    }
    puts("");
    free(t[scope]);
    t[scope] = NULL;
    //if (t[scope]==NULL)
    //    printf("free table[%d]\n", scope);
    create_table_flag[scope] = 0;
    table_item_index[scope] = 0;
    scope--;
}

void dump_parameter() 
{
    //puts("!!!!!!!!!!!!!!!!!dump_parameter");
    //printf("~~~~~~~~~~~~scope=%d\n", scope);
    symbol_t *p, *prev;
    if ( t[scope] == NULL ) {
        //puts("!!!!!!!!!!!!!!!!!but actually dump nothing");
        scope--;
        return;
    }
    if ( t[scope]->head == NULL ) {
        free(t[scope]);
        return;
    }

    for ( p = t[scope]->head; p != NULL; ) {
        prev = p;
        p = p->next;
        free(prev);
    }
    
    free(t[scope]);
    t[scope] = NULL;
    create_table_flag[scope] = 0;
    table_item_index[scope] = 0;
    scope--;
}

void push_type(char *str)
{
    //printf("!!!!!!!!!!!!!!!!!push %s\n", str);
    strcpy(type_stack[stack_index], str);
    stack_index++;
}

void pop_type()
{
    stack_index--;
    //printf("!!!!!!!!!!!!!!!!!pop %s\n", type_stack[stack_index]);
    strcpy(rfunc.type, type_stack[stack_index]);
    strcpy(type_stack[stack_index], "");
}

void parse_newline()
{
    if (strcmp(code_line, "") == 0) {
        printf("%d:\n", yylineno); 
    }
    else {
        printf("%d: %s\n", yylineno, code_line); 
        if (rcb_flag) {
            //puts("ready to dump symbol"); 
            dump_symbol(); 
            rcb_flag = 0; 
        }
        if (error_type_flag || syntax_error_flag) {
            yyerror(error_msg);
        }
        error_type_flag = 0;
        strcpy(error_msg, "");
        strcpy(code_line, "");
    } 
}

symbol_t find_last(int find_scope)
{
    symbol_t *p;
    /* move to the tail of the list */
    for ( p = t[find_scope]->head; p->next != NULL; p = p->next ) 
        ;
    return *p;
}

void parse_func_attr(char *s, char r[])
{
    int i, j = 1;
    int c = 'A' - 'a';

    r[0] = *s + c;

    for (i = 1; *(s+i) != '\0'; i++) {
        if (*(s+i) == ',') {
            r[j] = *(s+i+2) + c;
            j++;
        }
    }
    r[j] = '\0';
}

/* code generation function
 * 
 * 0: global variables
 * 1: function def
 * 2: local variables
 * 3: print
 * 4: return
 * 5: end function
 * 6: expr
 * 7: if else
 */
void gencode_function() 
{
    if (selection_flag ) {
        
        if (if_end_with_else_flag) {
            fprintf(file, "\tgoto Exit_%d\n", current_label_index);
            if_end_with_else_flag = 0;
        }

        if (if_end_flag) {
            fprintf(file, "\tExit_%d:\n", current_label_index);
            current_label_index--;
            if_end_flag = 0;
        }

        if (else_begin_flag) {
            fprintf(file, "\tLabel_%d:\n", current_label_index);
            else_begin_flag = 0;
        }

    }

    if (gflag == 0) {
        symbol_t node = find_last(scope);
        fprintf(file, ".field public static ");
        fprintf(file, "%s ", node.name);

        if (strcmp(node.type, "int") == 0)
            fprintf(file, "I");
        else if (strcmp(node.type, "float") == 0)
            fprintf(file, "F");
        else if (strcmp(node.type, "bool") == 0)
            fprintf(file, "Z");
        if (glo_var_assi_flag) {
            fprintf(file, " = %s", glo_var_value);
            glo_var_assi_flag = 0;
            strcpy(glo_var_value, "");
        }
        fprintf(file, "\n");
    }
    else if (gflag == 1) {
        symbol_t node = find_last(0);
        char func_para_type[16];
        
        fprintf(file, ".method public static ");
        fprintf(file, "%s", node.name);

        if (strcmp(node.name, "main") == 0)
            fprintf(file, "([Ljava/lang/String;)");
        else {
            parse_func_attr(node.attribute, func_para_type);
            fprintf(file, "(%s)", func_para_type);
        }
        
        if (strcmp(node.type, "int") == 0)
            fprintf(file, "I\n");
        else if (strcmp(node.type, "float") == 0)
            fprintf(file, "F\n");
        else if (strcmp(node.type, "bool") == 0)
            fprintf(file, "Z\n");
        else if (strcmp(node.type, "void") == 0)
            fprintf(file, "V\n");
        
        fprintf(file, ".limit stack 50\n"
                      ".limit locals 50\n");
    }
    else if (gflag == 2) {
        symbol_t node = find_last(scope);
        //printf("node=%s, index=%d, type=%s, flag=%d\n", node.name, node.index, node.type, loc_var_assi_flag);
        if (loc_var_assi_flag) {
            printf("%s\n", loc_var_value);

            if (strcmp(node.type, "string") == 0) {
                fprintf(file, "\tldc \"%s\"\n", loc_var_value);
            }
            else {
                //printf("here~~~~~~~~\n");
                fprintf(file, "\tldc %s\n", loc_var_value);
                //printf("else end~~~~~~~~\n");
            }
                
            loc_var_assi_flag = 0;
        }
        else {
            if (strcmp(node.type, "int") == 0)
                fprintf(file, "\tldc 0\n");         // defaut to init it to 0
            else if (strcmp(node.type, "float") == 0)
                fprintf(file, "\tldc 0.0\n");       // defaut to init it to 0.0
        }
        if (strcmp(node.type, "int") == 0)    
            fprintf(file, "\tistore %d\n", node.index);
        else if (strcmp(node.type, "float") == 0)
            fprintf(file, "\tfstore %d\n", node.index);
        else if (strcmp(node.type, "string") == 0)
            fprintf(file, "\tastore %d\n", node.index);
        else if (strcmp(node.type, "bool") == 0)
            fprintf(file, "\tistore %d\n", node.index);
        strcpy(loc_var_value, "");
    }
    else if (gflag == 3) {
        if (print_const_flag) {
            if (strcmp(print_const_type, "Ljava/lang/String;") == 0) {
                //printf("~~~~~~~~~~%s\n", print_const_value);
                fprintf(file, "\tldc \"%s\"\n", print_const_value);
            }
            else
                fprintf(file, "\tldc %s\n", print_const_value);
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
	                  "\tswap\n"
	                  "\tinvokevirtual java/io/PrintStream/println");
            fprintf(file, "(%s)", print_const_type);
            fprintf(file, "V\n");
            print_const_flag = 0;
        }
        else {
            
            if (strcmp(print_id_type, "int") == 0) {
                fprintf(file, "\tiload %d\n", print_id_index);
                fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                              "\tswap\n"
                              "\tinvokevirtual java/io/PrintStream/println");
                fprintf(file, "(I)");
            }
            else if (strcmp(print_id_type, "float") == 0) {
                fprintf(file, "\tfload %d\n", print_id_index);
                fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                              "\tswap\n"
                              "\tinvokevirtual java/io/PrintStream/println");
                fprintf(file, "(F)");
            }
            else if (strcmp(print_id_type, "string") == 0) {
                fprintf(file, "\taload %d\n", print_id_index);
                fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                              "\tswap\n"
                              "\tinvokevirtual java/io/PrintStream/println");
                fprintf(file, "(Ljava/lang/String;)");
            }
            fprintf(file, "V\n");
        }
    }
    else if (gflag == 4) {
        symbol_t node;
        node = find_last(0);
        
        if (strcmp(node.type, "void") == 0) {
            if (return_void_flag) {
                fprintf(file, "\treturn\n");
                return_void_flag = 0;
            }
            else
                printf("this should not happen...\n");
        }
        else if (strcmp(node.type, "int") == 0) {
            fprintf(file, "\tireturn\n");
        }
        else if (strcmp(node.type, "float") == 0) {
            fprintf(file, "\tfreturn\n");
        }
        else if (strcmp(node.type, "bool") == 0) {
            fprintf(file, "\tireturn\n");
        }

        
    }
    else if (gflag == 5) {
        if (scope == 0)
            fprintf(file, ".end method\n");
    }
    else if (gflag == 6) {
        //printf("%s\n", expr_buf);

        int record_flag = 0, action_flag = 0, recognition_flag = 1;
        int j = 0;
        char record[32];
        char action = ' ', c, c_next;
        char assi_var[32];
        symbol_t node;
        int i, len = strlen(expr_buf);

        for (i = 0; i < len; i++) {
            c = expr_buf[i];
            c_next = expr_buf[i+1];

            if (recognition_flag) {
                if (c == 'I' || c == 'F') {
                    action = c;
                    record_flag = 1;
                    recognition_flag = 0;
                    continue;
                }
                if (c == 'V') {
                    action = 'V';
                    record_flag = 1;
                    recognition_flag = 0;
                    continue;
                }
            }


            if (record_flag) {
                /* encounter a white space, go to action section */
                if (expr_buf[i] == ' ') {
                    record[j] = '\0';
                    j = 0;
                    recognition_flag = 1;
                    record_flag = 0;
                    action_flag = 1;
                }
                else {
                    record[j] = expr_buf[i];
                    j++;
                }
            }

            if (action_flag) {
                if (action == 'I') {
                    fprintf(file, "\tldc %s\n", record);
                    if (expr_fmode)
                        fprintf(file, "\ti2f\n");
                }
                else if (action == 'F') {
                    fprintf(file, "\tldc %s\n", record);
                }
                else if (action == 'V') {
                    
                    if (assi_flag && c_next == '=') {
                        //assi_flag = 1;
                        strcpy(assi_var, record);
                    }
                    /* += -= *= /= %= */
                    else if (assi_flag && expr_buf[i+2] == '=') {
                        strcpy(assi_var, record);
                        symbol_t node = find_symbol(assi_var, 1);

                        if (strcmp(node.type, "int") == 0) {
                            fprintf(file, "\tiload %d\n", node.index);
                        }
                        else if (strcmp(node.type, "float") == 0) {
                            fprintf(file, "\tfload %d\n", node.index);
                        }
                    }
                    else {
                        node = find_symbol(record, scope);

                        if (strcmp(node.type, "int") == 0) {
                            fprintf(file, "\tiload %d\n", node.index);
                            if (expr_fmode)
                                fprintf(file, "\ti2f\n");
                        }
                        else if (strcmp(node.type, "float") == 0)
                            fprintf(file, "\tfload %d\n", node.index);
                    }

                }
                action_flag = 0;
            }

            
            if (expr_fmode) {
                if (c == '+' && c_next == ' ') {
                    fprintf(file, "\tfadd\n");
                }
                else if (c == '-' && c_next == ' ') {
                    fprintf(file, "\tfsub\n");
                }
                else if (c == '*' && c_next == ' ') {
                    fprintf(file, "\tfmul\n");
                }
                else if (c == '/' && c_next == ' ') {
                    fprintf(file, "\tfdiv\n");
                }
                else if (c == '%' && c_next == ' ') {
                    yyerror("mod float");
                }
            }
            else {
                if (c == '+' && c_next == ' ') {
                    fprintf(file, "\tiadd\n");
                }
                else if (c == '-' && c_next == ' ') {
                    fprintf(file, "\tisub\n");
                }
                else if (c == '*' && c_next == ' ') {
                    fprintf(file, "\timul\n");
                }
                else if (c == '/' && c_next == ' ') {
                    fprintf(file, "\tidiv\n");
                }
                else if (c == '%' && c_next == ' ') {
                    fprintf(file, "\tirem\n");
                }
            }
            
            /* post ++, -- */
            if (c == '+' && c_next == '+') {
                if (strcmp(node.type, "int") == 0) {
                    fprintf(file, "\tiload %d\n", node.index);
                    fprintf(file, "\tldc 1\n");
                    fprintf(file, "\tiadd\n");
                    fprintf(file, "\tistore %d\n", node.index);
                }
                else if (strcmp(node.type, "float") == 0) {
                    fprintf(file, "\tfload %d\n", node.index);
                    fprintf(file, "\tldc 1.0\n");
                    fprintf(file, "\tfadd\n");
                    fprintf(file, "\tfstore %d\n", node.index);
                }
                i++; // increment two !!
            }
            else if (c == '-' && c_next == '-') {
                if (strcmp(node.type, "int") == 0) {
                    fprintf(file, "\tiload %d\n", node.index);
                    fprintf(file, "\tldc 1\n");
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tistore %d\n", node.index);
                }
                else if (strcmp(node.type, "float") == 0) {
                    fprintf(file, "\tfload %d\n", node.index);
                    fprintf(file, "\tldc 1.0\n");
                    fprintf(file, "\tfsub\n");
                    fprintf(file, "\tfstore %d\n", node.index);
                }
                i++; // increment two !!
            }

            if (if_else_flag) {
                if (c == '>' && c_next == ' ') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tifle Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
                else if (c == '<' && c_next == ' ') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tifge Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
                else if (c == '>' && c_next == '=') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tiflt Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
                else if (c == '<' && c_next == '=') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tifgt Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
                else if (c == '=' && c_next == '=') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tifne Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
                else if (c == '!' && c_next == '=') {
                    fprintf(file, "\tisub\n");
                    fprintf(file, "\tifeq Label_%d\n", label_index);
                    current_label_index = label_index;
                    label_index++;
                    i++; // increment two!!
                    if_else_flag = 0;
                }
            }

            if (if_flag) {
                if_flag = 0;
            }
        } //end for

        if (assi_flag) {
            symbol_t node = find_symbol(assi_var, scope);

            if (expr_fmode) {
                if (assi_flag == 2) {
                    fprintf(file, "\tfadd\n");
                }
                else if (assi_flag == 3) {
                    fprintf(file, "\tfsub\n");
                }
                else if (assi_flag == 4) {
                    fprintf(file, "\tfmul\n");
                }
                else if (assi_flag == 5) {
                    fprintf(file, "\tfdiv\n");
                }
                else if (assi_flag == 6) {
                    yyerror("mod float");
                }
            }
            else {
                if (assi_flag == 2) {
                    fprintf(file, "\tiadd\n");
                }
                else if (assi_flag == 3) {
                    fprintf(file, "\tisub\n");
                }
                else if (assi_flag == 4) {
                    fprintf(file, "\timul\n");
                }
                else if (assi_flag == 5) {
                    fprintf(file, "\tidiv\n");
                }
                else if (assi_flag == 6) {
                    fprintf(file, "\tirem\n");
                }
            }

            if (strcmp(node.type, "int") == 0) {
                if (expr_fmode)
                    fprintf(file, "\tf2i\n");
                fprintf(file, "\tistore %d\n", node.index);
            }
            else if (strcmp(node.type, "float") == 0) {
                if (!expr_fmode)
                    fprintf(file, "\ti2f\n");
                fprintf(file, "\tfstore %d\n", node.index);
            }

            assi_flag = 0;
            expr_fmode = 0;
        } //end if (assi_flag)

        strcpy(expr_buf, "");
    } // end if (gflag == 6)

    if (selection_flag) {
        if (else_end_flag) {
            fprintf(file, "\tExit_%d:\n", current_label_index);
            current_label_index--;
            else_end_flag = 0;
        }
    }

    selection_flag = 0;
    gflag = -1;
}
