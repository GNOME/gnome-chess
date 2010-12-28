class GlChess
{
    static int test_count = 0;
    static int failure_count = 0;

    private static void test_good_move (string fen, string move)
    {
        ChessState state = new ChessState (fen);
        if (!state.move (move, false))
        {
            stderr.printf ("Not allowed to do valid move: %s : %s\n", fen, move);
            failure_count++;
        }
        test_count++;
    }

    private static void test_bad_move (string fen, string move)
    {
        ChessState state = new ChessState (fen);
        if (state.move (move, false))
        {
            stderr.printf ("Allowed to do invalid move: %s : %s\n", fen, move);
            failure_count++;
        }
        test_count++;
    }

    public static int main (string[] args)
    {
        /* Pawn move */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a2a3");

        /* Pawn march */
        test_good_move ("8/8/8/8/8/8/P7/8 w - - 0 1", "a2a4");

        /* Pawn march only allowed from baseline */
        test_bad_move ("8/8/8/8/8/P7/8/8 w - - 0 1", "a2a5");
        
        /* En passant */
        test_good_move ("8/8/8/pP6/8/8/8/8 w - a6 0 1", "b5a6");

        /* Castle kingside */
        test_good_move ("8/8/8/8/8/8/8/4K2R w K - 0 1", "O-O");

        /* Castle queenside */
        test_good_move ("8/8/8/8/8/8/8/R3K3 w Q - 0 1", "O-O-O");

        /* Can't castle if pieces moved */
        test_bad_move ("8/8/8/8/8/8/8/4K2R w - - 0 1", "O-O");

        /* Can't castle if rook not there (shouldn't occur as then the castle flag would not be there) */
        test_bad_move ("8/8/8/8/8/8/8/4K3 w K - 0 1", "O-O");

        /* Can't castle when in check */
        test_bad_move ("4r3/8/8/8/8/8/8/4K2R w K - 0 1", "O-O");

        /* Can't move across square that would put into check */
        test_bad_move ("5r2/8/8/8/8/8/8/4K2R w K - 0 1", "O-O");

        /* Can't move into check */
        test_bad_move ("4r3/8/8/8/8/8/4R3/4K3 w KQkr - 0 1", "e2f2");

        stdout.printf ("%d/%d tests successful\n", test_count - failure_count, test_count);

        return failure_count;
    }
}
