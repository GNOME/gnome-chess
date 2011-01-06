public class ChessClock : Object
{
    private Timer timer;
    private uint white_duration;
    private uint black_duration;
    private uint white_used;
    private uint black_used;
    private Color active_color = Color.WHITE;
    private uint timeout = 0;

    public signal void tick ();
    public signal void expired ();

    public ChessClock (uint white_duration, uint black_duration, uint white_used = 0, uint black_used = 0)
    {
        this.white_duration = white_duration;
        this.black_duration = black_duration;
        this.white_used = white_used;
        this.black_used = black_used;
        timer = new Timer ();
    }

    public void start ()
    {
        if (timeout != 0)
            return;

        uint remaining;
        if (active_color == Color.WHITE)
        {
            if (white_used > white_duration)
                white_used = white_duration;
            remaining = white_duration - white_used;
        }
        else
        {
            if (black_used > black_duration)
                black_used = black_duration;
            remaining = black_duration - black_used;
        }
        timer.start ();

        timeout = Timeout.add (remaining, timer_expired_cb);
    }

    private bool timer_expired_cb ()
    {
        timeout = 0;
        expired ();
        return false;
    }

    public void stop ()
    {
        if (timeout == 0)
            return;
        timer.stop ();
        Source.remove (timeout);
        timeout = 0;

        var elapsed = (uint) (timer.elapsed () * 1000000);
        if (active_color == Color.WHITE)
            white_used += elapsed;
        else
            black_used += elapsed;
    }

    public void set_color (Color color)
    {
        if (color == active_color)
            return;

        active_color = color;
        stop ();
        start ();
    }
}
