%{

/* lexpgn by David A. Wheeler (http://www.dwheeler.com).

   This code processes files formatted using PGN, as defined in
   "Standard Portable Game Notation Specification and Implementation
   Guide" Revised 1994.03.12 by Steven J. Edwards.

   This code lexically analyzes PGN files as an import format; since it's
   importing, it tries to accept nonstandard formats as much as it can and
   figure out the "intent".  It handles varying newlines (e.g. \r), etc.
   It will accept a great deal of misformatting that isn't,
   strictly speaking, legal PGN, but the point is to be able to figure
   out what was intended.

   Calling the lexer will process ONE game in a file,
   starting with 0 or more tags, followed by 0 or more moves.
   It returns 0 if no erors, 1 if errors, 2 if terminated (normally).

   It will place data somewhere depending on the value of data_dest;
   if data_dest is DEST_TRASH, it skips the game (not fully implemented),
   if data_dest is DEST_GAME, it stores into Game[],
   if data_dest is DEST_BOOK, it's stored into the book material.
   To process a multi-game PGN file, call it again and again.

   Some of the funny ordering (e.g., for bracecomment) is to make it
   high speed.  Flex/lex can produce high speed lexers, but only
   if it gets some help, in particular by defining patterns that
   maximally match.

   TODO: prevent buffer overflow for FEN.


*/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "common.h"
#include "lexpgn.h"
#include "book.h"


enum tagtype { NO_TAG, EVENT_TAG, SITE_TAG, DATE_TAG, ROUND_TAG,
	       WHITE_TAG, BLACK_TAG, RESULT_TAG, 
               WHITE_ELO_TAG, BLACK_ELO_TAG,
               WHITETITLE_TAG, BLACKTITLE_TAG, FEN_TAG,
               OTHER_TAG };

enum data_destination_t data_dest;

#define yyterminate() { if ( seen_tags || seen_moves) return 1; \
			return 2; }
		

char *pgn_event;
char *pgn_site;
char *pgn_date;
char *pgn_round;
char *pgn_white;
char *pgn_black;
char *pgn_result;
char *pgn_whiteELO;
char *pgn_blackELO;
char *pgn_othertags;
char *initial_comments; /* PGN comments before any moves */

char *return_append_str(char *dest, const char *s) {
/* Append text s to dest, and return new result. */
	char *newloc;
	size_t newlen;
	/* This doesn't have buffer overflow vulnerabilities, because
	   we always allocate for enough space before appending. */
	if (!dest) {
		newloc = (char *) malloc(strlen(s))+1;
		strcpy(newloc, s);
		return newloc;
	}
	newlen = strlen(dest) + strlen(s) + 1;
	newloc = (char *) malloc(newlen);
	strcpy(newloc, dest);
	if (!newloc) return dest; /* Can't do it, throw away the data */
	strcat(newloc, s);
	return newloc;
}

void append_str(char **dest, const char *s) {
/* Append text s to *dest, and modify *dest to new location. */
	char *temp;
	temp = return_append_str(*dest, s);
	*dest = temp;
}

void append_comment(const char *t) {
/* Append PGN text t after the current move */
	if (data_dest == DEST_GAME) {
		/* TODO */
		if (GameCnt < 1) {
			append_str(&initial_comments,t);
		} else {
			append_str(&(Game[GameCnt].comments),t);
		}
	}
}

%}


%option case-insensitive
%option full
%option ecs
%option pointer
%option noyywrap


SPACE		[ \t\n\r\f]
NONSPACE	[^ \t\n\r\f]

%x tag_gobble
%x tagsymbol
%x tagsep
%x tagdata
%x tagend
%x bracecomment
%x RAV

%%
	/* These are executed on each entry to the code */
	int seen_tags = 0;
	int seen_moves = 0;
	enum tagtype ctag = NO_TAG;
	int firstmovenum = -1;
	int side = white;
	int rav_count = 0;
	int result = R_NORESULT;
	char tagname[80]; /* Name of tag currently being processed */
	leaf *p;
	int addtobook[2];
	addtobook[0] = 0;
	addtobook[1] = 0;


{SPACE}+		{ /* Ignore whitespace */ }
\%[^\r\n]*		{ /* Ignore PGN escape. We'll allow initial space. */ }

