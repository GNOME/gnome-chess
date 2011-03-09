class GlChess
{
    static int test_count = 0;
    static int failure_count = 0;

    private static void test_good_move (string fen, string move, string result_fen,
                                        ChessResult result = ChessResult.IN_PROGRESS,
                                        ChessRule rule = ChessRule.CHECKMATE)
    {
        ChessState state = new ChessState (fen);
        test_count++;
        if (!state.move (move))
        {
            stderr.printf ("%d. FAIL %s + %s is a valid move\n", test_count, fen, move);
            failure_count++;
            return;
        }

        if (state.get_fen () != result_fen)
        {
            stderr.printf ("%d. FAIL %s + %s has state %s not %s\n", test_count, fen, move, state.get_fen (), result_fen);
            failure_count++;
            return;
        }

        if (state.last_move.get_san () != move)
        {
            stderr.printf ("%d. FAIL %s + %s has SAN move %s\n", test_count, fen, move, state.last_move.get_san ());
            failure_count++;
            return;
        }

        ChessRule move_rule;
        var move_result = state.get_result (out move_rule);
        if (move_result != result || move_rule != rule)
        {
            stderr.printf ("%d. FAIL %s + %s has result %d not %d\n", test_count, fen, move, move_result, result);
            failure_count++;
            return;
        }

        stderr.printf ("%d. PASS %s + %s is valid\n", test_count, fen, move);
    }

    private static void test_bad_move (string fen, string move)
    {
        ChessState state = new ChessState (fen);
        test_count++;
        if (state.move (move, false))
        {
            stderr.printf ("%d. FAIL %s + %s is valid\n", test_count, fen, move);
            failure_count++;
            return;
        }

        stderr.printf ("%d. PASS %s + %s is invalid\n", test_count, fen, move);
    }

    public static int main (string[] args)
    {
        /* Pawn move */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a3",
                        "8/8/8/8/8/P7/8/8 b - - 0 1");

        /* Pawn march */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a4",
                        "8/8/8/8/P7/8/8/8 b - a3 0 1");

        /* Pawn march only allowed from baseline */
        test_bad_move ("8/8/8/8/8/P7/8/8 w - - 0 1", "a2a5");

        /* Pawn promotion */
        test_good_move ("8/P7/8/8/8/8/8/8 w - - 0 1", "a8=Q",
                        "Q7/8/8/8/8/8/8/8 b - - 0 1");

        /* En passant */
        test_good_move ("8/8/8/pP6/8/8/8/8 w - a6 0 1", "bxa6",
                        "8/8/P7/8/8/8/8/8 b - - 0 1");

        /* Can't en passant if wasn't allowed */
        test_bad_move ("8/8/8/pP6/8/8/8/8 w - - 0 1", "b5a6");

        /* Castle kingside */
        test_good_move ("8/8/8/8/8/8/8/4K2R w K - 0 1", "O-O",
                        "8/8/8/8/8/8/8/5RK1 b - - 1 1");

        /* Castle queenside */
        test_good_move ("8/8/8/8/8/8/8/R3K3 w Q - 0 1", "O-O-O",
                        "8/8/8/8/8/8/8/2KR4 b - - 1 1");

        /* Can't castle if pieces moved */
        test_bad_move ("8/8/8/8/8/8/8/4K2R w - - 0 1", "O-O");

        /* Can't castle if rook not there (shouldn't occur as then the castle flag would not be there) */
        test_bad_move ("8/8/8/8/8/8/8/4K3 w K - 0 1", "O-O");

        /* Can't castle when in check */
        test_bad_move ("4r3/8/8/8/8/8/8/4K2R w K - 0 1", "O-O");

        /* Can't move across square that would put into check */
        test_bad_move ("5r2/8/8/8/8/8/8/4K2R w K - 0 1", "O-O");

        /* Can't move into check */
        test_bad_move ("4r3/8/8/8/8/8/4R3/4K3 w - - 0 1", "e2f2");

        /* Check */
        test_good_move ("k7/8/8/8/8/8/8/1R6 w - - 0 1", "Ra1+",
                        "k7/8/8/8/8/8/8/R7 b - - 1 1");

        /* Checkmate */
        test_good_move ("k7/8/8/8/8/8/1R6/1R6 w - - 0 1", "Ra1#",
                        "k7/8/8/8/8/8/1R6/R7 b - - 1 1", ChessResult.WHITE_WON, ChessRule.CHECKMATE);

        /* Not checkmate (piece can be moved to intercept) */
        test_good_move ("k7/7r/8/8/8/8/1R6/1R6 w - - 0 1", "Ra1+",
                        "k7/7r/8/8/8/8/1R6/R7 b - - 1 1");

        /* Stalemate */
        test_good_move ("k7/8/7R/8/8/8/8/1R6 w - - 0 1", "Rh7",
                        "k7/7R/8/8/8/8/8/1R6 b - - 1 1", ChessResult.DRAW, ChessRule.STALEMATE);

        /* Insufficient material */
        test_good_move ("k7/7p/7K/8/8/8/8/8 w - - 0 1", "Kxh7",
                        "k7/7K/8/8/8/8/8/8 b - - 0 1", ChessResult.DRAW, ChessRule.INSUFFICIENT_MATERIAL);

        // FIXME: Need to be able to test claim draw

        /* Claim draw due to 50 move rule */
        //test_good_move ("p7/8/8/8/8/8/8/P7 w - - 50 1", "draw",
        //                "p7/8/8/8/8/8/8/P7 w - - 50 1", ChessResult.DRAW, ChessRule.FIFTY_MOVES);

        /* Need 50 moves for 50 move rule */
        //test_bad_move ("p7/8/8/8/8/8/8/P7 w - - 49 1", "draw");

        /* Three fold repetition */
        // FIXME: Need a test for three fold repetition

        stdout.printf ("%d/%d tests successful\n", test_count - failure_count, test_count);

        return failure_count;
    }
}
