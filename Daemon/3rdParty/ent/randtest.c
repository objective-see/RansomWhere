/*

	 Apply various randomness tests to a stream of bytes

		  by John Walker  --  September 1996
		       http://www.fourmilab.ch/

*/

#include <math.h>

#define FALSE 0
#define TRUE  1

#define log2of10 3.32192809488736234787


//static long ccount[256],	   /* Bins to count occurrences of values */
//	    totalc = 0; 	       /* Total bytes counted */
//static double prob[256];	   /* Probabilities per bin for entropy */

/*  RT_LOG2  --  Calculate log to the base 2  */

static double rt_log2(double x)
{
    return log2of10 * log10(x);
}

#define MONTEN	6		      /* Bytes used as Monte Carlo
					 co-ordinates.	This should be no more
					 bits than the mantissa of your
                                         "double" floating point type. */

/*
static int mp;
static unsigned int monte[MONTEN];
static long inmont, mcount;
static double cexpb, incirc, montex, montey, montepi,
	      	      ent, chisq;
*/

//do rand tests
// ->combined thread safe function
void rt_combo(void *buf, int bufl, double *r_ent, double *r_chisq, double *r_montepicalc)
{
    long ccount[256];	   /* Bins to count occurrences of values */
    long totalc = 0; 	       /* Total bytes counted */
    double prob[256];	   /* Probabilities per bin for entropy */
    
    int mp;
    unsigned int monte[MONTEN];
    long inmont, mcount;
    double cexpb, incirc, montex, montey, montepi, ent, chisq;
    
    int i = 0;
    
    unsigned char *bp = buf;
    int oc, c, bean;
    
    //rt_init()
    /* Initialise for calculations */
    
    ent = 0.0;		       /* Clear entropy accumulator */
    chisq = 0.0;	       /* Clear Chi-Square */
    
    mp = 0;                /* Reset Monte Carlo accumulator pointer */
    mcount = 0; 	       /* Clear Monte Carlo tries */
    inmont = 0; 	       /* Clear Monte Carlo inside count */
    
    
    incirc = pow(pow(256.0, (double) (MONTEN / 2)) - 1, 2.0);
    
    for(i = 0; i < 256; i++)
    {
        ccount[i] = 0;
    }
    totalc = 0;
    
    //rt_init()
    while ((void)(bean = 0), (bufl-- > 0))
    {
        oc = *bp++;
        c = oc;
        
        ccount[c]++;		  /* Update counter for this bin */
        totalc++;
        
        /* Update inside / outside circle counts for Monte Carlo
         computation of PI */
        
        if(bean == 0)
        {
            monte[mp++] = oc;       /* Save character for Monte Carlo */
            if (mp >= MONTEN)
            {     /* Calculate every MONTEN character */
                int mj;
                
                mp = 0;
                mcount++;
                montex = montey = 0;
                for (mj = 0; mj < MONTEN / 2; mj++)
                {
                    montex = (montex * 256.0) + monte[mj];
                    montey = (montey * 256.0) + monte[(MONTEN / 2) + mj];
                }
                if ((montex * montex + montey *  montey) <= incirc)
                {
                    inmont++;
                }
            }
        }
    }//while
    
    //rt_end()
    
    /* Scan bins and calculate probability for each bin and
     Chi-Square distribution.  The probability will be reused
     in the entropy calculation below.  While we're at it,
     we sum of all the data which will be used to compute the
     mean. */
    
    cexpb = totalc / 256.0;  /* Expected count per bin */
    for (i = 0; i < 256; i++) {
        double a = ccount[i] - cexpb;;
        
        prob[i] = ((double) ccount[i]) / totalc;
        chisq += (a * a) / cexpb;
    }
    
    /* Calculate entropy */
    
    for (i = 0; i < 256; i++)
    {
        if (prob[i] > 0.0) {
            ent += prob[i] * rt_log2(1 / prob[i]);
        }
    }
    
    /* Calculate Monte Carlo value for PI from percentage of hits
     within the circle */
    
    montepi = 4.0 * (((double) inmont) / mcount);
    
    /* Return results through arguments */
    
    *r_ent = ent;
    *r_chisq = chisq;
    *r_montepicalc = montepi;
    
    return;
}
