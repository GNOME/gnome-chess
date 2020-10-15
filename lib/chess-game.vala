/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2014 Robert Ancell
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum ChessResult
{
    IN_PROGRESS,
    WHITE_WON,
    BLACK_WON,
    DRAW,
    BUG
}

public enum ChessRule
{
    UNKNOWN,
    CHECKMATE,
    STALEMATE,
    FIFTY_MOVES,
    SEVENTY_FIVE_MOVES,
    TIMEOUT,
    THREE_FOLD_REPETITION,
    FIVE_FOLD_REPETITION,
    INSUFFICIENT_MATERIAL,
    RESIGN,
    ABANDONMENT,
    DEATH,
    BUG
}

public class ChessGame : Object
{
    public bool is_started;
    public ChessResult result;
    public ChessRule rule;
    public List<ChessState> move_stack;

    private int hold_count = 0;

    public const string STANDARD_SETUP = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

    public signal void turn_started (ChessPlayer player);
    public signal void moved (ChessMove move);
    public signal void paused ();
    public signal void unpaused ();
    public signal void undo ();
    public signal void ended ();

    public bool is_paused { get; private set; default = false; }
    public bool should_show_paused_overlay { get; private set; default = false; }

    public ChessState current_state
    {
       get { return move_stack.data; }
    }

    public ChessPlayer white
    {
        get { return current_state.players[Color.WHITE]; }
    }
    public ChessPlayer black
    {
        get { return current_state.players[Color.BLACK]; }
    }
    public ChessPlayer current_player
    {
        get { return current_state.current_player; }
    }
    public ChessPlayer opponent
    {
        get { return current_state.opponent; }
    }
    private ChessClock? _clock;
    public ChessClock? clock
    {
        get { return _clock; }
        set
        {
            if (is_started)
                return;
            _clock = value;
        }
    }

    public ChessGame (string fen = STANDARD_SETUP, string[]? moves = null) throws PGNError
    {
        is_started = false;
        move_stack.prepend (new ChessState (fen));
        result = ChessResult.IN_PROGRESS;

        if (moves != null)
        {
            for (var i = 0; i < moves.length; i++)
            {
                if (!do_move (current_player, moves[i], true))
                {
                    /* Message when the game cannot be loaded due to an invalid move in the file. */
                    throw new PGNError.LOAD_ERROR (_("Failed to load PGN: move %s is invalid."), moves[i]);
                }
            }
        }

        white.do_move.connect (move_cb);
        white.do_undo.connect (undo_cb);
        white.do_resign.connect (resign_cb);
        white.do_claim_draw.connect (claim_draw_cb);
        black.do_move.connect (move_cb);
        black.do_undo.connect (undo_cb);
        black.do_resign.connect (resign_cb);
        black.do_claim_draw.connect (claim_draw_cb);
    }

    ~ChessGame ()
    {
        if (_clock != null)
            _clock.stop ();
    }

    private bool move_cb (ChessPlayer player, string move, bool apply)
    {
        if (!is_started)
            return false;

        return do_move (player, move, apply);
    }

    private bool do_move (ChessPlayer player, string? move, bool apply)
    {
        if (player != current_player)
            return false;

        var state = current_state.copy ();
        state.number++;
        if (!state.move (move, apply))
            return false;

        if (!apply)
            return true;

        move_stack.prepend (state);
        if (state.last_move.victim != null)
            state.last_move.victim.died ();
        state.last_move.piece.moved ();
        if (state.last_move.castling_rook != null)
            state.last_move.castling_rook.moved ();
        moved (state.last_move);
        complete_move ();

        return true;
    }

    public void add_hold ()
    {
        hold_count++;
    }

    public void remove_hold ()
    {
        return_if_fail (hold_count > 0);

        hold_count--;
        if (hold_count == 0)
            complete_move ();
    }