\[[ \t]*		{
	/* Handle "[".  If we've already seen a move, return "[" to
	   the stream and return. */
	/* We rashly match on any SC to avoid trouble with unmatched
	   brackets of various types */
	seen_tags = 1;
	ctag = NO_TAG;
	if (seen_moves) {
		BEGIN(INITIAL);
		yyless(0); /* put the "[" back. */
		return 0;
	}
	if (data_dest == DEST_TRASH) {BEGIN(tag_gobble);}
 	else { BEGIN(tagsymbol); }
	}


<tag_gobble>[^\n\r]*		{BEGIN(INITIAL);}

<tagsymbol>white		{ctag = WHITE_TAG; BEGIN(tagsep);}
<tagsymbol>black		{ctag = BLACK_TAG; BEGIN(tagsep);}
<tagsymbol>result		{ctag = RESULT_TAG; BEGIN(tagsep);}
<tagsymbol>whitetitle		{ctag = WHITETITLE_TAG; BEGIN(tagsep);}
<tagsymbol>blacktitle		{ctag = BLACKTITLE_TAG; BEGIN(tagsep);}
<tagsymbol>fen			{ctag = FEN_TAG; BEGIN(tagsep);}
<tagsymbol>event		{ctag = EVENT_TAG; BEGIN(tagsep);}
<tagsymbol>site			{ctag = SITE_TAG; BEGIN(tagsep);}
<tagsymbol>date			{ctag = DATE_TAG; BEGIN(tagsep);}
<tagsymbol>round		{ctag = ROUND_TAG; BEGIN(tagsep);}
<tagsymbol>whiteELO		{ctag = WHITE_ELO_TAG; BEGIN(tagsep);}
<tagsymbol>blackELO		{ctag = BLACK_ELO_TAG; BEGIN(tagsep);}
<tagsymbol>[a-z0-9_]+		{
	ctag = OTHER_TAG;
	if (yyleng >= (sizeof(tagname)-1)) {
		printf("Error, tagname too long: %s", yytext);
		return 1;
	}
	strncpy(tagname, yytext, sizeof(tagname)-1);
	BEGIN(tagsep);
	}
<tagsymbol>[ \t]*\]		{BEGIN(INITIAL); /* No tag name, skip. */}
<tagsymbol>[\n\r]		{BEGIN(INITIAL); /* Line ended early. */}
<tagsymbol>.			{
	printf("Bad character as tag name: %s\n", yytext);
	return 1;
	}

<tagsep>[ \t]+\"?		{BEGIN(tagdata);}
<tagsep>.			{
	printf("Bad character as tag separator: %s\n", yytext);
	return 1;
	}

<tagdata>("\\\""|[^\n\r\"])* { /* tag data */

	/* We start at first " in tag, and must match
	   till we reach an unprotected " or end of line */

	BEGIN(tagend);
	/* TODO: if DEST_GAME, store tag symbol and data for later saving */
	switch(ctag) {
		case WHITE_TAG:
			/* printf("White = %s\n", yytext); */
			if ((data_dest == DEST_BOOK) &&
				 IsTrustedPlayer(yytext)) addtobook[white]=1;
			if (data_dest == DEST_GAME)
				pgn_white = strdup(yytext);
			break;
		case BLACK_TAG:
			/* printf("Black = %s\n", yytext); */
			if ((data_dest == DEST_BOOK) &&
				 IsTrustedPlayer(yytext)) addtobook[black]=1;
			if (data_dest == DEST_GAME)
				pgn_black = strdup(yytext);
			break;
		case RESULT_TAG:
			/* printf("Result = %s\n", yytext); */
			if (!strcmp(yytext, "1-0")) result = R_WHITE_WINS;
			else if (!strcmp(yytext, "0-1")) result = R_BLACK_WINS;
			else if (!strcmp(yytext, "1/2-1/2"))
				 result = R_DRAW;
			if (data_dest == DEST_GAME)
				pgn_result = strdup(yytext);
			break;
		case WHITETITLE_TAG: /* We'll trust GM, IM, FMs */
			if (data_dest == DEST_BOOK &&
			    (strcmp(yytext, "GM") == 0 ||
			     strcmp(yytext, "IM") == 0 ||
			     strcmp(yytext, "FM") == 0))
				addtobook[white]=1;
			if (data_dest == DEST_GAME) {
				append_str(&pgn_othertags, "[WhiteTitle \"");
				append_str(&pgn_othertags, yytext);
				append_str(&pgn_othertags, "\"]\n");
			}
			break;
		case BLACKTITLE_TAG:
			if (data_dest == DEST_BOOK &&
			    (strcmp(yytext, "GM") == 0 ||
			     strcmp(yytext, "IM") == 0 ||
			     strcmp(yytext, "FM") == 0))
				addtobook[black]=1;
			if (data_dest == DEST_GAME) {
				append_str(&pgn_othertags, "[BlackTitle \"");
				append_str(&pgn_othertags, yytext);
				append_str(&pgn_othertags, "\"]\n");
			}
			break;
		case FEN_TAG:
			/* Legal FEN is no more than 81 chars long, because
			   71 (a character for every board cell, plus
			   separators) + 1 (space) + 1 (side, w or b) +
			   1 (space) + 4 (castling, KQkq) + 1 (space) +
			   2 (en passant) = 71.  We'll leave one char
			   for miscount/whitespace. This doesn't fully
			   protect against buffer overflow attacks; the
			   parsing routine still has to check to make sure
			   its input don't force it to walk off the end
			   of any arrays. Still, it helps as a sanity check. */
			/* printf("FEN tag encountered \"%s\"\n",yytext); */
			if (yyleng > 82) {
				printf("Error: FEN too long: %s\n", yytext);
				return 1;
			}
			/* Doesn't return failure/success; just
			   do the best you can */
			ParseEPD(yytext);
			/* Remember it can be black to move now */
			side = board.side;
			if (data_dest == DEST_GAME) {
				append_str(&pgn_othertags, "[FEN \"");
				append_str(&pgn_othertags, yytext);
				append_str(&pgn_othertags, "\"]\n");
			}
			break;
		case EVENT_TAG:
			if (data_dest == DEST_GAME)
				pgn_event = strdup(yytext);
			break;
		case SITE_TAG:
			if (data_dest == DEST_GAME)
				pgn_site = strdup(yytext);
			break;
		case DATE_TAG:
			if (data_dest == DEST_GAME)
				pgn_date = strdup(yytext);
			break;
		case ROUND_TAG:
			if (data_dest == DEST_GAME)
				pgn_round = strdup(yytext);
			break;
		case WHITE_ELO_TAG:
			if (data_dest == DEST_GAME)
				pgn_whiteELO = strdup(yytext);
			break;
		case BLACK_ELO_TAG:
			if (data_dest == DEST_GAME)
				pgn_blackELO = strdup(yytext);
			break;
		case OTHER_TAG:
			if (data_dest == DEST_GAME) {
				append_str(&pgn_othertags, "[");
				append_str(&pgn_othertags, tagname);
				append_str(&pgn_othertags, " \"");
				append_str(&pgn_othertags, yytext);
				append_str(&pgn_othertags, "\"]\n");
			}
			break;
	}
	}

<tagdata>\"[ \t]*\][\n\r]*	{BEGIN(INITIAL);}
<tagdata>\"[^\n\r]*		{BEGIN(INITIAL); /* Garbage, do what can. */}
<tagdata>[\n\r]			{BEGIN(INITIAL); /* End-of-line. */}

<tagend>[^\n\r]*		{BEGIN(INITIAL); /* Consume leftover */}

\;[^\n\r]*		{ /* PGN comment */
	seen_moves = 1;
	append_comment(yytext);
	append_comment("\n");
	}

\{			{ /* PGN comment */
	seen_moves = 1;
	append_comment(yytext);
	BEGIN(bracecomment);
	}
<bracecomment>[^\r\n}]+(\n+[^\r\n}]*)*	{ /* PGN comment; may embed \n */
	append_comment(yytext);
	}
