[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Prctl
{
    [CCode (cheader_filename = "linux/prctl.h", cname = "PR_SET_PDEATHSIG")]
    public const int SET_PDEATHSIG;

    [CCode (cheader_filename = "sys/prctl.h", sentinel = "")]
    public int prctl (int option, ...);
}