    private void complete_move ()
    {
        /* Wait until the hold is removed */
        if (hold_count > 0)
            return;

        if (!is_started)
            return;

        ChessRule rule;
        var result = current_state.get_result (out rule);
        if (result != ChessResult.IN_PROGRESS)
        {
            stop (result, rule);
            return;
        }

        if (is_five_fold_repeat ())
        {
            stop (ChessResult.DRAW, ChessRule.FIVE_FOLD_REPETITION);
            return;
        }

        /* Note this test must occur after the test for checkmate in current_state.get_result (). */
        if (is_seventy_five_move_rule_fulfilled ())
        {
            stop (ChessResult.DRAW, ChessRule.SEVENTY_FIVE_MOVES);
            return;
        }

        if (_clock != null)
            _clock.active_color = current_player.color;
        turn_started (current_player);
    }

    private void undo_cb (ChessPlayer player)
    {
        /* If this players turn undo their opponents move first */
        if (player == current_player)
            undo_cb (opponent);

        /* Don't pop off starting move */
        if (move_stack.next == null)
            return;

        /* Pop off the move state and notify */
        move_stack.remove_link (move_stack);
        undo ();
    }

    private bool resign_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        if (player.color == Color.WHITE)
            stop (ChessResult.BLACK_WON, ChessRule.RESIGN);
        else
            stop (ChessResult.WHITE_WON, ChessRule.RESIGN);

        return true;
    }

    private int state_repeated_times (ChessState s1)
    {
        var count = 1;

        foreach (var s2 in move_stack)
        {
            if (s1 != s2 && s1.equals (s2))
                count++;
        }

        return count;
    }

    public bool is_three_fold_repeat ()
    {
        return state_repeated_times (current_state) >= 3;
    }

    public bool is_five_fold_repeat ()
    {
        return state_repeated_times (current_state) >= 5;
    }

    public bool is_fifty_move_rule_fulfilled ()
    {
        /* Fifty moves *per player* without capture or pawn advancement */
        return current_state.halfmove_clock >= 100;
    }

    public bool is_seventy_five_move_rule_fulfilled ()
    {
        /* 75 moves *per player* without capture or pawn advancement */
        return current_state.halfmove_clock >= 150;
    }

    public bool can_claim_draw ()
    {
        return is_fifty_move_rule_fulfilled () || is_three_fold_repeat ();
    }

    private void claim_draw_cb ()
        requires (can_claim_draw ())
    {
        if (is_fifty_move_rule_fulfilled ())
            stop (ChessResult.DRAW, ChessRule.FIFTY_MOVES);
        else if (is_three_fold_repeat ())
            stop (ChessResult.DRAW, ChessRule.THREE_FOLD_REPETITION);
    }

    public void start ()
    {
        if (result != ChessResult.IN_PROGRESS)
            return;

        if (is_started)
            return;
        is_started = true;

        if (_clock != null)
        {
            _clock.expired.connect (clock_expired_cb);
            _clock.active_color = current_player.color;
        }

        turn_started (current_player);
    }

    private void clock_expired_cb (ChessClock clock)
    {
        if (clock.white_remaining_seconds <= 0)
            stop (ChessResult.BLACK_WON, ChessRule.TIMEOUT);
        else if (clock.black_remaining_seconds <= 0)
            stop (ChessResult.WHITE_WON, ChessRule.TIMEOUT);
        else
            assert_not_reached ();
    }

    public ChessPiece? get_piece (int rank, int file, int move_number = -1)
    {
        if (move_number < 0)
            move_number += (int) move_stack.length ();

        var state = move_stack.nth_data (move_stack.length () - move_number - 1);

        return state.board[state.get_index (rank, file)];
    }

    public uint n_moves
    {
        get { return move_stack.length () - 1; }
    }

    public void pause (bool show_overlay = true)
    {
        if (clock != null && result == ChessResult.IN_PROGRESS && !is_paused)
        {
            clock.pause ();
            is_paused = true;
            should_show_paused_overlay = show_overlay;
            paused ();
        }
    }

    public void unpause ()
    {
        if (clock != null && result == ChessResult.IN_PROGRESS && is_paused)
        {
            clock.unpause ();
            is_paused = false;
            should_show_paused_overlay = false;
            unpaused ();
        }
    }

    public void stop (ChessResult result, ChessRule rule)
    {
        if (!is_started)
            return;
        this.result = result;
        this.rule = rule;
        is_started = false;
        if (_clock != null)
            _clock.stop ();
        ended ();
    }
}
