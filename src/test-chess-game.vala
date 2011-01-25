class GlChess
{
    static int test_count = 0;
    static int failure_count = 0;

    private static void test_good_move (string fen, string move, string result_fen, CheckState check_state = CheckState.NONE)
    {
        ChessState state = new ChessState (fen);
        test_count++;
        if (!state.move (move))
        {
            stderr.printf ("%d. Not allowed to do valid move: %s : %s\n", test_count, fen, move);
            failure_count++;
            return;
        }

        if (state.get_fen () != result_fen)
        {
            stderr.printf ("%d. Move led to invalid state: %s : %s -> %s, not %s\n", test_count, fen, move, state.get_fen (), result_fen);
            failure_count++;
            return;
        }

        if (state.check_state != check_state)
        {
            stderr.printf ("%d. Move led to invalid check state: %s : %s -> %d, not %d\n", test_count, fen, move, state.check_state, check_state);
            failure_count++;
            return;
        }

        stderr.printf ("%d. %s + %s -> %s OK\n", test_count, fen, move, result_fen);
    }

    private static void test_bad_move (string fen, string move)
    {
        ChessState state = new ChessState (fen);
        test_count++;
        if (state.move (move, false))
        {
            stderr.printf ("%d. Allowed to do invalid move: %s : %s\n", test_count, fen, move);
            failure_count++;
            return;
        }

        stderr.printf ("%d. %s + %s -> invalid OK\n", test_count, fen, move);
    }

    public static int main (string[] args)
    {
        /* Pawn move */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a2a3",
                        "8/8/8/8/8/P7/8/8 b - - 0 1");

        /* Pawn march */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a2a4",
                        "8/8/8/8/P7/8/8/8 b - a3 0 1");

        /* Pawn march only allowed from baseline */
        test_bad_move ("8/8/8/8/8/P7/8/8 w - - 0 1", "a2a5");
        
        /* En passant */
        test_good_move ("8/8/8/pP6/8/8/8/8 w - a6 0 1", "b5a6",
                        "8/8/P7/8/8/8/8/8 b - - 0 1");

        /* Can't en passant if wasn't allowed */
        test_bad_move ("8/8/8/pP6/8/8/8/8 w - - 0 1", "b5a6");

        /* Castle kingside */
        test_good_move ("8/8/8/8/8/8/8/4K2R w K - 0 1", "O-O",
                        "8/8/8/8/8/8/8/5RK1 b - - 0 1");

        /* Castle queenside */
        test_good_move ("8/8/8/8/8/8/8/R3K3 w Q - 0 1", "O-O-O",
                        "8/8/8/8/8/8/8/2KR4 b - - 0 1");

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

        /* Checkmate */
        test_good_move ("k7/8/8/8/8/8/1R6/1R6 w - - 0 1", "b1a1",
                        "k7/8/8/8/8/8/1R6/R7 b - - 0 1", CheckState.CHECKMATE);

        stdout.printf ("%d/%d tests successful\n", test_count - failure_count, test_count);

        return failure_count;
    }
}