<bracecomment>\}	{
	append_comment(yytext);
	BEGIN(INITIAL);
	}
<bracecomment>\n\r	{ append_comment("\n"); }
<bracecomment>\r\n	{ append_comment("\n"); }
<bracecomment>\r	{ append_comment("\n"); }
<bracecomment>\n	{ append_comment("\n"); }


\${NONSPACE}*		{ seen_moves = 1; /* Numeric Annotation Glyph */
	append_comment(yytext);
	}

\*{SPACE}*		{ return 0; /* could check if consistent w/Result */ }
1\/2-1\/2{SPACE}*	{ return 0; }
0-1{SPACE}*		{ return 0; }
1-0{SPACE}*		{ return 0; }

[1-9][0-9]*\.?		{ seen_moves = 1; /* Move number */
	if (firstmovenum == -1) {
		/* TODO: Use this info somehow */
		sscanf(yytext, "%d", &firstmovenum);
		if (firstmovenum < 0 || firstmovenum > 32000)
			firstmovenum = -1;
		/* printf("First move num=%d\n", firstmovenum); */
	}
	}

\.\.+			{ seen_moves = 1; side = black; }


[a-z0][a-z0-9\-=\+\#\?\!\,]*	{ /* Process a move */
	seen_moves = 1;
	if (data_dest != DEST_TRASH) {
		/*  printf("Seen move %s\n", yytext); */
		/* SAN moves can be at most 7 characters, and
		  Game[].SANmv must be able to store the result. */
		if (yyleng > 7) {
			printf("Error: move too long: %s\n", yytext);
			return 1;
		}
		p = ValidateMove(yytext);
		if (!p) {
			printf ("Illegal move: %s\n", yytext);
			return 1;
		}
		/* MakeMove increments GameCnt */
		MakeMove(side, &p->move);
		if (addtobook[side]) {
			if (BookBuilder (result, side) == BOOK_EFULL) {
				printf("Book full - Failed to add move %s\n",
				       yytext);
				ShowBoard();
				return 1;
			}
	
		}
		strcpy(Game[GameCnt].SANmv, yytext);
		side = 1^side;
	}
	}

\(	{ rav_count = 1; append_comment(yytext); BEGIN(RAV); }
<RAV>\(	{ rav_count++; append_comment(yytext); }
<RAV>\)	{ rav_count--; append_comment(yytext);
	 if (rav_count <=0) BEGIN(INITIAL); }
<RAV>[^\(\)\[]+	{ append_comment(yytext); 
		/* We escape [ to avoid problems with
		   unclosed RAV */
		}
<RAV>^\[[wW]hite	{ yyless(0) ; BEGIN(INITIAL); return(0) ; /* Damn humans */}
<RAV>\[		{ append_comment(yytext); }


<INITIAL,tagsymbol,tagdata>.	{
	 printf("Illegal character %c in input stream.\n", yytext[0]);
	 return 1;
	}

%%

