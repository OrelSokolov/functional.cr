/* The "dangerous" layer: plain C arithmetic.
 *
 * From C there are no exceptions. A bad argument (b == 0) triggers a
 * hardware divide-by-zero fault (SIGFPE on Linux) that kills the whole
 * process before Crystal gets any chance to rescue it. Guards must stop
 * such arguments *before* they cross the FFI boundary. */

int mg_div(int a, int b)
{
    return a / b; /* b == 0 -> SIGFPE, process dies */
}

int mg_mean(int sum, int n)
{
    return sum / n; /* n == 0 -> SIGFPE, process dies */
}
