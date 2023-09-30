/* lottery.c */

#include <stdio.h>    /* for printf() */
#include <stdlib.h>   /* for rand() and srand() */
#include <sys/time.h> /* for gettimeofday() */

int your_fcn()
{
    /* Modify this function to win the "lottery" in main(). */
    char buffer[16];
    /**
     * e5f8: memory location in stack of RIP/EIP (return address pointer)
     * e5d0: memory location in stack of buffer pointer
    */
    // int* ret = buffer + (0x7fffffffe5f8 - 0x7fffffffe5d0);
    int* ret = buffer + (0xe4e8 - 0xe4c0);
    /**
     * main+77: win scenario
     * main+50: normal return value
    */
    // *ret += (77 - 50);
    /**
     * 0x279: win scenario
     * 0x25b: normal return value
     */
    *ret += (0x279 - 0x25b);
    return 0;
}

int main()
{
    /* Seed the random number generator */
    struct timeval tv;
    gettimeofday(&tv, NULL);
    srand(tv.tv_usec);

    int rv;
    rv = your_fcn();

    /* Lottery time */
    if(rv != rand())
        printf("You lose\n");
    else
        printf("You win!\n");

    return EXIT_SUCCESS;
}
